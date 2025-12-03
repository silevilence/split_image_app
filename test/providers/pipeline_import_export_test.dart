import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_image_app/processors/processors.dart';
import 'package:split_image_app/providers/pipeline_provider.dart';

void main() {
  group('Pipeline Import/Export', () {
    late PipelineProvider provider;
    late Directory tempDir;

    setUp(() async {
      provider = PipelineProvider();
      tempDir = await Directory.systemTemp.createTemp('pipeline_test_');
    });

    tearDown(() async {
      provider.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('ProcessorChain.toConfig()', () {
      test('should return empty list when chain is empty', () {
        expect(provider.processors, isEmpty);
        final config = provider.toConfig();
        expect(config['processors'], isEmpty);
      });

      test('should serialize single processor correctly', () {
        provider.addProcessor(ProcessorType.backgroundRemoval);
        final config = provider.toConfig();

        final processors = config['processors'] as List;
        expect(processors.length, 1);

        final processorConfig = processors[0] as Map<String, dynamic>;
        expect(processorConfig['typeId'], 'background_removal');
        expect(processorConfig['enabled'], true);
        expect(processorConfig['params'], isA<Map>());
      });

      test('should serialize multiple processors in order', () {
        provider.addProcessor(ProcessorType.backgroundRemoval);
        provider.addProcessor(ProcessorType.smartCrop);
        provider.addProcessor(ProcessorType.colorReplace);

        final config = provider.toConfig();
        final processors = config['processors'] as List;

        expect(processors.length, 3);
        expect((processors[0] as Map)['typeId'], 'background_removal');
        expect((processors[1] as Map)['typeId'], 'smart_crop');
        expect((processors[2] as Map)['typeId'], 'color_replace');
      });

      test('should preserve processor enabled state', () {
        provider.addProcessor(ProcessorType.backgroundRemoval);
        provider.addProcessor(ProcessorType.smartCrop);
        provider.setProcessorEnabled(0, false);

        final config = provider.toConfig();
        final processors = config['processors'] as List;

        expect((processors[0] as Map)['enabled'], false);
        expect((processors[1] as Map)['enabled'], true);
      });

      test('should preserve custom name', () {
        provider.addProcessor(ProcessorType.backgroundRemoval);
        provider.updateProcessorName(0, 'My Custom Name');

        final config = provider.toConfig();
        final processors = config['processors'] as List;

        expect((processors[0] as Map)['customName'], 'My Custom Name');
      });

      test('should not include slice overrides in toConfig()', () {
        provider.addProcessor(ProcessorType.backgroundRemoval);
        final processor = provider.processors[0];

        // 设置单图覆盖
        provider.setSliceOverride(
          0,
          processor.instanceId,
          ProcessorParams({'threshold': 128}),
        );

        final config = provider.toConfig();

        // processors 配置不应包含 slice overrides
        final processors = config['processors'] as List;
        expect(processors.length, 1);

        // overrides 在顶层配置中
        expect(config['overrides'], isA<Map>());
      });
    });

    group('PipelineProvider.loadFromConfig()', () {
      test('should restore single processor from config', () {
        // 创建配置
        final config = {
          'processors': [
            {
              'typeId': 'background_removal',
              'instanceId': 'test_1',
              'customName': 'Test Processor',
              'enabled': true,
              'params': {'threshold': 128},
            },
          ],
        };

        provider.loadFromConfig(config);

        expect(provider.processors.length, 1);
        expect(provider.processors[0].type, ProcessorType.backgroundRemoval);
        expect(provider.processors[0].customName, 'Test Processor');
        expect(provider.processors[0].enabled, true);
      });

      test('should restore multiple processors in correct order', () {
        final config = <String, dynamic>{
          'processors': <Map<String, dynamic>>[
            <String, dynamic>{
              'typeId': 'smart_crop',
              'instanceId': 'a',
              'customName': '',
              'enabled': true,
              'params': <String, dynamic>{},
            },
            <String, dynamic>{
              'typeId': 'resize',
              'instanceId': 'b',
              'customName': '',
              'enabled': true,
              'params': <String, dynamic>{},
            },
            <String, dynamic>{
              'typeId': 'background_removal',
              'instanceId': 'c',
              'customName': '',
              'enabled': true,
              'params': <String, dynamic>{},
            },
          ],
        };

        provider.loadFromConfig(config);

        expect(provider.processors.length, 3);
        expect(provider.processors[0].type, ProcessorType.smartCrop);
        expect(provider.processors[1].type, ProcessorType.resize);
        expect(provider.processors[2].type, ProcessorType.backgroundRemoval);
      });

      test('should restore processor parameters', () {
        final config = {
          'processors': [
            {
              'typeId': 'resize',
              'instanceId': 'test_resize',
              'customName': '',
              'enabled': true,
              'params': {'width': 100, 'height': 200},
            },
          ],
        };

        provider.loadFromConfig(config);

        expect(provider.processors[0].globalParams.get<int>('width'), 100);
        expect(provider.processors[0].globalParams.get<int>('height'), 200);
      });

      test('should handle empty config', () {
        provider.addProcessor(ProcessorType.backgroundRemoval);
        expect(provider.processors.length, 1);

        provider.loadFromConfig({'processors': []});

        expect(provider.processors, isEmpty);
      });

      test('should skip invalid processor types', () {
        final config = <String, dynamic>{
          'processors': <Map<String, dynamic>>[
            <String, dynamic>{
              'typeId': 'unknown_type',
              'instanceId': 'x',
              'customName': '',
              'enabled': true,
              'params': <String, dynamic>{},
            },
            <String, dynamic>{
              'typeId': 'resize',
              'instanceId': 'y',
              'customName': '',
              'enabled': true,
              'params': <String, dynamic>{},
            },
          ],
        };

        provider.loadFromConfig(config);

        // 只有一个有效的处理器被加载
        expect(provider.processors.length, 1);
        expect(provider.processors[0].type, ProcessorType.resize);
      });
    });

    group('JSON Serialization Round-trip', () {
      test('should survive JSON encode/decode round-trip', () {
        // 设置完整的 pipeline
        provider.addProcessor(ProcessorType.backgroundRemoval);
        provider.addProcessor(ProcessorType.smartCrop);
        provider.updateProcessorName(0, 'BG Remove');
        provider.setProcessorEnabled(1, false);

        // 导出为 JSON 字符串
        final config = {
          'version': 1,
          'processors': provider.toConfig()['processors'],
        };
        final jsonStr = jsonEncode(config);

        // 解析 JSON
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

        // 创建新 provider 并恢复
        final newProvider = PipelineProvider();
        newProvider.loadFromConfig(decoded);

        expect(newProvider.processors.length, 2);
        expect(newProvider.processors[0].type, ProcessorType.backgroundRemoval);
        expect(newProvider.processors[0].customName, 'BG Remove');
        expect(newProvider.processors[1].type, ProcessorType.smartCrop);
        expect(newProvider.processors[1].enabled, false);

        newProvider.dispose();
      });

      test('should produce valid JSON format', () {
        provider.addProcessor(ProcessorType.colorReplace);

        final config = {
          'version': 1,
          'exportedAt': DateTime.now().toIso8601String(),
          'processors': provider.toConfig()['processors'],
        };

        // 应该不抛出异常
        final jsonStr = const JsonEncoder.withIndent('  ').convert(config);
        expect(jsonStr, contains('"version": 1'));
        expect(jsonStr, contains('"processors"'));
        expect(jsonStr, contains('"color_replace"'));
      });
    });

    group('Import Append vs Replace', () {
      test('loadFromConfig should replace existing processors', () {
        // 先添加一些处理器
        provider.addProcessor(ProcessorType.backgroundRemoval);
        provider.addProcessor(ProcessorType.smartCrop);
        expect(provider.processors.length, 2);

        // 加载新配置（应该替换）
        final config = <String, dynamic>{
          'processors': <Map<String, dynamic>>[
            <String, dynamic>{
              'typeId': 'resize',
              'instanceId': 'new',
              'customName': '',
              'enabled': true,
              'params': <String, dynamic>{},
            },
          ],
        };
        provider.loadFromConfig(config);

        // 应该只有新的一个
        expect(provider.processors.length, 1);
        expect(provider.processors[0].type, ProcessorType.resize);
      });
    });
  });
}

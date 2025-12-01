import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_image_app/processors/processors.dart';

void main() {
  group('ProcessorParam', () {
    test('ProcessorParamDef validates integer values', () {
      final def = ProcessorParamDef(
        id: 'threshold',
        displayName: 'Threshold',
        type: ParamType.integer,
        defaultValue: 50,
        minValue: 0,
        maxValue: 100,
      );

      expect(def.isValid(50), isTrue);
      expect(def.isValid(0), isTrue);
      expect(def.isValid(100), isTrue);
      expect(def.isValid(-1), isFalse);
      expect(def.isValid(101), isFalse);
      expect(def.isValid('50'), isFalse);
    });

    test('ProcessorParamDef validates double values', () {
      final def = ProcessorParamDef(
        id: 'opacity',
        displayName: 'Opacity',
        type: ParamType.double_,
        defaultValue: 1.0,
        minValue: 0.0,
        maxValue: 1.0,
      );

      expect(def.isValid(0.5), isTrue);
      expect(def.isValid(0.0), isTrue);
      expect(def.isValid(1.0), isTrue);
      expect(def.isValid(-0.1), isFalse);
      expect(def.isValid(1.1), isFalse);
    });

    test('ProcessorParamDef validates enum values', () {
      final def = ProcessorParamDef(
        id: 'algorithm',
        displayName: 'Algorithm',
        type: ParamType.enumChoice,
        defaultValue: 'bilinear',
        enumOptions: ['nearest', 'bilinear', 'bicubic'],
      );

      expect(def.isValid('bilinear'), isTrue);
      expect(def.isValid('nearest'), isTrue);
      expect(def.isValid('invalid'), isFalse);
    });

    test('ProcessorParams get and set values', () {
      const params = ProcessorParams({'a': 1, 'b': 'test'});

      expect(params.get<int>('a'), equals(1));
      expect(params.get<String>('b'), equals('test'));
      expect(params.get<int>('c'), isNull);
      expect(params.getOr<int>('c', 10), equals(10));
    });

    test('ProcessorParams copyWith creates new instance', () {
      const params = ProcessorParams({'a': 1});
      final newParams = params.copyWith('b', 2);

      expect(params.get<int>('b'), isNull);
      expect(newParams.get<int>('a'), equals(1));
      expect(newParams.get<int>('b'), equals(2));
    });
  });

  group('ProcessorIO', () {
    test('ProcessorInput stores pixel data correctly', () {
      final pixels = Uint8List.fromList(List.generate(100 * 4, (i) => i % 256));
      final input = ProcessorInput(
        pixels: pixels,
        width: 10,
        height: 10,
        sliceIndex: 0,
        row: 0,
        col: 0,
      );

      expect(input.width, equals(10));
      expect(input.height, equals(10));
      expect(input.pixelCount, equals(100));
      expect(input.bytesPerRow, equals(40));
      expect(input.totalBytes, equals(400));
    });

    test('ProcessorInput getPixelAt returns correct values', () {
      // Create 2x2 image with RGBA pixels
      final pixels = Uint8List.fromList([
        255, 0, 0, 255, // Red pixel at (0, 0)
        0, 255, 0, 255, // Green pixel at (1, 0)
        0, 0, 255, 255, // Blue pixel at (0, 1)
        255, 255, 255, 255, // White pixel at (1, 1)
      ]);
      final input = ProcessorInput(pixels: pixels, width: 2, height: 2);

      expect(input.getPixelAt(0, 0), equals([255, 0, 0, 255]));
      expect(input.getPixelAt(1, 0), equals([0, 255, 0, 255]));
      expect(input.getPixelAt(0, 1), equals([0, 0, 255, 255]));
      expect(input.getPixelAt(1, 1), equals([255, 255, 255, 255]));
      expect(input.getPixelAt(2, 0), isNull); // Out of bounds
    });

    test('ProcessorOutput unchanged preserves data', () {
      final pixels = Uint8List.fromList([1, 2, 3, 4]);
      final input = ProcessorInput(pixels: pixels, width: 1, height: 1);
      final output = ProcessorOutput.unchanged(input, processorId: 'test');

      expect(output.pixels, equals(input.pixels));
      expect(output.width, equals(input.width));
      expect(output.height, equals(input.height));
      expect(output.hasChanges, isFalse);
      expect(output.processorId, equals('test'));
    });

    test('ProcessorOutput toInput converts correctly', () {
      final pixels = Uint8List.fromList([1, 2, 3, 4]);
      final output = ProcessorOutput(pixels: pixels, width: 1, height: 1);
      final input = output.toInput(sliceIndex: 5, row: 1, col: 2);

      expect(input.pixels, equals(output.pixels));
      expect(input.sliceIndex, equals(5));
      expect(input.row, equals(1));
      expect(input.col, equals(2));
    });
  });

  group('ProcessorFactory', () {
    setUp(() {
      ProcessorFactory.resetCounter();
    });

    test('creates processor with unique instance ID', () {
      final p1 = ProcessorFactory.create(ProcessorType.smartCrop);
      final p2 = ProcessorFactory.create(ProcessorType.smartCrop);

      expect(p1.instanceId, isNot(equals(p2.instanceId)));
    });

    test('creates processor with custom name', () {
      final processor = ProcessorFactory.create(
        ProcessorType.resize,
        customName: 'My Resize',
      );

      expect(processor.customName, equals('My Resize'));
    });

    test('creates processor with initial params', () {
      final processor = ProcessorFactory.create(
        ProcessorType.backgroundRemoval,
        params: const ProcessorParams({'threshold': 30}),
      );

      expect(processor.globalParams.get<int>('threshold'), equals(30));
    });

    test('fromConfig restores processor correctly', () {
      final config = {
        'typeId': 'smart_crop',
        'instanceId': 'smart_crop_custom',
        'customName': 'Custom Crop',
        'enabled': false,
        'params': {'margin': 10},
      };

      final processor = ProcessorFactory.fromConfig(config);

      expect(processor, isNotNull);
      expect(processor!.type, equals(ProcessorType.smartCrop));
      expect(processor.instanceId, equals('smart_crop_custom'));
      expect(processor.customName, equals('Custom Crop'));
      expect(processor.enabled, isFalse);
      expect(processor.globalParams.get<int>('margin'), equals(10));
    });
  });

  group('ProcessorChain', () {
    late ProcessorChain chain;

    setUp(() {
      ProcessorFactory.resetCounter();
      chain = ProcessorChain();
    });

    test('add and remove processors', () {
      final p1 = ProcessorFactory.create(ProcessorType.smartCrop);
      final p2 = ProcessorFactory.create(ProcessorType.resize);

      chain.add(p1);
      chain.add(p2);

      expect(chain.length, equals(2));
      expect(chain.processors[0], equals(p1));
      expect(chain.processors[1], equals(p2));

      chain.remove(p1);
      expect(chain.length, equals(1));
      expect(chain.processors[0], equals(p2));
    });

    test('reorder processors', () {
      final p1 = ProcessorFactory.create(ProcessorType.smartCrop);
      final p2 = ProcessorFactory.create(ProcessorType.resize);
      final p3 = ProcessorFactory.create(ProcessorType.colorReplace);

      chain.add(p1);
      chain.add(p2);
      chain.add(p3);

      // Move first to last
      chain.reorder(0, 3);
      expect(chain.processors[0], equals(p2));
      expect(chain.processors[1], equals(p3));
      expect(chain.processors[2], equals(p1));
    });

    test('enabledProcessors filters correctly', () {
      final p1 = ProcessorFactory.create(ProcessorType.smartCrop);
      final p2 = ProcessorFactory.create(ProcessorType.resize);

      p2.enabled = false;
      chain.add(p1);
      chain.add(p2);

      expect(chain.length, equals(2));
      expect(chain.enabledProcessors.length, equals(1));
      expect(chain.enabledCount, equals(1));
    });

    test('findById returns correct processor', () {
      final p1 = ProcessorFactory.create(ProcessorType.smartCrop);
      chain.add(p1);

      expect(chain.findById(p1.instanceId), equals(p1));
      expect(chain.findById('non-existent'), isNull);
    });

    test('slice overrides management', () {
      final p1 = ProcessorFactory.create(ProcessorType.smartCrop);
      chain.add(p1);

      chain.setSliceOverride(
        0,
        p1.instanceId,
        const ProcessorParams({'margin': 5}),
      );

      final overrides = chain.getSliceOverrides(0);
      expect(overrides, isNotNull);
      expect(
        overrides!.getOverrides(p1.instanceId)?.get<int>('margin'),
        equals(5),
      );

      chain.removeSliceOverride(0, p1.instanceId);
      expect(chain.getSliceOverrides(0), isNull);
    });

    test('process executes enabled processors in order', () async {
      final pixels = Uint8List.fromList(List.generate(4, (i) => i));
      final input = ProcessorInput(pixels: pixels, width: 1, height: 1);

      final p1 = ProcessorFactory.create(ProcessorType.smartCrop);
      final p2 = ProcessorFactory.create(ProcessorType.resize);
      p2.enabled = false;

      chain.add(p1);
      chain.add(p2);

      final output = await chain.process(input);

      // Placeholder processors don't modify data
      expect(output.hasChanges, isFalse);
    });

    test('toConfig serializes chain correctly', () {
      final p1 = ProcessorFactory.create(
        ProcessorType.smartCrop,
        customName: 'Crop 1',
      );
      chain.add(p1);

      final config = chain.toConfig();

      expect(config.length, equals(1));
      expect(config[0]['typeId'], equals('smart_crop'));
      expect(config[0]['customName'], equals('Crop 1'));
    });
  });

  group('SliceOverrides', () {
    test('manages overrides correctly', () {
      const overrides = SliceOverrides(sliceIndex: 0);

      final updated = overrides.setOverrides(
        'processor_1',
        const ProcessorParams({'threshold': 50}),
      );

      expect(updated.hasOverrides, isTrue);
      expect(updated.hasOverridesFor('processor_1'), isTrue);
      expect(
        updated.getOverrides('processor_1')?.get<int>('threshold'),
        equals(50),
      );

      final removed = updated.removeOverrides('processor_1');
      expect(removed.hasOverrides, isFalse);
    });

    test('serializes and deserializes correctly', () {
      final overrides = SliceOverrides(
        sliceIndex: 5,
        overrides: {
          'proc_1': const ProcessorParams({'a': 1}),
        },
      );

      final map = overrides.toMap();
      final restored = SliceOverrides.fromMap(map);

      expect(restored.sliceIndex, equals(5));
      expect(restored.getOverrides('proc_1')?.get<int>('a'), equals(1));
    });
  });
}

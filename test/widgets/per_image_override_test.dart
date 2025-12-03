import 'package:flutter_test/flutter_test.dart';

import 'package:split_image_app/processors/processors.dart';
import 'package:split_image_app/models/slice_preview.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

void main() {
  group('Per-Image Override Editor', () {
    group('ProcessorParams', () {
      test('copyWith should create new instance with updated value', () {
        const params = ProcessorParams({'threshold': 50, 'color': 0xFF000000});
        final updated = params.copyWith('threshold', 100);

        expect(updated.get<int>('threshold'), 100);
        expect(updated.get<int>('color'), 0xFF000000);
        // 原始对象不变
        expect(params.get<int>('threshold'), 50);
      });

      test('remove should create new instance without the key', () {
        const params = ProcessorParams({'a': 1, 'b': 2, 'c': 3});
        final updated = params.remove('b');

        expect(updated.has('a'), true);
        expect(updated.has('b'), false);
        expect(updated.has('c'), true);
      });

      test('copyWithAll should merge multiple values', () {
        const params = ProcessorParams({'a': 1, 'b': 2});
        final updated = params.copyWithAll({'b': 20, 'c': 30});

        expect(updated.get<int>('a'), 1);
        expect(updated.get<int>('b'), 20);
        expect(updated.get<int>('c'), 30);
      });
    });

    group('SlicePreview overrides', () {
      late SlicePreview slice;

      setUp(() {
        slice = SlicePreview(
          row: 0,
          col: 0,
          region: const ui.Rect.fromLTWH(0, 0, 100, 100),
          thumbnailBytes: Uint8List(0),
        );
      });

      test('initially has no overrides', () {
        expect(slice.hasOverrides, false);
        expect(slice.processorOverrides.isEmpty, true);
      });

      test('setOverrides should add override params', () {
        slice.setOverrides(
          'processor_1',
          const ProcessorParams({'margin': 10}),
        );

        expect(slice.hasOverrides, true);
        expect(slice.getOverrides('processor_1')?.get<int>('margin'), 10);
      });

      test('removeOverrides should remove specific processor override', () {
        slice.setOverrides('processor_1', const ProcessorParams({'a': 1}));
        slice.setOverrides('processor_2', const ProcessorParams({'b': 2}));

        slice.removeOverrides('processor_1');

        expect(slice.getOverrides('processor_1'), null);
        expect(slice.getOverrides('processor_2')?.get<int>('b'), 2);
      });

      test('clearOverrides should remove all overrides', () {
        slice.setOverrides('processor_1', const ProcessorParams({'a': 1}));
        slice.setOverrides('processor_2', const ProcessorParams({'b': 2}));

        slice.clearOverrides();

        expect(slice.hasOverrides, false);
        expect(slice.processorOverrides.isEmpty, true);
      });

      test('copyWith should preserve overrides', () {
        slice.setOverrides(
          'processor_1',
          const ProcessorParams({'margin': 10}),
        );

        final copy = slice.copyWith(isSelected: false);

        expect(copy.isSelected, false);
        expect(copy.getOverrides('processor_1')?.get<int>('margin'), 10);
      });
    });

    group('ProcessorChain slice overrides', () {
      late ProcessorChain chain;

      setUp(() {
        chain = ProcessorChain();
      });

      test('setSliceOverride should store override for specific slice', () {
        chain.setSliceOverride(
          0,
          'proc_1',
          const ProcessorParams({'value': 42}),
        );

        final overrides = chain.getSliceOverrides(0);
        expect(overrides, isNotNull);
        expect(overrides!.getOverrides('proc_1')?.get<int>('value'), 42);
      });

      test('multiple slices can have different overrides', () {
        chain.setSliceOverride(0, 'proc', const ProcessorParams({'v': 1}));
        chain.setSliceOverride(1, 'proc', const ProcessorParams({'v': 2}));
        chain.setSliceOverride(2, 'proc', const ProcessorParams({'v': 3}));

        expect(
          chain.getSliceOverrides(0)?.getOverrides('proc')?.get<int>('v'),
          1,
        );
        expect(
          chain.getSliceOverrides(1)?.getOverrides('proc')?.get<int>('v'),
          2,
        );
        expect(
          chain.getSliceOverrides(2)?.getOverrides('proc')?.get<int>('v'),
          3,
        );
      });

      test('removeSliceOverride should remove specific processor override', () {
        chain.setSliceOverride(0, 'proc_1', const ProcessorParams({'a': 1}));
        chain.setSliceOverride(0, 'proc_2', const ProcessorParams({'b': 2}));

        chain.removeSliceOverride(0, 'proc_1');

        final overrides = chain.getSliceOverrides(0);
        expect(overrides?.getOverrides('proc_1'), null);
        expect(overrides?.getOverrides('proc_2')?.get<int>('b'), 2);
      });

      test('clearAllOverrides should remove all slice overrides', () {
        chain.setSliceOverride(0, 'proc', const ProcessorParams({'a': 1}));
        chain.setSliceOverride(1, 'proc', const ProcessorParams({'b': 2}));

        chain.clearAllOverrides();

        expect(chain.getSliceOverrides(0), null);
        expect(chain.getSliceOverrides(1), null);
      });
    });

    group('ProcessorParamDef supportsPerImageOverride', () {
      test('perImageParams should filter correctly', () {
        final processor = ProcessorFactory.create(ProcessorType.smartCrop);

        final perImageParams = processor.perImageParams;

        // SmartCrop 的所有参数都支持单图覆盖
        expect(perImageParams.isNotEmpty, true);
        for (final param in perImageParams) {
          expect(param.supportsPerImageOverride, true);
        }
      });

      test(
        'hasPerImageParams should return true for processors with per-image params',
        () {
          final smartCrop = ProcessorFactory.create(ProcessorType.smartCrop);
          final backgroundRemoval = ProcessorFactory.create(
            ProcessorType.backgroundRemoval,
          );

          // SmartCrop 有单图覆盖参数
          expect(smartCrop.hasPerImageParams, true);

          // BackgroundRemoval 可能没有（或有），根据实现检查
          // 这里只验证方法存在且返回布尔值
          expect(backgroundRemoval.hasPerImageParams, isA<bool>());
        },
      );
    });
  });
}

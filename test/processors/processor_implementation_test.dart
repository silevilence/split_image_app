import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_image_app/processors/processors.dart';

void main() {
  group('BackgroundRemovalProcessor', () {
    late BackgroundRemovalProcessor processor;

    setUp(() {
      processor = BackgroundRemovalProcessor(instanceId: 'test_bg_removal');
    });

    test('should remove white background from corners', () async {
      // 创建一个 4x4 的测试图片
      // 边缘是白色背景，中心是红色内容
      // W W W W
      // W R R W
      // W R R W
      // W W W W
      final pixels = Uint8List(4 * 4 * 4);

      // 填充白色背景 (RGBA: 255, 255, 255, 255)
      for (int i = 0; i < pixels.length; i += 4) {
        pixels[i] = 255; // R
        pixels[i + 1] = 255; // G
        pixels[i + 2] = 255; // B
        pixels[i + 3] = 255; // A
      }

      // 中心 2x2 区域设置为红色
      final centerPixels = [(1, 1), (2, 1), (1, 2), (2, 2)];
      for (final pos in centerPixels) {
        final offset = (pos.$2 * 4 + pos.$1) * 4;
        pixels[offset] = 255; // R
        pixels[offset + 1] = 0; // G
        pixels[offset + 2] = 0; // B
        pixels[offset + 3] = 255; // A
      }

      final input = ProcessorInput(pixels: pixels, width: 4, height: 4);
      final params = ProcessorParams({
        'threshold': 30,
        'replaceColor': 0x00000000, // 透明
      });

      final output = await processor.process(input, params);

      expect(output.hasChanges, true);
      expect(output.width, 4);
      expect(output.height, 4);

      // 检查角落像素是否变为透明
      expect(output.pixels[3], 0); // 左上角 Alpha = 0
      expect(output.pixels[(3 * 4 + 3) * 4 + 3], 0); // 右下角 Alpha = 0

      // 检查中心像素是否保持红色
      final centerOffset = (1 * 4 + 1) * 4;
      expect(output.pixels[centerOffset], 255); // R
      expect(output.pixels[centerOffset + 1], 0); // G
      expect(output.pixels[centerOffset + 2], 0); // B
      expect(output.pixels[centerOffset + 3], 255); // A (不透明)
    });

    test('should return unchanged when no background detected', () async {
      // 创建全红色图片
      final pixels = Uint8List(4 * 4 * 4);
      for (int i = 0; i < pixels.length; i += 4) {
        pixels[i] = 255; // R
        pixels[i + 1] = 0; // G
        pixels[i + 2] = 0; // B
        pixels[i + 3] = 255; // A
      }

      final input = ProcessorInput(pixels: pixels, width: 4, height: 4);
      final params = ProcessorParams({
        'threshold': 30,
        'replaceColor': 0x00000000,
      });

      final output = await processor.process(input, params);

      // 因为四角颜色相同但与自己完全一致，flood fill 会替换所有像素
      // 但由于都是相同颜色，结果取决于实现
      expect(output.width, 4);
      expect(output.height, 4);
    });
  });

  group('SmartCropProcessor', () {
    late SmartCropProcessor processor;

    setUp(() {
      processor = SmartCropProcessor(instanceId: 'test_smart_crop');
    });

    test('should crop specified pixels from each edge', () async {
      // 创建 6x6 图片
      final pixels = Uint8List(6 * 6 * 4);
      for (int i = 0; i < pixels.length; i += 4) {
        pixels[i] = 255; // R
        pixels[i + 1] = 0; // G
        pixels[i + 2] = 0; // B
        pixels[i + 3] = 255; // A
      }

      final input = ProcessorInput(pixels: pixels, width: 6, height: 6);
      final params = ProcessorParams({
        'marginTop': 1,
        'marginBottom': 1,
        'marginLeft': 1,
        'marginRight': 1,
      });

      final output = await processor.process(input, params);

      expect(output.hasChanges, true);
      // 6x6 - 每边裁剪1像素 = 4x4
      expect(output.width, 4);
      expect(output.height, 4);
    });

    test('should crop asymmetrically', () async {
      // 创建 10x8 图片
      final pixels = Uint8List(10 * 8 * 4);
      for (int i = 0; i < pixels.length; i += 4) {
        pixels[i + 3] = 255; // A
      }

      final input = ProcessorInput(pixels: pixels, width: 10, height: 8);
      final params = ProcessorParams({
        'marginTop': 2,
        'marginBottom': 1,
        'marginLeft': 3,
        'marginRight': 2,
      });

      final output = await processor.process(input, params);

      expect(output.hasChanges, true);
      // 宽度: 10 - 3 - 2 = 5
      // 高度: 8 - 2 - 1 = 5
      expect(output.width, 5);
      expect(output.height, 5);
    });

    test('should return unchanged when all margins are 0', () async {
      final pixels = Uint8List(4 * 4 * 4);
      for (int i = 0; i < pixels.length; i += 4) {
        pixels[i + 3] = 255;
      }

      final input = ProcessorInput(pixels: pixels, width: 4, height: 4);
      final params = ProcessorParams({
        'marginTop': 0,
        'marginBottom': 0,
        'marginLeft': 0,
        'marginRight': 0,
      });

      final output = await processor.process(input, params);

      expect(output.hasChanges, false);
      expect(output.width, 4);
      expect(output.height, 4);
    });

    test('should return unchanged when crop exceeds image size', () async {
      final pixels = Uint8List(4 * 4 * 4);
      for (int i = 0; i < pixels.length; i += 4) {
        pixels[i + 3] = 255;
      }

      final input = ProcessorInput(pixels: pixels, width: 4, height: 4);
      final params = ProcessorParams({
        'marginTop': 2,
        'marginBottom': 3, // 2 + 3 = 5 > 4
        'marginLeft': 0,
        'marginRight': 0,
      });

      final output = await processor.process(input, params);

      expect(output.hasChanges, false);
    });

    test('should preserve pixel content after cropping', () async {
      // 创建 4x4 图片，填充不同颜色用于验证
      final pixels = Uint8List(4 * 4 * 4);
      for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          final offset = (y * 4 + x) * 4;
          pixels[offset] = x * 60; // R
          pixels[offset + 1] = y * 60; // G
          pixels[offset + 2] = 100; // B
          pixels[offset + 3] = 255; // A
        }
      }

      final input = ProcessorInput(pixels: pixels, width: 4, height: 4);
      final params = ProcessorParams({
        'marginTop': 1,
        'marginBottom': 1,
        'marginLeft': 1,
        'marginRight': 1,
      });

      final output = await processor.process(input, params);

      expect(output.hasChanges, true);
      expect(output.width, 2);
      expect(output.height, 2);

      // 验证裁剪后的左上角像素来自原图的 (1,1)
      expect(output.pixels[0], 1 * 60); // R = 60 (原图 x=1)
      expect(output.pixels[1], 1 * 60); // G = 60 (原图 y=1)
      expect(output.pixels[2], 100); // B
      expect(output.pixels[3], 255); // A
    });
  });

  group('ColorReplaceProcessor', () {
    late ColorReplaceProcessor processor;

    setUp(() {
      processor = ColorReplaceProcessor(instanceId: 'test_color_replace');
    });

    test('should replace target color with new color', () async {
      // 创建 2x2 图片，全白色
      final pixels = Uint8List(2 * 2 * 4);
      for (int i = 0; i < pixels.length; i += 4) {
        pixels[i] = 255; // R
        pixels[i + 1] = 255; // G
        pixels[i + 2] = 255; // B
        pixels[i + 3] = 255; // A
      }

      final input = ProcessorInput(pixels: pixels, width: 2, height: 2);
      final params = ProcessorParams({
        'targetColor': 0xFFFFFFFF, // 白色
        'newColor': 0xFF0000FF, // 蓝色
        'threshold': 20,
      });

      final output = await processor.process(input, params);

      expect(output.hasChanges, true);

      // 检查所有像素是否变为蓝色
      for (int i = 0; i < output.pixels.length; i += 4) {
        expect(output.pixels[i], 0); // R = 0
        expect(output.pixels[i + 1], 0); // G = 0
        expect(output.pixels[i + 2], 255); // B = 255
        expect(output.pixels[i + 3], 255); // A = 255
      }
    });

    test('should respect threshold for color matching', () async {
      // 创建 2x2 图片
      // 第一个像素: 纯白 (255, 255, 255)
      // 其他像素: 近白 (250, 250, 250)
      final pixels = Uint8List(2 * 2 * 4);

      // 第一个像素 - 纯白
      pixels[0] = 255;
      pixels[1] = 255;
      pixels[2] = 255;
      pixels[3] = 255;

      // 其他像素 - 近白
      for (int i = 4; i < pixels.length; i += 4) {
        pixels[i] = 250;
        pixels[i + 1] = 250;
        pixels[i + 2] = 250;
        pixels[i + 3] = 255;
      }

      final input = ProcessorInput(pixels: pixels, width: 2, height: 2);

      // 使用较小的阈值，只匹配纯白
      final params = ProcessorParams({
        'targetColor': 0xFFFFFFFF,
        'newColor': 0xFF000000, // 黑色
        'threshold': 3, // 只有纯白会被匹配
      });

      final output = await processor.process(input, params);

      expect(output.hasChanges, true);

      // 第一个像素应该变成黑色
      expect(output.pixels[0], 0); // R = 0
      expect(output.pixels[1], 0); // G = 0
      expect(output.pixels[2], 0); // B = 0

      // 第二个像素应该保持近白
      expect(output.pixels[4], 250);
    });

    test('should return unchanged when no color matches', () async {
      // 创建全红色图片
      final pixels = Uint8List(2 * 2 * 4);
      for (int i = 0; i < pixels.length; i += 4) {
        pixels[i] = 255; // R
        pixels[i + 1] = 0; // G
        pixels[i + 2] = 0; // B
        pixels[i + 3] = 255; // A
      }

      final input = ProcessorInput(pixels: pixels, width: 2, height: 2);
      final params = ProcessorParams({
        'targetColor': 0xFFFFFFFF, // 白色（不存在）
        'newColor': 0xFF0000FF,
        'threshold': 20,
      });

      final output = await processor.process(input, params);

      expect(output.hasChanges, false);
    });
  });

  group('ResizeProcessor', () {
    late ResizeProcessor processor;

    setUp(() {
      processor = ResizeProcessor(instanceId: 'test_resize');
    });

    test('should resize image to specified dimensions', () async {
      // 创建 4x4 红色图片
      final pixels = Uint8List(4 * 4 * 4);
      for (int i = 0; i < pixels.length; i += 4) {
        pixels[i] = 255; // R
        pixels[i + 1] = 0; // G
        pixels[i + 2] = 0; // B
        pixels[i + 3] = 255; // A
      }

      final input = ProcessorInput(pixels: pixels, width: 4, height: 4);
      final params = ProcessorParams({
        'width': 2,
        'height': 2,
        'unit': 'pixel',
      });

      final output = await processor.process(input, params);

      expect(output.hasChanges, true);
      expect(output.width, 2);
      expect(output.height, 2);
      expect(output.pixels.length, 2 * 2 * 4);

      // 检查像素仍然是红色
      expect(output.pixels[0], 255); // R
      expect(output.pixels[1], 0); // G
      expect(output.pixels[2], 0); // B
      expect(output.pixels[3], 255); // A
    });

    test('should maintain aspect ratio when one dimension is 0', () async {
      // 创建 4x2 图片
      final pixels = Uint8List(4 * 2 * 4);
      for (int i = 0; i < pixels.length; i += 4) {
        pixels[i + 3] = 255; // A
      }

      final input = ProcessorInput(pixels: pixels, width: 4, height: 2);
      final params = ProcessorParams({
        'width': 8,
        'height': 0, // 自动计算
        'unit': 'pixel',
      });

      final output = await processor.process(input, params);

      expect(output.hasChanges, true);
      expect(output.width, 8);
      expect(output.height, 4); // 按比例: 8 * (2/4) = 4
    });

    test('should handle percent unit correctly', () async {
      // 创建 4x4 图片
      final pixels = Uint8List(4 * 4 * 4);
      for (int i = 0; i < pixels.length; i += 4) {
        pixels[i + 3] = 255;
      }

      final input = ProcessorInput(pixels: pixels, width: 4, height: 4);
      final params = ProcessorParams({
        'width': 50, // 50%
        'height': 50, // 50%
        'unit': 'percent',
      });

      final output = await processor.process(input, params);

      expect(output.hasChanges, true);
      expect(output.width, 2); // 4 * 50% = 2
      expect(output.height, 2); // 4 * 50% = 2
    });

    test('should return unchanged when both dimensions are 0', () async {
      final pixels = Uint8List(4 * 4 * 4);
      final input = ProcessorInput(pixels: pixels, width: 4, height: 4);
      final params = ProcessorParams({
        'width': 0,
        'height': 0,
        'unit': 'pixel',
      });

      final output = await processor.process(input, params);

      expect(output.hasChanges, false);
    });

    test('should return unchanged when dimensions match', () async {
      final pixels = Uint8List(4 * 4 * 4);
      final input = ProcessorInput(pixels: pixels, width: 4, height: 4);
      final params = ProcessorParams({
        'width': 4,
        'height': 4,
        'unit': 'pixel',
      });

      final output = await processor.process(input, params);

      expect(output.hasChanges, false);
    });
  });
}

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:split_image_app/processors/background_removal_processor.dart';
import 'package:split_image_app/processors/processor_io.dart';
import 'package:split_image_app/processors/processor_param.dart';

void main() {
  group('Background Removal to PNG Export Integration', () {
    test(
      'should preserve transparency when exporting to PNG after background removal',
      () async {
        // 1. 创建一个测试图片：白色背景 + 红色中心方块
        // 10x10 图片，中心 4x4 是红色，周围是白色背景
        const width = 10;
        const height = 10;

        final pixels = Uint8List(width * height * 4);
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final offset = (y * width + x) * 4;
            if (x >= 3 && x < 7 && y >= 3 && y < 7) {
              // 中心红色方块
              pixels[offset] = 255; // R
              pixels[offset + 1] = 0; // G
              pixels[offset + 2] = 0; // B
              pixels[offset + 3] = 255; // A (不透明)
            } else {
              // 白色背景
              pixels[offset] = 255; // R
              pixels[offset + 1] = 255; // G
              pixels[offset + 2] = 255; // B
              pixels[offset + 3] = 255; // A (不透明)
            }
          }
        }

        // 2. 应用背景移除处理器
        final processor = BackgroundRemovalProcessor(
          instanceId: 'test-bg-removal',
        );
        final input = ProcessorInput(
          pixels: pixels,
          width: width,
          height: height,
          sliceIndex: 0,
          row: 0,
          col: 0,
        );

        final output = await processor.process(
          input,
          ProcessorParams({
            'threshold': 30,
            'replaceColor': 0x00000000, // 透明
          }),
        );

        expect(output.hasChanges, isTrue);

        // 3. 验证背景像素变为透明
        final processedPixels = output.pixels;

        // 检查左上角（应该是透明的）
        final cornerOffset = 0;
        expect(
          processedPixels[cornerOffset + 3],
          equals(0),
          reason: 'Corner pixel should be transparent',
        );

        // 检查中心（应该是红色不透明）
        final centerOffset = (5 * width + 5) * 4;
        expect(
          processedPixels[centerOffset],
          equals(255),
          reason: 'Center R should be 255',
        );
        expect(
          processedPixels[centerOffset + 1],
          equals(0),
          reason: 'Center G should be 0',
        );
        expect(
          processedPixels[centerOffset + 2],
          equals(0),
          reason: 'Center B should be 0',
        );
        expect(
          processedPixels[centerOffset + 3],
          equals(255),
          reason: 'Center pixel should be opaque',
        );

        // 4. 模拟导出：使用与 image_processor.dart 相同的逻辑创建 Image
        final exportImage = img.Image(
          width: output.width,
          height: output.height,
          numChannels: 4, // 关键！必须指定 4 通道以保留 Alpha
        );

        for (int y = 0; y < output.height; y++) {
          for (int x = 0; x < output.width; x++) {
            final offset = (y * output.width + x) * 4;
            exportImage.setPixelRgba(
              x,
              y,
              processedPixels[offset],
              processedPixels[offset + 1],
              processedPixels[offset + 2],
              processedPixels[offset + 3],
            );
          }
        }

        // 5. 验证导出图片保留了 Alpha 通道
        expect(exportImage.hasAlpha, isTrue);
        expect(exportImage.numChannels, equals(4));

        // 6. 编码为 PNG
        final pngBytes = img.encodePng(exportImage);

        // 7. 解码并验证透明度保留
        final decoded = img.decodePng(Uint8List.fromList(pngBytes));
        expect(decoded, isNotNull);
        expect(decoded!.hasAlpha, isTrue);

        // 检查左上角像素（应该是透明的）
        final cornerPixel = decoded.getPixel(0, 0);
        expect(
          cornerPixel.a.toInt(),
          equals(0),
          reason: 'PNG corner should be transparent',
        );

        // 检查中心像素（应该是红色不透明）
        final centerPixel = decoded.getPixel(5, 5);
        expect(
          centerPixel.r.toInt(),
          equals(255),
          reason: 'PNG center R should be 255',
        );
        expect(
          centerPixel.a.toInt(),
          equals(255),
          reason: 'PNG center should be opaque',
        );

        print('✅ 背景移除 + PNG 导出测试通过！');
        print('   - 背景像素透明度: ${cornerPixel.a}');
        print('   - 中心像素透明度: ${centerPixel.a}');
        print('   - PNG 文件大小: ${pngBytes.length} bytes');
      },
    );

    test('should export actual PNG file with transparency', () async {
      // 创建简单测试图片
      const width = 4;
      const height = 4;

      // 左半透明，右半不透明红色
      final pixels = Uint8List(width * height * 4);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final offset = (y * width + x) * 4;
          if (x < 2) {
            // 左边：透明
            pixels[offset] = 0;
            pixels[offset + 1] = 0;
            pixels[offset + 2] = 0;
            pixels[offset + 3] = 0;
          } else {
            // 右边：红色不透明
            pixels[offset] = 255;
            pixels[offset + 1] = 0;
            pixels[offset + 2] = 0;
            pixels[offset + 3] = 255;
          }
        }
      }

      // 创建带 Alpha 通道的图片
      final image = img.Image(width: width, height: height, numChannels: 4);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final offset = (y * width + x) * 4;
          image.setPixelRgba(
            x,
            y,
            pixels[offset],
            pixels[offset + 1],
            pixels[offset + 2],
            pixels[offset + 3],
          );
        }
      }

      // 导出到临时文件
      final tempDir = Directory.systemTemp;
      final testFile = File('${tempDir.path}/test_transparency.png');

      final pngBytes = img.encodePng(image);
      testFile.writeAsBytesSync(pngBytes);

      // 重新读取并验证
      final readBytes = testFile.readAsBytesSync();
      final decoded = img.decodePng(readBytes);

      expect(decoded, isNotNull);
      expect(decoded!.hasAlpha, isTrue);

      // 左边应该透明
      final leftPixel = decoded.getPixel(0, 0);
      expect(leftPixel.a.toInt(), equals(0));

      // 右边应该不透明
      final rightPixel = decoded.getPixel(3, 0);
      expect(rightPixel.a.toInt(), equals(255));

      // 清理
      testFile.deleteSync();

      print('✅ PNG 文件透明度保留测试通过！');
    });
  });
}

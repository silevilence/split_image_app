import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('Transparency Export Tests', () {
    test(
      'should preserve alpha channel when creating image from RGBA pixels',
      () {
        // 创建一个 2x2 的测试图片，其中一半是透明的
        const width = 2;
        const height = 2;

        // RGBA 像素数据: 左上透明红, 右上不透明绿, 左下不透明蓝, 右下透明白
        final pixels = Uint8List.fromList([
          255, 0, 0, 0, // 左上: 透明红色 (A=0)
          0, 255, 0, 255, // 右上: 不透明绿色 (A=255)
          0, 0, 255, 255, // 左下: 不透明蓝色 (A=255)
          255, 255, 255, 0, // 右下: 透明白色 (A=0)
        ]);

        // 使用当前代码的方式创建图片
        final imageOld = img.Image(width: width, height: height);
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final offset = (y * width + x) * 4;
            imageOld.setPixelRgba(
              x,
              y,
              pixels[offset], // R
              pixels[offset + 1], // G
              pixels[offset + 2], // B
              pixels[offset + 3], // A
            );
          }
        }

        // 检查旧方式的 Alpha 通道
        print('Old method - numChannels: ${imageOld.numChannels}');
        print('Old method - hasAlpha: ${imageOld.hasAlpha}');

        final pixelOld00 = imageOld.getPixel(0, 0);
        final pixelOld10 = imageOld.getPixel(1, 0);
        print('Old method - pixel(0,0) alpha: ${pixelOld00.a}');
        print('Old method - pixel(1,0) alpha: ${pixelOld10.a}');

        // 使用正确的方式创建带 Alpha 通道的图片
        final imageNew = img.Image(
          width: width,
          height: height,
          numChannels: 4,
        );
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final offset = (y * width + x) * 4;
            imageNew.setPixelRgba(
              x,
              y,
              pixels[offset], // R
              pixels[offset + 1], // G
              pixels[offset + 2], // B
              pixels[offset + 3], // A
            );
          }
        }

        // 检查新方式的 Alpha 通道
        print('New method - numChannels: ${imageNew.numChannels}');
        print('New method - hasAlpha: ${imageNew.hasAlpha}');

        final pixelNew00 = imageNew.getPixel(0, 0);
        final pixelNew10 = imageNew.getPixel(1, 0);
        print('New method - pixel(0,0) alpha: ${pixelNew00.a}');
        print('New method - pixel(1,0) alpha: ${pixelNew10.a}');

        // 验证新方式保留了 Alpha 通道
        expect(imageNew.hasAlpha, isTrue);
        expect(pixelNew00.a.toInt(), equals(0)); // 透明
        expect(pixelNew10.a.toInt(), equals(255)); // 不透明

        // 编码为 PNG 并验证
        final pngBytesOld = img.encodePng(imageOld);
        final pngBytesNew = img.encodePng(imageNew);

        print('Old PNG size: ${pngBytesOld.length} bytes');
        print('New PNG size: ${pngBytesNew.length} bytes');

        // 解码回来验证
        final decodedOld = img.decodePng(Uint8List.fromList(pngBytesOld));
        final decodedNew = img.decodePng(Uint8List.fromList(pngBytesNew));

        print('Decoded old - hasAlpha: ${decodedOld?.hasAlpha}');
        print('Decoded new - hasAlpha: ${decodedNew?.hasAlpha}');

        if (decodedOld != null) {
          final p = decodedOld.getPixel(0, 0);
          print(
            'Decoded old - pixel(0,0): R=${p.r}, G=${p.g}, B=${p.b}, A=${p.a}',
          );
        }

        if (decodedNew != null) {
          final p = decodedNew.getPixel(0, 0);
          print(
            'Decoded new - pixel(0,0): R=${p.r}, G=${p.g}, B=${p.b}, A=${p.a}',
          );
          expect(p.a.toInt(), equals(0)); // 应该是透明的
        }
      },
    );
  });
}

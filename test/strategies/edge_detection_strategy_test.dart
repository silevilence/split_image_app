import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_image_app/models/grid_algorithm_type.dart';
import 'package:split_image_app/models/grid_generator_input.dart';
import 'package:split_image_app/strategies/edge_detection_strategy.dart';
import 'package:split_image_app/strategies/grid_strategy_factory.dart';

void main() {
  group('EdgeDetectionStrategy', () {
    test('should create strategy via factory', () {
      final strategy = GridStrategyFactory.create(
        GridAlgorithmType.edgeDetection,
      );
      expect(strategy, isA<EdgeDetectionStrategy>());
      expect(strategy.type, GridAlgorithmType.edgeDetection);
      expect(strategy.requiresPixelData, true);
    });

    test('should return failure when no pixel data provided', () async {
      final strategy = EdgeDetectionStrategy();

      final input = GridGeneratorInput(
        effectiveRect: const Rect.fromLTWH(0, 0, 100, 100),
        targetRows: 2,
        targetCols: 2,
        imageWidth: 100,
        imageHeight: 100,
        pixelData: null,
      );

      final result = await strategy.generate(input);

      expect(result.success, false);
      expect(result.message, contains('需要像素数据'));
    });

    test('should generate grid lines with valid pixel data', () async {
      final strategy = EdgeDetectionStrategy();

      // 创建一个简单的 100x100 白色图像
      // 中间有一条黑色水平线和一条黑色垂直线
      final pixelData = Uint8List(100 * 100 * 4);
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          final idx = (y * 100 + x) * 4;
          // 默认白色背景
          pixelData[idx] = 255; // R
          pixelData[idx + 1] = 255; // G
          pixelData[idx + 2] = 255; // B
          pixelData[idx + 3] = 255; // A

          // 在 y=50 附近画一条水平黑线
          if (y >= 48 && y <= 52) {
            pixelData[idx] = 0;
            pixelData[idx + 1] = 0;
            pixelData[idx + 2] = 0;
          }

          // 在 x=50 附近画一条垂直黑线
          if (x >= 48 && x <= 52) {
            pixelData[idx] = 0;
            pixelData[idx + 1] = 0;
            pixelData[idx + 2] = 0;
          }
        }
      }

      final input = GridGeneratorInput(
        effectiveRect: const Rect.fromLTWH(0, 0, 100, 100),
        targetRows: 2,
        targetCols: 2,
        imageWidth: 100,
        imageHeight: 100,
        pixelData: pixelData,
        hasUserMargins: true, // 跳过边距检测
      );

      final result = await strategy.generate(input);

      expect(result.success, true);
      expect(result.horizontalLines.length, 1);
      expect(result.verticalLines.length, 1);

      // 水平线应该在图片中间附近 (0.5 左右)
      expect(result.horizontalLines[0], closeTo(0.5, 0.1));
      // 垂直线应该在图片中间附近 (0.5 左右)
      expect(result.verticalLines[0], closeTo(0.5, 0.1));
    });

    test('should detect edges and find low-edge-density areas', () async {
      final strategy = EdgeDetectionStrategy();

      // 创建一个有多个贴纸区域的图像
      // 4个 45x45 的黑色方块，间隔 10 像素
      final pixelData = Uint8List(100 * 100 * 4);
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          final idx = (y * 100 + x) * 4;
          // 默认白色背景
          pixelData[idx] = 255; // R
          pixelData[idx + 1] = 255; // G
          pixelData[idx + 2] = 255; // B
          pixelData[idx + 3] = 255; // A

          // 左上方块 (0-45, 0-45)
          if (x < 45 && y < 45) {
            pixelData[idx] = 100;
            pixelData[idx + 1] = 100;
            pixelData[idx + 2] = 100;
          }
          // 右上方块 (55-100, 0-45)
          if (x >= 55 && y < 45) {
            pixelData[idx] = 100;
            pixelData[idx + 1] = 100;
            pixelData[idx + 2] = 100;
          }
          // 左下方块 (0-45, 55-100)
          if (x < 45 && y >= 55) {
            pixelData[idx] = 100;
            pixelData[idx + 1] = 100;
            pixelData[idx + 2] = 100;
          }
          // 右下方块 (55-100, 55-100)
          if (x >= 55 && y >= 55) {
            pixelData[idx] = 100;
            pixelData[idx + 1] = 100;
            pixelData[idx + 2] = 100;
          }
        }
      }

      final input = GridGeneratorInput(
        effectiveRect: const Rect.fromLTWH(0, 0, 100, 100),
        targetRows: 2,
        targetCols: 2,
        imageWidth: 100,
        imageHeight: 100,
        pixelData: pixelData,
        hasUserMargins: true,
      );

      final result = await strategy.generate(input);

      expect(result.success, true);
      // 期望在 45-55 的间隙区域检测到分割线
      expect(result.horizontalLines.isNotEmpty, true);
      expect(result.verticalLines.isNotEmpty, true);
    });
  });

  group('GridAlgorithmType', () {
    test('edgeDetection should be implemented', () {
      expect(GridAlgorithmType.edgeDetection.isImplemented, true);
      expect(GridAlgorithmType.edgeDetection.displayName, '边缘检测');
      expect(GridAlgorithmType.edgeDetection.description, contains('Sobel'));
    });
  });
}

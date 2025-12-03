import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:split_image_app/utils/image_processor.dart';

void main() {
  group('ExportSlice', () {
    test('should serialize and deserialize correctly', () {
      final slice = ExportSlice(
        x: 10,
        y: 20,
        width: 100,
        height: 200,
        suffix: 'test_slice',
      );

      final map = slice.toMap();
      final restored = ExportSlice.fromMap(map);

      expect(restored.x, 10);
      expect(restored.y, 20);
      expect(restored.width, 100);
      expect(restored.height, 200);
      expect(restored.suffix, 'test_slice');
    });
  });

  group('ExportTask', () {
    test('should serialize and deserialize correctly', () {
      final imageBytes = Uint8List.fromList([1, 2, 3, 4]);
      final slices = [
        ExportSlice(x: 0, y: 0, width: 10, height: 10, suffix: '1_1'),
        ExportSlice(x: 10, y: 0, width: 10, height: 10, suffix: '1_2'),
      ];

      final task = ExportTask(
        imageBytes: imageBytes,
        slices: slices,
        outputDir: '/test/output',
        prefix: 'test',
        format: 'png',
      );

      final map = task.toMap();
      final restored = ExportTask.fromMap(map);

      expect(restored.imageBytes, imageBytes);
      expect(restored.slices.length, 2);
      expect(restored.outputDir, '/test/output');
      expect(restored.prefix, 'test');
      expect(restored.format, 'png');
    });
  });

  group('ExportProgress', () {
    test('should calculate progress correctly', () {
      final progress = ExportProgress(
        current: 5,
        total: 10,
        currentFile: 'test.png',
      );

      expect(progress.progress, 0.5);
      expect(progress.isComplete, false);
      expect(progress.error, null);
    });

    test('should handle zero total', () {
      final progress = ExportProgress(current: 0, total: 0);

      expect(progress.progress, 0.0);
    });

    test('should serialize and deserialize correctly', () {
      final progress = ExportProgress(
        current: 3,
        total: 10,
        currentFile: 'test.png',
        isComplete: false,
        error: null,
      );

      final map = progress.toMap();
      final restored = ExportProgress.fromMap(map);

      expect(restored.current, 3);
      expect(restored.total, 10);
      expect(restored.currentFile, 'test.png');
      expect(restored.isComplete, false);
      expect(restored.error, null);
    });
  });

  group('ImageProcessor.exportSlices', () {
    late Directory tempDir;

    setUp(() async {
      // 创建临时目录
      tempDir = await Directory.systemTemp.createTemp('export_test_');
    });

    tearDown(() async {
      // 清理临时目录
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should export slices with valid coordinates', () async {
      // 创建一个简单的 4x4 红色测试图片
      final image = img.Image(width: 4, height: 4);
      for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          image.setPixelRgba(x, y, 255, 0, 0, 255);
        }
      }
      final imageBytes = Uint8List.fromList(img.encodePng(image));

      final task = ExportTask(
        imageBytes: imageBytes,
        slices: [
          ExportSlice(x: 0, y: 0, width: 2, height: 2, suffix: '1_1'),
          ExportSlice(x: 2, y: 0, width: 2, height: 2, suffix: '1_2'),
        ],
        outputDir: tempDir.path,
        prefix: 'test',
        format: 'png',
      );

      final progressList = <ExportProgress>[];
      await for (final progress in ImageProcessor.exportSlices(task)) {
        progressList.add(progress);
      }

      // 应该有进度更新和完成消息
      expect(progressList.isNotEmpty, true);
      expect(progressList.last.isComplete, true);
      expect(progressList.last.error, null);

      // 检查文件是否创建
      final file1 = File(
        '${tempDir.path}${Platform.pathSeparator}test_1_1.png',
      );
      final file2 = File(
        '${tempDir.path}${Platform.pathSeparator}test_1_2.png',
      );
      expect(await file1.exists(), true);
      expect(await file2.exists(), true);
    });

    test('should handle slices that exceed image bounds', () async {
      // 创建 4x4 图片
      final image = img.Image(width: 4, height: 4);
      final imageBytes = Uint8List.fromList(img.encodePng(image));

      final task = ExportTask(
        imageBytes: imageBytes,
        slices: [
          // 超出边界的切片 - 应该被裁剪处理
          ExportSlice(x: 2, y: 2, width: 10, height: 10, suffix: 'overflow'),
        ],
        outputDir: tempDir.path,
        prefix: 'test',
        format: 'png',
      );

      final progressList = <ExportProgress>[];
      await for (final progress in ImageProcessor.exportSlices(task)) {
        progressList.add(progress);
      }

      // 不应该有错误
      expect(progressList.last.isComplete, true);
      expect(progressList.last.error, null);
    });

    test('should handle edge case coordinates gracefully', () async {
      final image = img.Image(width: 4, height: 4);
      final imageBytes = Uint8List.fromList(img.encodePng(image));

      final task = ExportTask(
        imageBytes: imageBytes,
        slices: [
          // x=10 会被 clamp 到 3，width 会变成 1
          // 这是边界处理的预期行为
          ExportSlice(x: 10, y: 10, width: 2, height: 2, suffix: 'edge_case'),
        ],
        outputDir: tempDir.path,
        prefix: 'test',
        format: 'png',
      );

      final progressList = <ExportProgress>[];
      await for (final progress in ImageProcessor.exportSlices(task)) {
        progressList.add(progress);
      }

      // 应该完成，边界被自动修正
      expect(progressList.last.isComplete, true);
      expect(progressList.last.error, null);

      // 边界修正后文件会被创建（尺寸为 1x1）
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}test_edge_case.png',
      );
      expect(await file.exists(), true);
    });

    test('should export in jpg format', () async {
      final image = img.Image(width: 4, height: 4);
      for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          image.setPixelRgba(x, y, 0, 255, 0, 255);
        }
      }
      final imageBytes = Uint8List.fromList(img.encodePng(image));

      final task = ExportTask(
        imageBytes: imageBytes,
        slices: [ExportSlice(x: 0, y: 0, width: 4, height: 4, suffix: 'full')],
        outputDir: tempDir.path,
        prefix: 'test',
        format: 'jpg',
      );

      await for (final _ in ImageProcessor.exportSlices(task)) {}

      final file = File(
        '${tempDir.path}${Platform.pathSeparator}test_full.jpg',
      );
      expect(await file.exists(), true);
    });
  });
}

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 导出任务数据
class ExportTask {
  /// 原图字节数据
  final Uint8List imageBytes;

  /// 要导出的切片列表
  final List<ExportSlice> slices;

  /// 输出目录
  final String outputDir;

  /// 文件前缀
  final String prefix;

  /// 导出格式 (png, jpg, webp)
  final String format;

  ExportTask({
    required this.imageBytes,
    required this.slices,
    required this.outputDir,
    required this.prefix,
    this.format = 'png',
  });

  /// 转换为可跨 Isolate 传递的 Map
  Map<String, dynamic> toMap() {
    return {
      'imageBytes': imageBytes,
      'slices': slices.map((s) => s.toMap()).toList(),
      'outputDir': outputDir,
      'prefix': prefix,
      'format': format,
    };
  }

  /// 从 Map 恢复
  static ExportTask fromMap(Map<String, dynamic> map) {
    return ExportTask(
      imageBytes: map['imageBytes'] as Uint8List,
      slices: (map['slices'] as List)
          .map((s) => ExportSlice.fromMap(s as Map<String, dynamic>))
          .toList(),
      outputDir: map['outputDir'] as String,
      prefix: map['prefix'] as String,
      format: map['format'] as String? ?? 'png',
    );
  }
}

/// 单个切片的导出信息
class ExportSlice {
  /// 在原图中的位置 (x, y, width, height)
  final int x;
  final int y;
  final int width;
  final int height;

  /// 文件后缀名
  final String suffix;

  /// 已处理的像素数据（RGBA 格式）
  /// 如果为 null，则从原图裁剪
  final Uint8List? processedPixels;

  /// 处理后的宽度（仅当 processedPixels 不为 null 时有效）
  final int? processedWidth;

  /// 处理后的高度（仅当 processedPixels 不为 null 时有效）
  final int? processedHeight;

  ExportSlice({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.suffix,
    this.processedPixels,
    this.processedWidth,
    this.processedHeight,
  });

  /// 是否有处理后的数据
  bool get hasProcessedData => processedPixels != null;

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'suffix': suffix,
      'processedPixels': processedPixels,
      'processedWidth': processedWidth,
      'processedHeight': processedHeight,
    };
  }

  static ExportSlice fromMap(Map<String, dynamic> map) {
    return ExportSlice(
      x: map['x'] as int,
      y: map['y'] as int,
      width: map['width'] as int,
      height: map['height'] as int,
      suffix: map['suffix'] as String,
      processedPixels: map['processedPixels'] as Uint8List?,
      processedWidth: map['processedWidth'] as int?,
      processedHeight: map['processedHeight'] as int?,
    );
  }
}

/// 导出进度消息
class ExportProgress {
  /// 当前处理的索引（从 0 开始）
  final int current;

  /// 总数
  final int total;

  /// 当前处理的文件名
  final String? currentFile;

  /// 是否完成
  final bool isComplete;

  /// 错误信息（如果有）
  final String? error;

  ExportProgress({
    required this.current,
    required this.total,
    this.currentFile,
    this.isComplete = false,
    this.error,
  });

  double get progress => total > 0 ? current / total : 0;

  Map<String, dynamic> toMap() {
    return {
      'current': current,
      'total': total,
      'currentFile': currentFile,
      'isComplete': isComplete,
      'error': error,
    };
  }

  static ExportProgress fromMap(Map<String, dynamic> map) {
    return ExportProgress(
      current: map['current'] as int,
      total: map['total'] as int,
      currentFile: map['currentFile'] as String?,
      isComplete: map['isComplete'] as bool,
      error: map['error'] as String?,
    );
  }
}

/// 图片处理器
class ImageProcessor {
  /// 在 Isolate 中执行导出任务
  /// 返回一个 Stream，用于接收进度更新
  static Stream<ExportProgress> exportSlices(ExportTask task) async* {
    final receivePort = ReceivePort();

    await Isolate.spawn(_exportIsolate, {
      'sendPort': receivePort.sendPort,
      'task': task.toMap(),
    });

    await for (final message in receivePort) {
      if (message is Map<String, dynamic>) {
        final progress = ExportProgress.fromMap(message);
        yield progress;
        if (progress.isComplete || progress.error != null) {
          receivePort.close();
          break;
        }
      }
    }
  }

  /// Isolate 入口函数
  static void _exportIsolate(Map<String, dynamic> message) {
    final sendPort = message['sendPort'] as SendPort;
    final task = ExportTask.fromMap(message['task'] as Map<String, dynamic>);

    try {
      // 解码原图（仅当有未处理的切片时需要）
      img.Image? image;
      int imageWidth = 0;
      int imageHeight = 0;

      // 检查是否有需要从原图裁剪的切片
      final needsOriginal = task.slices.any((s) => !s.hasProcessedData);
      if (needsOriginal) {
        image = img.decodeImage(task.imageBytes);
        if (image == null) {
          sendPort.send(
            ExportProgress(
              current: 0,
              total: task.slices.length,
              error: '无法解码图片',
            ).toMap(),
          );
          return;
        }
        imageWidth = image.width;
        imageHeight = image.height;
      }

      final total = task.slices.length;

      for (var i = 0; i < task.slices.length; i++) {
        final slice = task.slices[i];

        // 生成文件名
        final ext = task.format.toLowerCase();
        final fileName = task.prefix.isEmpty
            ? '${slice.suffix}.$ext'
            : '${task.prefix}_${slice.suffix}.$ext';
        final filePath = '${task.outputDir}${Platform.pathSeparator}$fileName';

        // 发送进度
        sendPort.send(
          ExportProgress(
            current: i,
            total: total,
            currentFile: fileName,
          ).toMap(),
        );

        img.Image imageToSave;

        if (slice.hasProcessedData) {
          // 使用处理后的像素数据
          final w = slice.processedWidth!;
          final h = slice.processedHeight!;
          final pixels = slice.processedPixels!;

          // 从 RGBA 像素数据创建图片
          imageToSave = img.Image(width: w, height: h);
          for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
              final offset = (y * w + x) * 4;
              imageToSave.setPixelRgba(
                x,
                y,
                pixels[offset], // R
                pixels[offset + 1], // G
                pixels[offset + 2], // B
                pixels[offset + 3], // A
              );
            }
          }
        } else {
          // 从原图裁剪
          if (image == null) {
            continue; // 不应该发生
          }

          // 边界检查和修正
          int x = slice.x.clamp(0, imageWidth - 1);
          int y = slice.y.clamp(0, imageHeight - 1);
          int width = slice.width;
          int height = slice.height;

          // 确保不超出图片边界
          if (x + width > imageWidth) {
            width = imageWidth - x;
          }
          if (y + height > imageHeight) {
            height = imageHeight - y;
          }

          // 确保尺寸有效
          if (width <= 0 || height <= 0) {
            continue; // 跳过无效切片
          }

          // 裁剪图片
          imageToSave = img.copyCrop(
            image,
            x: x,
            y: y,
            width: width,
            height: height,
          );
        }

        // 根据格式编码
        late List<int> encodedBytes;
        switch (task.format.toLowerCase()) {
          case 'jpg':
          case 'jpeg':
            encodedBytes = img.encodeJpg(imageToSave, quality: 95);
            break;
          case 'png':
          default:
            encodedBytes = img.encodePng(imageToSave);
            break;
        }
        File(filePath).writeAsBytesSync(encodedBytes);
      }

      // 完成
      sendPort.send(
        ExportProgress(current: total, total: total, isComplete: true).toMap(),
      );
    } catch (e, stackTrace) {
      sendPort.send(
        ExportProgress(
          current: 0,
          total: task.slices.length,
          error: '导出失败: $e\n$stackTrace',
        ).toMap(),
      );
    }
  }
}

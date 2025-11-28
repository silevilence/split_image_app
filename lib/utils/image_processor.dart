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

  ExportTask({
    required this.imageBytes,
    required this.slices,
    required this.outputDir,
    required this.prefix,
  });

  /// 转换为可跨 Isolate 传递的 Map
  Map<String, dynamic> toMap() {
    return {
      'imageBytes': imageBytes,
      'slices': slices.map((s) => s.toMap()).toList(),
      'outputDir': outputDir,
      'prefix': prefix,
    };
  }

  /// 从 Map 恢复
  static ExportTask fromMap(Map<String, dynamic> map) {
    return ExportTask(
      imageBytes: map['imageBytes'] as Uint8List,
      slices: (map['slices'] as List).map((s) => ExportSlice.fromMap(s as Map<String, dynamic>)).toList(),
      outputDir: map['outputDir'] as String,
      prefix: map['prefix'] as String,
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

  ExportSlice({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.suffix,
  });

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'suffix': suffix,
    };
  }

  static ExportSlice fromMap(Map<String, dynamic> map) {
    return ExportSlice(
      x: map['x'] as int,
      y: map['y'] as int,
      width: map['width'] as int,
      height: map['height'] as int,
      suffix: map['suffix'] as String,
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
    
    await Isolate.spawn(
      _exportIsolate,
      {
        'sendPort': receivePort.sendPort,
        'task': task.toMap(),
      },
    );

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
      // 解码原图
      final image = img.decodeImage(task.imageBytes);
      if (image == null) {
        sendPort.send(ExportProgress(
          current: 0,
          total: task.slices.length,
          error: '无法解码图片',
        ).toMap());
        return;
      }

      final total = task.slices.length;

      for (var i = 0; i < task.slices.length; i++) {
        final slice = task.slices[i];
        
        // 生成文件名
        final fileName = task.prefix.isEmpty
            ? '${slice.suffix}.png'
            : '${task.prefix}_${slice.suffix}.png';
        final filePath = '${task.outputDir}${Platform.pathSeparator}$fileName';

        // 发送进度
        sendPort.send(ExportProgress(
          current: i,
          total: total,
          currentFile: fileName,
        ).toMap());

        // 裁剪图片
        final cropped = img.copyCrop(
          image,
          x: slice.x,
          y: slice.y,
          width: slice.width,
          height: slice.height,
        );

        // 编码并保存
        final pngBytes = img.encodePng(cropped);
        File(filePath).writeAsBytesSync(pngBytes);
      }

      // 完成
      sendPort.send(ExportProgress(
        current: total,
        total: total,
        isComplete: true,
      ).toMap());
    } catch (e) {
      sendPort.send(ExportProgress(
        current: 0,
        total: task.slices.length,
        error: e.toString(),
      ).toMap());
    }
  }
}

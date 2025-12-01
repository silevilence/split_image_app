import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// 处理器输入数据
///
/// 包含待处理的图片数据和元信息。
@immutable
class ProcessorInput {
  /// 图片像素数据 (RGBA 格式)
  final Uint8List pixels;

  /// 图片宽度
  final int width;

  /// 图片高度
  final int height;

  /// 切片索引 (用于调试和日志)
  final int? sliceIndex;

  /// 切片行号
  final int? row;

  /// 切片列号
  final int? col;

  /// 额外元数据
  final Map<String, dynamic> metadata;

  const ProcessorInput({
    required this.pixels,
    required this.width,
    required this.height,
    this.sliceIndex,
    this.row,
    this.col,
    this.metadata = const {},
  });

  /// 像素数量
  int get pixelCount => width * height;

  /// 每行字节数 (RGBA = 4 bytes per pixel)
  int get bytesPerRow => width * 4;

  /// 总字节数
  int get totalBytes => pixels.length;

  /// 从 dart:ui Image 创建输入
  ///
  /// 注意：此方法会消耗 UI 资源，应在主线程调用
  static Future<ProcessorInput> fromImage(
    ui.Image image, {
    int? sliceIndex,
    int? row,
    int? col,
    Map<String, dynamic> metadata = const {},
  }) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw Exception('Failed to get image byte data');
    }

    return ProcessorInput(
      pixels: byteData.buffer.asUint8List(),
      width: image.width,
      height: image.height,
      sliceIndex: sliceIndex,
      row: row,
      col: col,
      metadata: metadata,
    );
  }

  /// 获取指定位置的像素 RGBA 值
  ///
  /// 返回 [r, g, b, a]，如果坐标越界返回 null
  List<int>? getPixelAt(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return null;
    final offset = (y * width + x) * 4;
    return [
      pixels[offset],
      pixels[offset + 1],
      pixels[offset + 2],
      pixels[offset + 3],
    ];
  }

  /// 复制并更新元数据
  ProcessorInput copyWith({
    Uint8List? pixels,
    int? width,
    int? height,
    Map<String, dynamic>? metadata,
  }) {
    return ProcessorInput(
      pixels: pixels ?? this.pixels,
      width: width ?? this.width,
      height: height ?? this.height,
      sliceIndex: sliceIndex,
      row: row,
      col: col,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() =>
      'ProcessorInput(${width}x$height, slice: $sliceIndex, row: $row, col: $col)';
}

/// 处理器输出数据
///
/// 包含处理后的图片数据和变更信息。
@immutable
class ProcessorOutput {
  /// 处理后的像素数据 (RGBA 格式)
  final Uint8List pixels;

  /// 输出图片宽度
  final int width;

  /// 输出图片高度
  final int height;

  /// 是否有变更（如果处理器未修改图片，可以返回 false 以优化性能）
  final bool hasChanges;

  /// 处理耗时（毫秒）
  final int? processingTimeMs;

  /// 处理器 ID（来源标识）
  final String? processorId;

  /// 额外元数据
  final Map<String, dynamic> metadata;

  const ProcessorOutput({
    required this.pixels,
    required this.width,
    required this.height,
    this.hasChanges = true,
    this.processingTimeMs,
    this.processorId,
    this.metadata = const {},
  });

  /// 从输入直接创建输出（无变更）
  factory ProcessorOutput.unchanged(
    ProcessorInput input, {
    String? processorId,
  }) {
    return ProcessorOutput(
      pixels: input.pixels,
      width: input.width,
      height: input.height,
      hasChanges: false,
      processorId: processorId,
      metadata: input.metadata,
    );
  }

  /// 转换为 ProcessorInput 以便传递给下一个处理器
  ProcessorInput toInput({int? sliceIndex, int? row, int? col}) {
    return ProcessorInput(
      pixels: pixels,
      width: width,
      height: height,
      sliceIndex: sliceIndex,
      row: row,
      col: col,
      metadata: metadata,
    );
  }

  /// 将处理结果转换为 dart:ui Image
  ///
  /// 注意：此方法会消耗 UI 资源，返回的 Image 需要手动 dispose
  Future<ui.Image> toImage() async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (image) => completer.complete(image),
    );
    return completer.future;
  }

  @override
  String toString() =>
      'ProcessorOutput(${width}x$height, changed: $hasChanges, processor: $processorId)';
}

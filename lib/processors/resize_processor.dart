import 'dart:typed_data';

import 'processor_io.dart';
import 'processor_param.dart';
import 'image_processor.dart';

/// 调整大小处理器
///
/// 使用双线性插值算法调整图片尺寸。
/// 支持像素和百分比两种单位，以及保持宽高比的自动计算。
class ResizeProcessor extends ImageProcessor {
  @override
  final ProcessorType type = ProcessorType.resize;

  ResizeProcessor({
    required super.instanceId,
    super.customName,
    super.globalParams,
  });

  @override
  List<ProcessorParamDef> get paramDefinitions => [
    // Global: Width
    const ProcessorParamDef(
      id: 'width',
      displayName: '宽度',
      description: '目标宽度，0 表示自动按比例计算',
      type: ParamType.integer,
      defaultValue: 0,
      minValue: 0,
      maxValue: 10000,
      supportsPerImageOverride: false,
    ),
    // Global: Height
    const ProcessorParamDef(
      id: 'height',
      displayName: '高度',
      description: '目标高度，0 表示自动按比例计算',
      type: ParamType.integer,
      defaultValue: 0,
      minValue: 0,
      maxValue: 10000,
      supportsPerImageOverride: false,
    ),
    // Global: Unit
    const ProcessorParamDef(
      id: 'unit',
      displayName: '单位',
      description: 'pixel=像素, percent=百分比',
      type: ParamType.enumChoice,
      defaultValue: 'pixel',
      enumOptions: ['pixel', 'percent'],
      supportsPerImageOverride: false,
    ),
  ];

  @override
  Future<ProcessorOutput> process(
    ProcessorInput input,
    ProcessorParams params,
  ) async {
    final stopwatch = Stopwatch()..start();

    var targetWidth = getParam<int>(params, 'width');
    var targetHeight = getParam<int>(params, 'height');
    final unit = getParam<String>(params, 'unit');

    final srcWidth = input.width;
    final srcHeight = input.height;

    // 如果两个都是 0，返回未修改的图片
    if (targetWidth == 0 && targetHeight == 0) {
      return ProcessorOutput.unchanged(input, processorId: instanceId);
    }

    // 如果是百分比单位，转换为像素值
    if (unit == 'percent') {
      if (targetWidth > 0) {
        targetWidth = (srcWidth * targetWidth / 100).round();
      }
      if (targetHeight > 0) {
        targetHeight = (srcHeight * targetHeight / 100).round();
      }
    }

    // 如果一个维度为 0，按比例计算
    if (targetWidth == 0 && targetHeight > 0) {
      targetWidth = (srcWidth * targetHeight / srcHeight).round();
    } else if (targetHeight == 0 && targetWidth > 0) {
      targetHeight = (srcHeight * targetWidth / srcWidth).round();
    }

    // 确保最小尺寸为 1
    targetWidth = targetWidth.clamp(1, 10000);
    targetHeight = targetHeight.clamp(1, 10000);

    // 如果尺寸没有变化，返回未修改的图片
    if (targetWidth == srcWidth && targetHeight == srcHeight) {
      return ProcessorOutput.unchanged(input, processorId: instanceId);
    }

    // 使用双线性插值缩放
    final newPixels = _bilinearResize(
      input.pixels,
      srcWidth,
      srcHeight,
      targetWidth,
      targetHeight,
    );

    stopwatch.stop();

    return ProcessorOutput(
      pixels: newPixels,
      width: targetWidth,
      height: targetHeight,
      hasChanges: true,
      processingTimeMs: stopwatch.elapsedMilliseconds,
      processorId: instanceId,
      metadata: {
        ...input.metadata,
        'originalSize': '${srcWidth}x$srcHeight',
        'newSize': '${targetWidth}x$targetHeight',
        'scaleX': (targetWidth / srcWidth).toStringAsFixed(2),
        'scaleY': (targetHeight / srcHeight).toStringAsFixed(2),
      },
    );
  }

  /// 双线性插值缩放算法
  Uint8List _bilinearResize(
    Uint8List src,
    int srcWidth,
    int srcHeight,
    int dstWidth,
    int dstHeight,
  ) {
    final dst = Uint8List(dstWidth * dstHeight * 4);

    final scaleX = srcWidth / dstWidth;
    final scaleY = srcHeight / dstHeight;

    for (int dstY = 0; dstY < dstHeight; dstY++) {
      for (int dstX = 0; dstX < dstWidth; dstX++) {
        // 计算源图像中的对应位置
        final srcXf = (dstX + 0.5) * scaleX - 0.5;
        final srcYf = (dstY + 0.5) * scaleY - 0.5;

        final x0 = srcXf.floor().clamp(0, srcWidth - 1);
        final y0 = srcYf.floor().clamp(0, srcHeight - 1);
        final x1 = (x0 + 1).clamp(0, srcWidth - 1);
        final y1 = (y0 + 1).clamp(0, srcHeight - 1);

        // 计算插值权重
        final xWeight = srcXf - x0;
        final yWeight = srcYf - y0;

        // 获取四个相邻像素
        final offset00 = (y0 * srcWidth + x0) * 4;
        final offset01 = (y0 * srcWidth + x1) * 4;
        final offset10 = (y1 * srcWidth + x0) * 4;
        final offset11 = (y1 * srcWidth + x1) * 4;

        // 对每个通道进行双线性插值
        final dstOffset = (dstY * dstWidth + dstX) * 4;

        for (int c = 0; c < 4; c++) {
          final v00 = src[offset00 + c];
          final v01 = src[offset01 + c];
          final v10 = src[offset10 + c];
          final v11 = src[offset11 + c];

          // 双线性插值公式
          final v0 = v00 + (v01 - v00) * xWeight;
          final v1 = v10 + (v11 - v10) * xWeight;
          final v = v0 + (v1 - v0) * yWeight;

          dst[dstOffset + c] = v.round().clamp(0, 255);
        }
      }
    }

    return dst;
  }
}

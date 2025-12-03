import 'dart:typed_data';

import 'processor_io.dart';
import 'processor_param.dart';
import 'image_processor.dart';

/// 边缘裁剪处理器
///
/// 按用户指定的边距值直接裁剪图片四周。
/// 边距值表示从各边向内裁剪的像素数。
class SmartCropProcessor extends ImageProcessor {
  @override
  final ProcessorType type = ProcessorType.smartCrop;

  SmartCropProcessor({
    required super.instanceId,
    super.customName,
    super.globalParams,
  });

  @override
  List<ProcessorParamDef> get paramDefinitions => [
    // Per-Image: Crop Top
    const ProcessorParamDef(
      id: 'marginTop',
      displayName: '裁剪上边',
      description: '从顶部向内裁剪的像素数',
      type: ParamType.integer,
      defaultValue: 0,
      minValue: 0,
      maxValue: 1000,
      supportsPerImageOverride: true,
    ),
    // Per-Image: Crop Bottom
    const ProcessorParamDef(
      id: 'marginBottom',
      displayName: '裁剪下边',
      description: '从底部向内裁剪的像素数',
      type: ParamType.integer,
      defaultValue: 0,
      minValue: 0,
      maxValue: 1000,
      supportsPerImageOverride: true,
    ),
    // Per-Image: Crop Left
    const ProcessorParamDef(
      id: 'marginLeft',
      displayName: '裁剪左边',
      description: '从左侧向内裁剪的像素数',
      type: ParamType.integer,
      defaultValue: 0,
      minValue: 0,
      maxValue: 1000,
      supportsPerImageOverride: true,
    ),
    // Per-Image: Crop Right
    const ProcessorParamDef(
      id: 'marginRight',
      displayName: '裁剪右边',
      description: '从右侧向内裁剪的像素数',
      type: ParamType.integer,
      defaultValue: 0,
      minValue: 0,
      maxValue: 1000,
      supportsPerImageOverride: true,
    ),
  ];

  @override
  Future<ProcessorOutput> process(
    ProcessorInput input,
    ProcessorParams params,
  ) async {
    final stopwatch = Stopwatch()..start();

    final cropTop = getParam<int>(params, 'marginTop');
    final cropBottom = getParam<int>(params, 'marginBottom');
    final cropLeft = getParam<int>(params, 'marginLeft');
    final cropRight = getParam<int>(params, 'marginRight');

    final pixels = input.pixels;
    final width = input.width;
    final height = input.height;

    // 检查裁剪值是否有效
    if (cropTop + cropBottom >= height || cropLeft + cropRight >= width) {
      // 裁剪区域超出图片范围，返回未修改的图片
      return ProcessorOutput.unchanged(input, processorId: instanceId);
    }

    // 如果所有裁剪值都为 0，返回未修改的图片
    if (cropTop == 0 && cropBottom == 0 && cropLeft == 0 && cropRight == 0) {
      return ProcessorOutput.unchanged(input, processorId: instanceId);
    }

    // 计算新尺寸
    final newWidth = width - cropLeft - cropRight;
    final newHeight = height - cropTop - cropBottom;

    // 确保尺寸有效
    if (newWidth <= 0 || newHeight <= 0) {
      return ProcessorOutput.unchanged(input, processorId: instanceId);
    }

    // 创建新的像素数据
    final newPixels = Uint8List(newWidth * newHeight * 4);

    for (int y = 0; y < newHeight; y++) {
      final srcY = y + cropTop;
      for (int x = 0; x < newWidth; x++) {
        final srcX = x + cropLeft;
        final srcOffset = (srcY * width + srcX) * 4;
        final dstOffset = (y * newWidth + x) * 4;

        newPixels[dstOffset] = pixels[srcOffset];
        newPixels[dstOffset + 1] = pixels[srcOffset + 1];
        newPixels[dstOffset + 2] = pixels[srcOffset + 2];
        newPixels[dstOffset + 3] = pixels[srcOffset + 3];
      }
    }

    stopwatch.stop();

    return ProcessorOutput(
      pixels: newPixels,
      width: newWidth,
      height: newHeight,
      hasChanges: true,
      processingTimeMs: stopwatch.elapsedMilliseconds,
      processorId: instanceId,
      metadata: {
        ...input.metadata,
        'originalSize': '${width}x$height',
        'croppedSize': '${newWidth}x$newHeight',
        'cropValues': {
          'top': cropTop,
          'bottom': cropBottom,
          'left': cropLeft,
          'right': cropRight,
        },
      },
    );
  }
}

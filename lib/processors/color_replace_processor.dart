import 'dart:typed_data';

import 'processor_io.dart';
import 'processor_param.dart';
import 'image_processor.dart';

/// 颜色替换处理器
///
/// 将图片中的指定颜色替换为另一种颜色。
/// 支持阈值容差，可以替换相似颜色的范围。
class ColorReplaceProcessor extends ImageProcessor {
  @override
  final ProcessorType type = ProcessorType.colorReplace;

  ColorReplaceProcessor({
    required super.instanceId,
    super.customName,
    super.globalParams,
  });

  @override
  List<ProcessorParamDef> get paramDefinitions => [
    // Global: Target Color
    const ProcessorParamDef(
      id: 'targetColor',
      displayName: '目标颜色',
      description: '要被替换的目标颜色',
      type: ParamType.color,
      defaultValue: 0xFFFFFFFF, // 白色
      supportsPerImageOverride: false,
    ),
    // Global: New Color
    const ProcessorParamDef(
      id: 'newColor',
      displayName: '新颜色',
      description: '替换成的新颜色',
      type: ParamType.color,
      defaultValue: 0x00000000, // 透明
      supportsPerImageOverride: false,
    ),
    // Per-Image: Threshold
    const ProcessorParamDef(
      id: 'threshold',
      displayName: '容差',
      description: '颜色匹配的容差值，越大范围越广',
      type: ParamType.integer,
      defaultValue: 20,
      minValue: 0,
      maxValue: 255,
      supportsPerImageOverride: true,
    ),
  ];

  @override
  Future<ProcessorOutput> process(
    ProcessorInput input,
    ProcessorParams params,
  ) async {
    final stopwatch = Stopwatch()..start();

    final targetColor = getParam<int>(params, 'targetColor');
    final newColor = getParam<int>(params, 'newColor');
    final threshold = getParam<int>(params, 'threshold');

    // 提取目标颜色的 RGBA 分量
    final targetA = (targetColor >> 24) & 0xFF;
    final targetR = (targetColor >> 16) & 0xFF;
    final targetG = (targetColor >> 8) & 0xFF;
    final targetB = targetColor & 0xFF;

    // 提取新颜色的 RGBA 分量
    final newA = (newColor >> 24) & 0xFF;
    final newR = (newColor >> 16) & 0xFF;
    final newG = (newColor >> 8) & 0xFF;
    final newB = newColor & 0xFF;

    // 复制像素数据
    final pixels = Uint8List.fromList(input.pixels);
    final pixelCount = input.width * input.height;

    int changedPixels = 0;

    for (int i = 0; i < pixelCount; i++) {
      final offset = i * 4;
      final r = pixels[offset];
      final g = pixels[offset + 1];
      final b = pixels[offset + 2];
      final a = pixels[offset + 3];

      // 检查是否与目标颜色匹配
      if (_isColorMatch(
        r,
        g,
        b,
        a,
        targetR,
        targetG,
        targetB,
        targetA,
        threshold,
      )) {
        pixels[offset] = newR;
        pixels[offset + 1] = newG;
        pixels[offset + 2] = newB;
        pixels[offset + 3] = newA;
        changedPixels++;
      }
    }

    stopwatch.stop();

    // 如果没有变更，返回未修改的输出
    if (changedPixels == 0) {
      return ProcessorOutput.unchanged(input, processorId: instanceId);
    }

    return ProcessorOutput(
      pixels: pixels,
      width: input.width,
      height: input.height,
      hasChanges: true,
      processingTimeMs: stopwatch.elapsedMilliseconds,
      processorId: instanceId,
      metadata: {
        ...input.metadata,
        'changedPixels': changedPixels,
        'percentChanged': (changedPixels * 100 / pixelCount).toStringAsFixed(1),
      },
    );
  }

  /// 检查像素是否与目标颜色匹配（在阈值范围内）
  bool _isColorMatch(
    int r,
    int g,
    int b,
    int a,
    int targetR,
    int targetG,
    int targetB,
    int targetA,
    int threshold,
  ) {
    final dr = (r - targetR).abs();
    final dg = (g - targetG).abs();
    final db = (b - targetB).abs();
    final da = (a - targetA).abs();

    return dr <= threshold &&
        dg <= threshold &&
        db <= threshold &&
        da <= threshold;
  }
}

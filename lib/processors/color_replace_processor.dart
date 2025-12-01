import 'processor_io.dart';
import 'processor_param.dart';
import 'image_processor.dart';

/// 颜色替换处理器
///
/// 将图片中的指定颜色替换为另一种颜色。
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
      displayName: 'Target Color',
      description: '要被替换的目标颜色',
      type: ParamType.color,
      defaultValue: 0xFFFFFFFF, // 白色
      supportsPerImageOverride: false,
    ),
    // Global: New Color
    const ProcessorParamDef(
      id: 'newColor',
      displayName: 'New Color',
      description: '替换成的新颜色',
      type: ParamType.color,
      defaultValue: 0x00000000, // 透明
      supportsPerImageOverride: false,
    ),
    // Per-Image: Threshold
    const ProcessorParamDef(
      id: 'threshold',
      displayName: 'Threshold',
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
    // TODO: 实现实际的颜色替换逻辑
    // 目前返回未修改的图片
    return ProcessorOutput.unchanged(input, processorId: instanceId);
  }
}

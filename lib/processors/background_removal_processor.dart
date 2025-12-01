import 'processor_io.dart';
import 'processor_param.dart';
import 'image_processor.dart';

/// 背景移除处理器
///
/// 移除图片中的背景，支持透明背景和颜色背景检测。
class BackgroundRemovalProcessor extends ImageProcessor {
  @override
  final ProcessorType type = ProcessorType.backgroundRemoval;

  BackgroundRemovalProcessor({
    required super.instanceId,
    super.customName,
    super.globalParams,
  });

  @override
  List<ProcessorParamDef> get paramDefinitions => [
    // Global: 阈值
    const ProcessorParamDef(
      id: 'threshold',
      displayName: '阈值',
      description: '背景检测的颜色容差值，越大越宽松',
      type: ParamType.integer,
      defaultValue: 30,
      minValue: 0,
      maxValue: 255,
      supportsPerImageOverride: false,
    ),
    // Global: 替换色/透明
    const ProcessorParamDef(
      id: 'replaceColor',
      displayName: '替换色',
      description: '背景移除后的填充色，透明=0x00000000',
      type: ParamType.color,
      defaultValue: 0x00000000, // 透明
      supportsPerImageOverride: false,
    ),
  ];

  @override
  Future<ProcessorOutput> process(
    ProcessorInput input,
    ProcessorParams params,
  ) async {
    // TODO: 实现实际的背景移除逻辑
    // 目前返回未修改的图片
    return ProcessorOutput.unchanged(input, processorId: instanceId);
  }
}

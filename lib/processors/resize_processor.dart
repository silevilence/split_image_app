import 'processor_io.dart';
import 'processor_param.dart';
import 'image_processor.dart';

/// 调整大小处理器
///
/// 调整图片的尺寸，支持多种缩放模式。
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
      displayName: 'Width',
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
      displayName: 'Height',
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
      displayName: 'Unit',
      description: '尺寸单位: pixel=像素, percent=百分比',
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
    // TODO: 实现实际的调整大小逻辑
    // 目前返回未修改的图片
    return ProcessorOutput.unchanged(input, processorId: instanceId);
  }
}

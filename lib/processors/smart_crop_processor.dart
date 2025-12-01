import 'processor_io.dart';
import 'processor_param.dart';
import 'image_processor.dart';

/// 智能裁剪处理器
///
/// 自动检测图片内容边界并裁剪多余空白。
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
    // Per-Image: Margin Top
    const ProcessorParamDef(
      id: 'marginTop',
      displayName: '上边距',
      description: '裁剪后顶部保留的边距 (像素)',
      type: ParamType.integer,
      defaultValue: 0,
      minValue: 0,
      maxValue: 500,
      supportsPerImageOverride: true,
    ),
    // Per-Image: Margin Bottom
    const ProcessorParamDef(
      id: 'marginBottom',
      displayName: '下边距',
      description: '裁剪后底部保留的边距 (像素)',
      type: ParamType.integer,
      defaultValue: 0,
      minValue: 0,
      maxValue: 500,
      supportsPerImageOverride: true,
    ),
    // Per-Image: Margin Left
    const ProcessorParamDef(
      id: 'marginLeft',
      displayName: '左边距',
      description: '裁剪后左侧保留的边距 (像素)',
      type: ParamType.integer,
      defaultValue: 0,
      minValue: 0,
      maxValue: 500,
      supportsPerImageOverride: true,
    ),
    // Per-Image: Margin Right
    const ProcessorParamDef(
      id: 'marginRight',
      displayName: '右边距',
      description: '裁剪后右侧保留的边距 (像素)',
      type: ParamType.integer,
      defaultValue: 0,
      minValue: 0,
      maxValue: 500,
      supportsPerImageOverride: true,
    ),
  ];

  @override
  Future<ProcessorOutput> process(
    ProcessorInput input,
    ProcessorParams params,
  ) async {
    // TODO: 实现实际的智能裁剪逻辑
    // 目前返回未修改的图片
    return ProcessorOutput.unchanged(input, processorId: instanceId);
  }
}

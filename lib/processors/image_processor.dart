import 'processor_io.dart';
import 'processor_param.dart';

/// 图片处理器类型枚举
enum ProcessorType {
  /// 背景移除
  backgroundRemoval(
    id: 'background_removal',
    displayName: '背景移除',
    description: '基于魔棒算法移除背景色',
  ),

  /// 智能裁剪
  smartCrop(id: 'smart_crop', displayName: '智能裁剪', description: '自动裁剪图片边缘空白'),

  /// 颜色替换
  colorReplace(
    id: 'color_replace',
    displayName: '颜色替换',
    description: '将指定颜色替换为另一种颜色',
  ),

  /// 强制缩放
  resize(id: 'resize', displayName: '强制缩放', description: '将图片缩放到指定尺寸');

  const ProcessorType({
    required this.id,
    required this.displayName,
    required this.description,
  });

  /// 处理器唯一标识
  final String id;

  /// 显示名称
  final String displayName;

  /// 描述
  final String description;

  /// 从 ID 获取类型
  static ProcessorType? fromId(String id) {
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

/// 图片处理器抽象基类
///
/// 使用策略模式定义图片后处理算法。
/// 每个处理器负责单一的图片处理任务（如背景移除、裁剪、缩放等）。
///
/// ## 实现新处理器
/// 1. 在 [ProcessorType] 添加枚举值
/// 2. 创建新的处理器类继承 [ImageProcessor]
/// 3. 实现 [process] 方法
/// 4. 定义参数 [paramDefinitions]
/// 5. 在 [ProcessorFactory] 注册
abstract class ImageProcessor {
  /// 获取处理器类型
  ProcessorType get type;

  /// 处理器实例唯一 ID（用于区分同类型的多个实例）
  final String instanceId;

  /// 自定义名称（用于显示，如 "Crop-1", "Crop-2"）
  String customName;

  /// 是否启用
  bool enabled;

  /// 全局参数
  ProcessorParams globalParams;

  ImageProcessor({
    required this.instanceId,
    String? customName,
    this.enabled = true,
    ProcessorParams? globalParams,
  }) : customName = customName ?? '',
       globalParams = globalParams ?? const ProcessorParams();

  /// 获取处理器显示名称
  String get displayName =>
      customName.isNotEmpty ? customName : type.displayName;

  /// 获取处理器描述
  String get description => type.description;

  /// 参数定义列表
  ///
  /// 子类应重写此方法返回该处理器支持的所有参数定义。
  List<ProcessorParamDef> get paramDefinitions;

  /// 获取支持单图覆盖的参数
  List<ProcessorParamDef> get perImageParams =>
      paramDefinitions.where((p) => p.supportsPerImageOverride).toList();

  /// 是否有支持单图覆盖的参数
  bool get hasPerImageParams => perImageParams.isNotEmpty;

  /// 处理图片
  ///
  /// [input] 输入图片数据
  /// [params] 合并后的参数（全局参数 + 单图覆盖参数）
  ///
  /// 返回处理后的输出数据。
  /// 此方法应设计为可在 Isolate 中运行（避免使用 UI 相关 API）。
  Future<ProcessorOutput> process(ProcessorInput input, ProcessorParams params);

  /// 使用全局参数处理图片（简化调用）
  Future<ProcessorOutput> processWithGlobalParams(ProcessorInput input) {
    return process(input, globalParams);
  }

  /// 使用单图覆盖参数处理图片
  ///
  /// [overrides] 单图覆盖参数，会与全局参数合并
  Future<ProcessorOutput> processWithOverrides(
    ProcessorInput input,
    ProcessorParams? overrides,
  ) {
    final mergedParams = overrides != null
        ? globalParams.copyWithAll(overrides.toMap())
        : globalParams;
    return process(input, mergedParams);
  }

  /// 获取参数的有效值（带默认值回退）
  T getParam<T>(ProcessorParams params, String paramId) {
    final def = paramDefinitions.firstWhere(
      (p) => p.id == paramId,
      orElse: () => throw ArgumentError('Unknown param: $paramId'),
    );
    return params.get<T>(paramId) ?? def.defaultValue as T;
  }

  /// 验证参数是否有效
  bool validateParams(ProcessorParams params) {
    for (final def in paramDefinitions) {
      if (params.has(def.id) && !def.isValid(params.get(def.id))) {
        return false;
      }
    }
    return true;
  }

  /// 设置全局参数
  void setGlobalParam(String paramId, dynamic value) {
    globalParams = globalParams.copyWith(paramId, value);
  }

  /// 批量设置全局参数
  void setGlobalParams(Map<String, dynamic> params) {
    globalParams = globalParams.copyWithAll(params);
  }

  /// 重置为默认参数
  void resetParams() {
    final defaults = <String, dynamic>{};
    for (final def in paramDefinitions) {
      defaults[def.id] = def.defaultValue;
    }
    globalParams = ProcessorParams(defaults);
  }

  /// 复制处理器配置
  Map<String, dynamic> toConfig() {
    return {
      'type': type.id,
      'instanceId': instanceId,
      'customName': customName,
      'enabled': enabled,
      'params': globalParams.toMap(),
    };
  }

  @override
  String toString() =>
      'ImageProcessor($displayName, type: ${type.id}, enabled: $enabled)';
}

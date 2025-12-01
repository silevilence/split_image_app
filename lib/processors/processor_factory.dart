import 'image_processor.dart';
import 'processor_param.dart';
import 'background_removal_processor.dart';
import 'smart_crop_processor.dart';
import 'color_replace_processor.dart';
import 'resize_processor.dart';

/// 处理器工厂
///
/// 负责创建处理器实例和从配置恢复处理器。
class ProcessorFactory {
  /// 实例计数器（用于生成唯一 ID）
  static int _instanceCounter = 0;

  /// 生成唯一的实例 ID
  static String generateInstanceId(ProcessorType type) {
    _instanceCounter++;
    return '${type.id}_$_instanceCounter';
  }

  /// 重置计数器（仅用于测试）
  static void resetCounter() {
    _instanceCounter = 0;
  }

  /// 创建处理器实例
  ///
  /// [type] 处理器类型
  /// [customName] 自定义名称（可选）
  /// [params] 初始参数（可选）
  static ImageProcessor create(
    ProcessorType type, {
    String? customName,
    ProcessorParams? params,
  }) {
    final instanceId = generateInstanceId(type);
    return _createWithId(type, instanceId, customName, params);
  }

  /// 从配置恢复处理器
  ///
  /// [config] 配置 Map
  static ImageProcessor? fromConfig(Map<String, dynamic> config) {
    final typeId = config['typeId'] as String?;
    if (typeId == null) return null;

    final type = ProcessorType.fromId(typeId);
    if (type == null) return null;

    final instanceId =
        config['instanceId'] as String? ?? generateInstanceId(type);
    final customName = config['customName'] as String?;
    final enabled = config['enabled'] as bool? ?? true;
    final paramsMap = config['params'] as Map<String, dynamic>? ?? {};
    final params = ProcessorParams.fromMap(paramsMap);

    final processor = _createWithId(type, instanceId, customName, params);
    processor.enabled = enabled;
    return processor;
  }

  /// 使用指定 ID 创建处理器（用于从配置恢复）
  static ImageProcessor _createWithId(
    ProcessorType type,
    String instanceId,
    String? customName,
    ProcessorParams? params,
  ) {
    switch (type) {
      case ProcessorType.backgroundRemoval:
        return BackgroundRemovalProcessor(
          instanceId: instanceId,
          customName: customName,
          globalParams: params,
        );
      case ProcessorType.smartCrop:
        return SmartCropProcessor(
          instanceId: instanceId,
          customName: customName,
          globalParams: params,
        );
      case ProcessorType.colorReplace:
        return ColorReplaceProcessor(
          instanceId: instanceId,
          customName: customName,
          globalParams: params,
        );
      case ProcessorType.resize:
        return ResizeProcessor(
          instanceId: instanceId,
          customName: customName,
          globalParams: params,
        );
    }
  }

  /// 获取所有可用的处理器类型
  static List<ProcessorType> get availableTypes => ProcessorType.values;
}

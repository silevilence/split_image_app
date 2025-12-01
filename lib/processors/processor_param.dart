import 'package:flutter/foundation.dart';

/// 处理器参数值类型
enum ParamType {
  /// 整数
  integer,

  /// 浮点数
  double_,

  /// 布尔值
  boolean,

  /// 字符串
  string,

  /// 颜色 (ARGB int)
  color,

  /// 枚举选择
  enumChoice,
}

/// 处理器参数定义
///
/// 定义处理器可配置的参数，包括名称、类型、默认值、范围等。
@immutable
class ProcessorParamDef {
  /// 参数 ID（唯一标识）
  final String id;

  /// 显示名称
  final String displayName;

  /// 参数描述
  final String description;

  /// 参数类型
  final ParamType type;

  /// 默认值
  final dynamic defaultValue;

  /// 最小值（适用于数值类型）
  final num? minValue;

  /// 最大值（适用于数值类型）
  final num? maxValue;

  /// 枚举选项（适用于 enumChoice 类型）
  final List<String>? enumOptions;

  /// 是否支持单图覆盖
  final bool supportsPerImageOverride;

  const ProcessorParamDef({
    required this.id,
    required this.displayName,
    this.description = '',
    required this.type,
    required this.defaultValue,
    this.minValue,
    this.maxValue,
    this.enumOptions,
    this.supportsPerImageOverride = false,
  });

  /// 验证值是否有效
  bool isValid(dynamic value) {
    if (value == null) return false;

    switch (type) {
      case ParamType.integer:
        if (value is! int) return false;
        if (minValue != null && value < minValue!) return false;
        if (maxValue != null && value > maxValue!) return false;
        return true;

      case ParamType.double_:
        if (value is! double && value is! int) return false;
        final doubleValue = (value as num).toDouble();
        if (minValue != null && doubleValue < minValue!) return false;
        if (maxValue != null && doubleValue > maxValue!) return false;
        return true;

      case ParamType.boolean:
        return value is bool;

      case ParamType.string:
        return value is String;

      case ParamType.color:
        return value is int;

      case ParamType.enumChoice:
        return value is String && (enumOptions?.contains(value) ?? false);
    }
  }

  /// 将值规范化到有效范围
  dynamic clampValue(dynamic value) {
    if (!isValid(value)) return defaultValue;

    switch (type) {
      case ParamType.integer:
        var intValue = value as int;
        if (minValue != null) {
          intValue = intValue.clamp(minValue!.toInt(), intValue);
        }
        if (maxValue != null) {
          intValue = intValue.clamp(intValue, maxValue!.toInt());
        }
        return intValue;

      case ParamType.double_:
        var doubleValue = (value as num).toDouble();
        if (minValue != null) {
          doubleValue = doubleValue.clamp(minValue!.toDouble(), doubleValue);
        }
        if (maxValue != null) {
          doubleValue = doubleValue.clamp(doubleValue, maxValue!.toDouble());
        }
        return doubleValue;

      default:
        return value;
    }
  }

  @override
  String toString() => 'ProcessorParamDef($id: $type, default: $defaultValue)';
}

/// 处理器参数值集合
///
/// 存储处理器的实际参数值。
@immutable
class ProcessorParams {
  /// 参数值映射 (paramId -> value)
  final Map<String, dynamic> _values;

  const ProcessorParams([Map<String, dynamic>? values])
    : _values = values ?? const {};

  /// 获取参数值
  T? get<T>(String paramId) {
    final value = _values[paramId];
    if (value is T) return value;
    return null;
  }

  /// 获取参数值，如果不存在则返回默认值
  T getOr<T>(String paramId, T defaultValue) {
    return get<T>(paramId) ?? defaultValue;
  }

  /// 检查参数是否存在
  bool has(String paramId) => _values.containsKey(paramId);

  /// 创建新实例并设置参数值
  ProcessorParams copyWith(String paramId, dynamic value) {
    return ProcessorParams({..._values, paramId: value});
  }

  /// 批量设置参数值
  ProcessorParams copyWithAll(Map<String, dynamic> updates) {
    return ProcessorParams({..._values, ...updates});
  }

  /// 移除参数
  ProcessorParams remove(String paramId) {
    final newValues = Map<String, dynamic>.from(_values);
    newValues.remove(paramId);
    return ProcessorParams(newValues);
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() => Map.unmodifiable(_values);

  /// 从 Map 创建
  factory ProcessorParams.fromMap(Map<String, dynamic> map) {
    return ProcessorParams(Map<String, dynamic>.from(map));
  }

  /// 是否为空
  bool get isEmpty => _values.isEmpty;

  /// 是否不为空
  bool get isNotEmpty => _values.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProcessorParams && mapEquals(_values, other._values);
  }

  @override
  int get hashCode => Object.hashAll(_values.entries);

  @override
  String toString() => 'ProcessorParams($_values)';
}

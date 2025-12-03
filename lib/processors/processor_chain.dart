import 'dart:async';

import 'package:flutter/foundation.dart';

import 'image_processor.dart';
import 'processor_io.dart';
import 'processor_param.dart';

/// 处理步骤配置
///
/// 用于序列化/反序列化处理器链。
@immutable
class ProcessorStepConfig {
  /// 处理器类型 ID
  final String typeId;

  /// 实例 ID
  final String instanceId;

  /// 自定义名称
  final String customName;

  /// 是否启用
  final bool enabled;

  /// 全局参数
  final Map<String, dynamic> params;

  const ProcessorStepConfig({
    required this.typeId,
    required this.instanceId,
    this.customName = '',
    this.enabled = true,
    this.params = const {},
  });

  factory ProcessorStepConfig.fromProcessor(ImageProcessor processor) {
    return ProcessorStepConfig(
      typeId: processor.type.id,
      instanceId: processor.instanceId,
      customName: processor.customName,
      enabled: processor.enabled,
      params: processor.globalParams.toMap(),
    );
  }

  Map<String, dynamic> toMap() => {
    'typeId': typeId,
    'instanceId': instanceId,
    'customName': customName,
    'enabled': enabled,
    'params': params,
  };

  factory ProcessorStepConfig.fromMap(Map<String, dynamic> map) {
    return ProcessorStepConfig(
      typeId: map['typeId'] as String? ?? '',
      instanceId: map['instanceId'] as String? ?? '',
      customName: map['customName'] as String? ?? '',
      enabled: map['enabled'] as bool? ?? true,
      params: Map<String, dynamic>.from(map['params'] as Map? ?? {}),
    );
  }
}

/// 单图参数覆盖
///
/// 存储特定图片对特定处理步骤的参数覆盖。
@immutable
class SliceOverrides {
  /// 切片索引
  final int sliceIndex;

  /// 参数覆盖映射 (processorInstanceId -> params)
  final Map<String, ProcessorParams> _overrides;

  const SliceOverrides({
    required this.sliceIndex,
    Map<String, ProcessorParams>? overrides,
  }) : _overrides = overrides ?? const {};

  /// 获取指定处理器的覆盖参数
  ProcessorParams? getOverrides(String instanceId) => _overrides[instanceId];

  /// 设置覆盖参数
  SliceOverrides setOverrides(String instanceId, ProcessorParams params) {
    return SliceOverrides(
      sliceIndex: sliceIndex,
      overrides: {..._overrides, instanceId: params},
    );
  }

  /// 移除覆盖参数
  SliceOverrides removeOverrides(String instanceId) {
    final newOverrides = Map<String, ProcessorParams>.from(_overrides);
    newOverrides.remove(instanceId);
    return SliceOverrides(sliceIndex: sliceIndex, overrides: newOverrides);
  }

  /// 清空所有覆盖
  SliceOverrides clear() {
    return SliceOverrides(sliceIndex: sliceIndex);
  }

  /// 是否有覆盖
  bool get hasOverrides => _overrides.isNotEmpty;

  /// 检查是否有指定处理器的覆盖
  bool hasOverridesFor(String instanceId) => _overrides.containsKey(instanceId);

  Map<String, dynamic> toMap() => {
    'sliceIndex': sliceIndex,
    'overrides': _overrides.map((k, v) => MapEntry(k, v.toMap())),
  };

  factory SliceOverrides.fromMap(Map<String, dynamic> map) {
    final overridesMap = map['overrides'] as Map<String, dynamic>? ?? {};
    return SliceOverrides(
      sliceIndex: map['sliceIndex'] as int? ?? 0,
      overrides: overridesMap.map(
        (k, v) =>
            MapEntry(k, ProcessorParams.fromMap(v as Map<String, dynamic>)),
      ),
    );
  }
}

/// 处理进度回调
typedef ProcessorProgressCallback =
    void Function(int currentStep, int totalSteps, String? message);

/// 处理器链
///
/// 管理处理器的执行顺序，支持添加、删除、重排序操作。
/// 实现责任链模式，依次执行每个处理器。
class ProcessorChain {
  /// 处理器列表
  final List<ImageProcessor> _processors = [];

  /// 单图参数覆盖映射 (sliceIndex -> SliceOverrides)
  final Map<int, SliceOverrides> _sliceOverrides = {};

  /// 获取处理器列表（只读）
  List<ImageProcessor> get processors => List.unmodifiable(_processors);

  /// 获取启用的处理器列表
  List<ImageProcessor> get enabledProcessors =>
      _processors.where((p) => p.enabled).toList();

  /// 处理器数量
  int get length => _processors.length;

  /// 是否为空
  bool get isEmpty => _processors.isEmpty;

  /// 是否不为空
  bool get isNotEmpty => _processors.isNotEmpty;

  /// 启用的处理器数量
  int get enabledCount => _processors.where((p) => p.enabled).length;

  /// 生成自动名称（如 "Crop-1", "Crop-2"）
  String _generateAutoName(ProcessorType type) {
    final existingCount = _processors.where((p) => p.type == type).length;
    if (existingCount == 0) {
      return type.displayName;
    }
    return '${type.displayName}-${existingCount + 1}';
  }

  /// 生成唯一的显示名称
  ///
  /// 如果名称已存在，自动添加数字后缀（如 "Name" -> "Name-2"）
  String _ensureUniqueName(String baseName) {
    // 检查是否已有同名的处理器
    final existingNames = _processors.map((p) => p.customName).toSet();

    if (!existingNames.contains(baseName)) {
      return baseName;
    }

    // 找到不重复的名称
    int suffix = 2;
    String newName;
    do {
      newName = '$baseName-$suffix';
      suffix++;
    } while (existingNames.contains(newName));

    return newName;
  }

  /// 添加处理器到末尾
  void add(ImageProcessor processor) {
    // 如果没有自定义名称，生成自动名称
    if (processor.customName.isEmpty) {
      processor.customName = _generateAutoName(processor.type);
    } else {
      // 有自定义名称时，确保名称唯一
      processor.customName = _ensureUniqueName(processor.customName);
    }
    _processors.add(processor);
  }

  /// 在指定位置插入处理器
  void insert(int index, ImageProcessor processor) {
    if (processor.customName.isEmpty) {
      processor.customName = _generateAutoName(processor.type);
    } else {
      processor.customName = _ensureUniqueName(processor.customName);
    }
    _processors.insert(index.clamp(0, _processors.length), processor);
  }

  /// 移除处理器
  bool remove(ImageProcessor processor) {
    // 同时移除相关的覆盖参数
    for (final override in _sliceOverrides.values) {
      if (override.hasOverridesFor(processor.instanceId)) {
        _sliceOverrides[override.sliceIndex] = override.removeOverrides(
          processor.instanceId,
        );
      }
    }
    return _processors.remove(processor);
  }

  /// 根据索引移除处理器
  ImageProcessor? removeAt(int index) {
    if (index < 0 || index >= _processors.length) return null;
    final processor = _processors.removeAt(index);
    // 同时移除相关的覆盖参数
    for (final override in _sliceOverrides.values) {
      if (override.hasOverridesFor(processor.instanceId)) {
        _sliceOverrides[override.sliceIndex] = override.removeOverrides(
          processor.instanceId,
        );
      }
    }
    return processor;
  }

  /// 重新排序处理器
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _processors.length) return;
    if (newIndex < 0 || newIndex > _processors.length) return;

    final processor = _processors.removeAt(oldIndex);
    if (newIndex > oldIndex) {
      newIndex--;
    }
    _processors.insert(newIndex, processor);
  }

  /// 获取处理器
  ImageProcessor? operator [](int index) {
    if (index < 0 || index >= _processors.length) return null;
    return _processors[index];
  }

  /// 根据实例 ID 查找处理器
  ImageProcessor? findById(String instanceId) {
    for (final processor in _processors) {
      if (processor.instanceId == instanceId) return processor;
    }
    return null;
  }

  /// 设置单图覆盖参数
  void setSliceOverride(
    int sliceIndex,
    String instanceId,
    ProcessorParams params,
  ) {
    final existing = _sliceOverrides[sliceIndex];
    if (existing != null) {
      _sliceOverrides[sliceIndex] = existing.setOverrides(instanceId, params);
    } else {
      _sliceOverrides[sliceIndex] = SliceOverrides(
        sliceIndex: sliceIndex,
        overrides: {instanceId: params},
      );
    }
  }

  /// 移除单图覆盖参数
  void removeSliceOverride(int sliceIndex, String instanceId) {
    final existing = _sliceOverrides[sliceIndex];
    if (existing != null) {
      final updated = existing.removeOverrides(instanceId);
      if (updated.hasOverrides) {
        _sliceOverrides[sliceIndex] = updated;
      } else {
        _sliceOverrides.remove(sliceIndex);
      }
    }
  }

  /// 获取单图覆盖参数
  SliceOverrides? getSliceOverrides(int sliceIndex) =>
      _sliceOverrides[sliceIndex];

  /// 清除所有单图覆盖
  void clearAllOverrides() {
    _sliceOverrides.clear();
  }

  /// 处理单张图片
  ///
  /// [input] 输入图片数据
  /// [sliceIndex] 切片索引（用于应用单图覆盖参数）
  /// [onProgress] 进度回调
  Future<ProcessorOutput> process(
    ProcessorInput input, {
    int? sliceIndex,
    ProcessorProgressCallback? onProgress,
  }) async {
    final enabled = enabledProcessors;
    if (enabled.isEmpty) {
      return ProcessorOutput.unchanged(input);
    }

    ProcessorInput currentInput = input;
    ProcessorOutput? lastOutput;
    final sliceOverride = sliceIndex != null
        ? _sliceOverrides[sliceIndex]
        : null;

    for (int i = 0; i < enabled.length; i++) {
      final processor = enabled[i];

      onProgress?.call(i + 1, enabled.length, processor.displayName);

      // 获取单图覆盖参数（如果有）
      final overrides = sliceOverride?.getOverrides(processor.instanceId);

      // 执行处理
      final output = await processor.processWithOverrides(
        currentInput,
        overrides,
      );
      lastOutput = output;

      // 准备下一步的输入
      if (i < enabled.length - 1) {
        currentInput = output.toInput(
          sliceIndex: input.sliceIndex,
          row: input.row,
          col: input.col,
        );
      }
    }

    return lastOutput ?? ProcessorOutput.unchanged(input);
  }

  /// 批量处理多张图片
  ///
  /// [inputs] 输入图片列表
  /// [onProgress] 进度回调 (currentImage, totalImages, currentStep, totalSteps)
  Future<List<ProcessorOutput>> processAll(
    List<ProcessorInput> inputs, {
    void Function(
      int currentImage,
      int totalImages,
      int currentStep,
      int totalSteps,
    )?
    onProgress,
  }) async {
    final results = <ProcessorOutput>[];

    for (int i = 0; i < inputs.length; i++) {
      final input = inputs[i];
      final output = await process(
        input,
        sliceIndex: input.sliceIndex,
        onProgress: (step, total, _) {
          onProgress?.call(i + 1, inputs.length, step, total);
        },
      );
      results.add(output);
    }

    return results;
  }

  /// 清空处理器链
  void clear() {
    _processors.clear();
    _sliceOverrides.clear();
  }

  /// 转换为配置列表（用于持久化）
  List<Map<String, dynamic>> toConfig() {
    return _processors
        .map((p) => ProcessorStepConfig.fromProcessor(p).toMap())
        .toList();
  }

  /// 获取单图覆盖配置
  Map<String, dynamic> getOverridesConfig() {
    return _sliceOverrides.map((k, v) => MapEntry(k.toString(), v.toMap()));
  }

  @override
  String toString() =>
      'ProcessorChain($_processors.length processors, $enabledCount enabled)';
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

import '../processors/processors.dart';

/// Pipeline 状态管理
///
/// 管理图片后处理流水线的状态，包括处理器链配置、
/// 执行状态、进度等。
class PipelineProvider extends ChangeNotifier {
  /// 处理器链
  final ProcessorChain _chain = ProcessorChain();

  /// 是否正在处理
  bool _isProcessing = false;

  /// 当前处理进度 (0.0 - 1.0)
  double _progress = 0.0;

  /// 当前正在处理的图片索引
  int _currentImageIndex = 0;

  /// 总图片数
  int _totalImages = 0;

  /// 当前处理步骤
  int _currentStep = 0;

  /// 总步骤数
  int _totalSteps = 0;

  /// 当前处理器名称
  String? _currentProcessorName;

  /// 错误信息
  String? _errorMessage;

  /// 是否有未应用的更改
  bool _hasUnappliedChanges = false;

  // ==================== Getters ====================

  /// 获取处理器链
  ProcessorChain get chain => _chain;

  /// 获取处理器列表
  List<ImageProcessor> get processors => _chain.processors;

  /// 获取启用的处理器数量
  int get enabledCount => _chain.enabledCount;

  /// 是否有处理器
  bool get hasProcessors => _chain.isNotEmpty;

  /// 是否正在处理
  bool get isProcessing => _isProcessing;

  /// 当前进度
  double get progress => _progress;

  /// 当前图片索引
  int get currentImageIndex => _currentImageIndex;

  /// 总图片数
  int get totalImages => _totalImages;

  /// 当前步骤
  int get currentStep => _currentStep;

  /// 总步骤数
  int get totalSteps => _totalSteps;

  /// 当前处理器名称
  String? get currentProcessorName => _currentProcessorName;

  /// 错误信息
  String? get errorMessage => _errorMessage;

  /// 是否有未应用的更改
  bool get hasUnappliedChanges => _hasUnappliedChanges;

  /// 获取概要描述（如 "3 Steps Active"）
  String get summary {
    if (_chain.isEmpty) return '无处理步骤';
    final enabled = _chain.enabledCount;
    final total = _chain.length;
    if (enabled == total) {
      return '$total 个处理步骤';
    }
    return '$enabled/$total 个处理步骤已启用';
  }

  // ==================== 处理器管理 ====================

  /// 添加处理器
  void addProcessor(
    ProcessorType type, {
    String? customName,
    ProcessorParams? params,
  }) {
    final processor = ProcessorFactory.create(
      type,
      customName: customName,
      params: params,
    );
    _chain.add(processor);
    _hasUnappliedChanges = true;
    notifyListeners();
  }

  /// 在指定位置插入处理器
  void insertProcessor(int index, ProcessorType type, {String? customName}) {
    final processor = ProcessorFactory.create(type, customName: customName);
    _chain.insert(index, processor);
    _hasUnappliedChanges = true;
    notifyListeners();
  }

  /// 移除处理器
  void removeProcessor(ImageProcessor processor) {
    if (_chain.remove(processor)) {
      _hasUnappliedChanges = true;
      notifyListeners();
    }
  }

  /// 根据索引移除处理器
  void removeProcessorAt(int index) {
    if (_chain.removeAt(index) != null) {
      _hasUnappliedChanges = true;
      notifyListeners();
    }
  }

  /// 重新排序处理器
  void reorderProcessor(int oldIndex, int newIndex) {
    _chain.reorder(oldIndex, newIndex);
    _hasUnappliedChanges = true;
    notifyListeners();
  }

  /// 切换处理器启用状态
  void toggleProcessor(int index) {
    final processor = _chain[index];
    if (processor != null) {
      processor.enabled = !processor.enabled;
      _hasUnappliedChanges = true;
      notifyListeners();
    }
  }

  /// 设置处理器启用状态
  void setProcessorEnabled(int index, bool enabled) {
    final processor = _chain[index];
    if (processor != null && processor.enabled != enabled) {
      processor.enabled = enabled;
      _hasUnappliedChanges = true;
      notifyListeners();
    }
  }

  /// 更新处理器自定义名称
  void updateProcessorName(int index, String name) {
    final processor = _chain[index];
    if (processor != null) {
      processor.customName = name;
      notifyListeners();
    }
  }

  /// 更新处理器全局参数
  void updateProcessorParam(int index, String paramId, dynamic value) {
    final processor = _chain[index];
    if (processor != null) {
      processor.setGlobalParam(paramId, value);
      _hasUnappliedChanges = true;
      notifyListeners();
    }
  }

  /// 批量更新处理器参数
  void updateProcessorParams(int index, Map<String, dynamic> params) {
    final processor = _chain[index];
    if (processor != null) {
      processor.setGlobalParams(params);
      _hasUnappliedChanges = true;
      notifyListeners();
    }
  }

  /// 重置处理器参数为默认值
  void resetProcessorParams(int index) {
    final processor = _chain[index];
    if (processor != null) {
      processor.resetParams();
      _hasUnappliedChanges = true;
      notifyListeners();
    }
  }

  // ==================== 单图覆盖 ====================

  /// 设置单图覆盖参数
  void setSliceOverride(
    int sliceIndex,
    String processorInstanceId,
    ProcessorParams params,
  ) {
    _chain.setSliceOverride(sliceIndex, processorInstanceId, params);
    _hasUnappliedChanges = true;
    notifyListeners();
  }

  /// 移除单图覆盖参数
  void removeSliceOverride(int sliceIndex, String processorInstanceId) {
    _chain.removeSliceOverride(sliceIndex, processorInstanceId);
    _hasUnappliedChanges = true;
    notifyListeners();
  }

  /// 获取单图覆盖参数
  SliceOverrides? getSliceOverrides(int sliceIndex) {
    return _chain.getSliceOverrides(sliceIndex);
  }

  /// 清除所有单图覆盖
  void clearAllOverrides() {
    _chain.clearAllOverrides();
    _hasUnappliedChanges = true;
    notifyListeners();
  }

  // ==================== 执行处理 ====================

  /// 处理单张图片
  Future<ProcessorOutput> processImage(
    ProcessorInput input, {
    int? sliceIndex,
  }) async {
    if (_chain.isEmpty) {
      return ProcessorOutput.unchanged(input);
    }

    _isProcessing = true;
    _progress = 0;
    _errorMessage = null;
    notifyListeners();

    try {
      final output = await _chain.process(
        input,
        sliceIndex: sliceIndex,
        onProgress: (step, total, name) {
          _currentStep = step;
          _totalSteps = total;
          _currentProcessorName = name;
          _progress = step / total;
          notifyListeners();
        },
      );

      _isProcessing = false;
      _progress = 1.0;
      notifyListeners();

      return output;
    } catch (e) {
      _isProcessing = false;
      _errorMessage = '处理失败: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// 批量处理图片
  Future<List<ProcessorOutput>> processImages(
    List<ProcessorInput> inputs,
  ) async {
    if (_chain.isEmpty) {
      return inputs.map((i) => ProcessorOutput.unchanged(i)).toList();
    }

    _isProcessing = true;
    _progress = 0;
    _currentImageIndex = 0;
    _totalImages = inputs.length;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await _chain.processAll(
        inputs,
        onProgress: (currentImage, totalImages, step, total) {
          _currentImageIndex = currentImage;
          _totalImages = totalImages;
          _currentStep = step;
          _totalSteps = total;
          _progress = (currentImage - 1 + step / total) / totalImages;
          notifyListeners();
        },
      );

      _isProcessing = false;
      _progress = 1.0;
      _hasUnappliedChanges = false;
      notifyListeners();

      return results;
    } catch (e) {
      _isProcessing = false;
      _errorMessage = '批量处理失败: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// 标记更改已应用
  void markChangesApplied() {
    _hasUnappliedChanges = false;
    notifyListeners();
  }

  // ==================== 配置持久化 ====================

  /// 导出配置
  Map<String, dynamic> toConfig() {
    return {
      'processors': _chain.toConfig(),
      'overrides': _chain.getOverridesConfig(),
    };
  }

  /// 从配置恢复
  void loadFromConfig(Map<String, dynamic> config) {
    _chain.clear();

    final processorConfigs = config['processors'] as List<dynamic>? ?? [];
    for (final procConfig in processorConfigs) {
      if (procConfig is Map<String, dynamic>) {
        final processor = ProcessorFactory.fromConfig(procConfig);
        if (processor != null) {
          _chain.add(processor);
        }
      }
    }

    // 恢复单图覆盖配置
    final overridesConfig = config['overrides'] as Map<String, dynamic>? ?? {};
    for (final entry in overridesConfig.entries) {
      final sliceIndex = int.tryParse(entry.key);
      if (sliceIndex != null && entry.value is Map<String, dynamic>) {
        final overridesMap =
            (entry.value as Map<String, dynamic>)['overrides']
                as Map<String, dynamic>?;
        if (overridesMap != null) {
          for (final override in overridesMap.entries) {
            if (override.value is Map<String, dynamic>) {
              _chain.setSliceOverride(
                sliceIndex,
                override.key,
                ProcessorParams.fromMap(override.value as Map<String, dynamic>),
              );
            }
          }
        }
      }
    }

    _hasUnappliedChanges = false;
    notifyListeners();
  }

  /// 清空处理器链
  void clear() {
    _chain.clear();
    _hasUnappliedChanges = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// 清除错误
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==================== 导入/导出功能 ====================

  /// 导出 Pipeline 配置到 JSON 文件
  ///
  /// 仅导出处理器配置，不包含单图覆盖参数。
  /// 返回 true 表示导出成功，false 表示取消或失败。
  Future<bool> exportPipelineToJson() async {
    if (_chain.isEmpty) {
      _errorMessage = '流水线为空，无法导出';
      notifyListeners();
      return false;
    }

    try {
      // 选择保存路径
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出流水线配置',
        fileName: 'pipeline_config.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) {
        // 用户取消
        return false;
      }

      // 构建配置数据（仅处理器，不含单图覆盖）
      final config = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'processors': _chain.toConfig(),
      };

      // 写入文件
      final file = File(result);
      final jsonStr = const JsonEncoder.withIndent('  ').convert(config);
      await file.writeAsString(jsonStr, flush: true);

      return true;
    } catch (e) {
      _errorMessage = '导出失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 从 JSON 文件导入 Pipeline 配置
  ///
  /// [append] 为 true 时追加到现有配置，为 false 时替换现有配置。
  /// 返回导入的处理器数量，-1 表示取消或失败。
  Future<int> importPipelineFromJson({required bool append}) async {
    debugPrint('[Pipeline] importPipelineFromJson called, append=$append');
    debugPrint('[Pipeline] Current processors count: ${_chain.length}');

    try {
      // 选择文件
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '导入流水线配置',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // 用户取消
        return -1;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        _errorMessage = '无法获取文件路径';
        notifyListeners();
        return -1;
      }

      // 读取文件
      final file = File(filePath);
      final jsonStr = await file.readAsString();
      final config = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 验证配置格式
      final processors = config['processors'];
      if (processors == null || processors is! List) {
        _errorMessage = '无效的配置文件格式';
        notifyListeners();
        return -1;
      }

      debugPrint('[Pipeline] Config contains ${processors.length} processors');

      // 如果不是追加模式，先清空
      if (!append) {
        debugPrint('[Pipeline] Replace mode: clearing existing processors');
        _chain.clear();
      } else {
        debugPrint(
          '[Pipeline] Append mode: keeping existing ${_chain.length} processors',
        );
      }

      // 导入处理器
      int importedCount = 0;
      for (final processorConfig in processors) {
        if (processorConfig is Map<String, dynamic>) {
          // 始终生成新的 instanceId 避免 GlobalKey 冲突
          // 即使是覆盖模式，也需要新 ID，因为旧 widget 可能还未完全销毁
          final modifiedConfig = Map<String, dynamic>.from(processorConfig);
          modifiedConfig.remove('instanceId');
          final processor = ProcessorFactory.fromConfig(modifiedConfig);
          if (processor != null) {
            _chain.add(processor);
            importedCount++;
            debugPrint(
              '[Pipeline] Added processor: ${processor.displayName} (id: ${processor.instanceId})',
            );
          }
        }
      }

      debugPrint(
        '[Pipeline] Import complete. Total processors now: ${_chain.length}',
      );

      if (importedCount > 0) {
        _hasUnappliedChanges = true;
      }

      notifyListeners();
      return importedCount;
    } catch (e) {
      _errorMessage = '导入失败: $e';
      notifyListeners();
      return -1;
    }
  }
}

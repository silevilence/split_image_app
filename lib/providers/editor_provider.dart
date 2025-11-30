import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/editor_history.dart';
import '../models/grid_algorithm_type.dart';
import '../models/grid_config.dart';
import '../models/grid_generator_input.dart';
import '../models/margins.dart';
import '../services/config_service.dart';
import '../strategies/grid_strategy_factory.dart';

/// 图片编辑器状态管理
class EditorProvider extends ChangeNotifier {
  /// 构造函数 - 从配置加载默认值
  EditorProvider() {
    final configService = ConfigService.instance;
    _algorithmType = configService.defaultAlgorithm;
    // 从配置加载默认行列数
    _gridConfig = GridConfig(
      rows: configService.config.grid.defaultRows,
      cols: configService.config.grid.defaultCols,
    );
  }

  // ============ 图片相关 ============

  /// 源图片文件
  File? _imageFile;
  File? get imageFile => _imageFile;

  /// 图片尺寸
  Size? _imageSize;
  Size? get imageSize => _imageSize;

  /// 图片像素数据（RGBA 格式，供智能算法使用）
  Uint8List? _pixelData;

  /// 图片宽高比
  double? get imageAspectRatio =>
      _imageSize != null ? _imageSize!.width / _imageSize!.height : null;

  /// 是否正在加载
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// 加载错误信息
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ============ 网格配置 ============

  /// 网格配置
  GridConfig _gridConfig = GridConfig.defaultConfig();
  GridConfig get gridConfig => _gridConfig;

  /// 当前使用的网格生成算法（构造函数中从配置加载）
  GridAlgorithmType _algorithmType = GridAlgorithmType.fixedEvenSplit;
  GridAlgorithmType get algorithmType => _algorithmType;

  /// 水平网格线（相对位置 0.0-1.0）
  List<double> _horizontalLines = [];
  List<double> get horizontalLines => _horizontalLines;

  /// 垂直网格线（相对位置 0.0-1.0）
  List<double> _verticalLines = [];
  List<double> get verticalLines => _verticalLines;

  /// 是否已自动交换行列
  bool _wasSwapped = false;
  bool get wasSwapped => _wasSwapped;

  // ============ 边距设置 ============

  /// 图片边缘留白
  ImageMargins _margins = ImageMargins.zero;
  ImageMargins get margins => _margins;

  /// 有效区域（排除边距后的区域）
  Rect? get effectiveRect {
    if (_imageSize == null) return null;
    return _margins.getEffectiveRect(_imageSize!);
  }

  /// 有效区域尺寸
  Size? get effectiveSize {
    final rect = effectiveRect;
    if (rect == null) return null;
    return Size(rect.width, rect.height);
  }

  /// 编辑模式（true: 可拖拽网格线，false: 可平移缩放画布）
  bool _isEditMode = false;
  bool get isEditMode => _isEditMode;

  /// 选中的线索引和类型
  int? _selectedLineIndex;
  bool? _selectedLineIsHorizontal; // true: 水平线, false: 垂直线, null: 无选中

  int? get selectedLineIndex => _selectedLineIndex;
  bool? get selectedLineIsHorizontal => _selectedLineIsHorizontal;

  bool get hasSelectedLine => _selectedLineIndex != null;

  // ============ 撤销/重做系统 ============

  /// 历史记录管理器
  final EditorHistory _history = EditorHistory();

  /// 是否可以撤销
  bool get canUndo => _history.canUndo;

  /// 是否可以重做
  bool get canRedo => _history.canRedo;

  /// 获取当前编辑器状态快照
  EditorSnapshot _getCurrentSnapshot() {
    return EditorSnapshot.from(
      horizontalLines: _horizontalLines,
      verticalLines: _verticalLines,
      margins: _margins,
    );
  }

  /// 保存当前状态到历史记录（在修改前调用）
  void _saveToHistory() {
    _history.saveState(_getCurrentSnapshot());
  }

  /// 从快照恢复状态
  void _restoreFromSnapshot(EditorSnapshot snapshot) {
    _horizontalLines = List<double>.from(snapshot.horizontalLines);
    _verticalLines = List<double>.from(snapshot.verticalLines);
    _margins = snapshot.margins;
    clearSelection();
  }

  /// 撤销操作
  void undo() {
    final previousState = _history.undo(_getCurrentSnapshot());
    if (previousState != null) {
      _restoreFromSnapshot(previousState);
      notifyListeners();
    }
  }

  /// 重做操作
  void redo() {
    final nextState = _history.redo(_getCurrentSnapshot());
    if (nextState != null) {
      _restoreFromSnapshot(nextState);
      notifyListeners();
    }
  }

  /// 开始编辑操作（拖拽/微调前调用，保存当前状态）
  /// 返回 true 表示成功开始编辑
  bool _isEditing = false;

  void beginEdit() {
    if (!_isEditing) {
      _saveToHistory();
      _isEditing = true;
    }
  }

  /// 结束编辑操作
  void endEdit() {
    _isEditing = false;
  }

  // ============ 方法 ============

  /// 切换编辑模式
  void toggleEditMode() {
    _isEditMode = !_isEditMode;
    notifyListeners();
  }

  /// 设置编辑模式
  void setEditMode(bool enabled) {
    _isEditMode = enabled;
    notifyListeners();
  }

  /// 选中网格线
  void selectLine(int index, bool isHorizontal) {
    _selectedLineIndex = index;
    _selectedLineIsHorizontal = isHorizontal;
    notifyListeners();
  }

  /// 取消选中
  void clearSelection() {
    _selectedLineIndex = null;
    _selectedLineIsHorizontal = null;
    notifyListeners();
  }

  /// 添加水平线
  void addHorizontalLine(double position) {
    _saveToHistory();
    _horizontalLines.add(position.clamp(0.0, 1.0));
    _horizontalLines.sort();
    notifyListeners();
  }

  /// 添加垂直线
  void addVerticalLine(double position) {
    _saveToHistory();
    _verticalLines.add(position.clamp(0.0, 1.0));
    _verticalLines.sort();
    notifyListeners();
  }

  /// 删除选中的线
  void deleteSelectedLine() {
    if (_selectedLineIndex == null || _selectedLineIsHorizontal == null) return;

    _saveToHistory();

    if (_selectedLineIsHorizontal!) {
      if (_selectedLineIndex! < _horizontalLines.length) {
        _horizontalLines.removeAt(_selectedLineIndex!);
      }
    } else {
      if (_selectedLineIndex! < _verticalLines.length) {
        _verticalLines.removeAt(_selectedLineIndex!);
      }
    }

    clearSelection();
  }

  /// 微调选中的线（像素级移动）
  /// [delta] 移动量（相对位置）
  /// [saveHistory] 是否保存历史记录（第一次按键时保存）
  void nudgeSelectedLine(double delta, {bool saveHistory = true}) {
    if (_selectedLineIndex == null || _selectedLineIsHorizontal == null) return;

    if (saveHistory) {
      _saveToHistory();
    }

    if (_selectedLineIsHorizontal!) {
      if (_selectedLineIndex! < _horizontalLines.length) {
        final newPos = (_horizontalLines[_selectedLineIndex!] + delta).clamp(
          0.0,
          1.0,
        );
        _horizontalLines[_selectedLineIndex!] = newPos;
        notifyListeners();
      }
    } else {
      if (_selectedLineIndex! < _verticalLines.length) {
        final newPos = (_verticalLines[_selectedLineIndex!] + delta).clamp(
          0.0,
          1.0,
        );
        _verticalLines[_selectedLineIndex!] = newPos;
        notifyListeners();
      }
    }
  }

  /// 根据当前算法生成网格线
  /// 网格线位置是相对于整个图片的比例 (0.0-1.0)
  ///
  /// [detectEdges] 是否检测边缘并自动设置 margin（仅首次应用算法时为 true）
  Future<void> _generateGridLines({bool detectEdges = false}) async {
    if (_imageSize == null) {
      _horizontalLines = [];
      _verticalLines = [];
      return;
    }

    final rect = effectiveRect!;

    // 使用策略工厂创建对应算法
    final strategy = GridStrategyFactory.tryCreate(_algorithmType);

    if (strategy == null) {
      // 算法未实现，回退到均匀分割
      _algorithmType = GridAlgorithmType.fixedEvenSplit;
      final fallbackStrategy = GridStrategyFactory.create(
        GridAlgorithmType.fixedEvenSplit,
      );
      final input = GridGeneratorInput(
        effectiveRect: rect,
        targetRows: _gridConfig.rows,
        targetCols: _gridConfig.cols,
        imageWidth: _imageSize!.width.toInt(),
        imageHeight: _imageSize!.height.toInt(),
      );
      final result = await fallbackStrategy.generate(input);
      _horizontalLines = result.horizontalLines;
      _verticalLines = result.verticalLines;
      return;
    }

    // 如果算法需要像素数据但当前没有，尝试加载
    Uint8List? pixelData = _pixelData;
    debugPrint('[EditorProvider] Algorithm: ${_algorithmType.name}');
    debugPrint(
      '[EditorProvider] requiresPixelData: ${strategy.requiresPixelData}',
    );
    debugPrint('[EditorProvider] existing pixelData: ${pixelData != null}');
    if (strategy.requiresPixelData && pixelData == null && _imageFile != null) {
      debugPrint('[EditorProvider] Loading pixel data...');
      pixelData = await _loadPixelData();
      debugPrint(
        '[EditorProvider] Pixel data loaded: ${pixelData != null}, length: ${pixelData?.length}',
      );
    }

    // 创建输入参数
    // 只有 detectEdges=true 且 margin 为零时，才让算法检测边缘
    final shouldDetectEdges = detectEdges && _margins.isZero;
    final input = GridGeneratorInput(
      effectiveRect: rect,
      targetRows: _gridConfig.rows,
      targetCols: _gridConfig.cols,
      imageWidth: _imageSize!.width.toInt(),
      imageHeight: _imageSize!.height.toInt(),
      pixelData: pixelData,
      hasUserMargins: !shouldDetectEdges,
    );

    // 生成网格线
    final result = await strategy.generate(input);

    if (result.success) {
      // 如果允许检测边缘，且算法建议了边距，则自动应用
      if (shouldDetectEdges &&
          result.suggestedMargins != null &&
          result.suggestedMargins!.hasMargins) {
        final suggested = result.suggestedMargins!;
        debugPrint('[EditorProvider] Applying suggested margins: $suggested');

        _margins = ImageMargins(
          top: suggested.top.toDouble(),
          bottom: suggested.bottom.toDouble(),
          left: suggested.left.toDouble(),
          right: suggested.right.toDouble(),
        );
      }

      _horizontalLines = result.horizontalLines;
      _verticalLines = result.verticalLines;
      if (result.message != null) {
        debugPrint('[EditorProvider] ${result.message}');
      }
    } else {
      // 生成失败，回退到均匀分割
      debugPrint('[EditorProvider] Grid generation failed: ${result.message}');
      debugPrint('[EditorProvider] Falling back to even split');

      final fallbackStrategy = GridStrategyFactory.create(
        GridAlgorithmType.fixedEvenSplit,
      );
      final fallbackInput = GridGeneratorInput(
        effectiveRect: rect,
        targetRows: _gridConfig.rows,
        targetCols: _gridConfig.cols,
        imageWidth: _imageSize!.width.toInt(),
        imageHeight: _imageSize!.height.toInt(),
      );
      final fallbackResult = await fallbackStrategy.generate(fallbackInput);
      _horizontalLines = fallbackResult.horizontalLines;
      _verticalLines = fallbackResult.verticalLines;
    }
  }

  /// 加载图片像素数据（RGBA 格式）
  Future<Uint8List?> _loadPixelData() async {
    if (_imageFile == null) return null;

    try {
      final bytes = await _imageFile!.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // 将图片转换为 RGBA 字节数组
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData != null) {
        _pixelData = byteData.buffer.asUint8List();
        return _pixelData;
      }
    } catch (e) {
      debugPrint('[EditorProvider] Failed to load pixel data: $e');
    }

    return null;
  }

  /// 设置网格生成算法
  Future<void> setAlgorithmType(GridAlgorithmType type) async {
    if (_algorithmType == type) return;
    _algorithmType = type;
    // 保存算法选择到配置
    await ConfigService.instance.setDefaultAlgorithm(type);
    // 切换算法时不自动检测边缘，需要手动触发
    await _generateGridLines();
    notifyListeners();
  }

  /// 重新生成网格（供外部调用，不检测边缘）
  Future<void> regenerateGrid() async {
    await _generateGridLines();
    notifyListeners();
  }

  /// 重新检测边缘并生成网格（手动触发）
  /// 会清空当前 margin，重新检测边缘
  Future<void> detectEdgesAndRegenerate() async {
    // 先清空 margin，这样算法会重新检测边缘
    _margins = ImageMargins.zero;
    await _generateGridLines(detectEdges: true);
    notifyListeners();
  }

  /// 加载图片
  Future<void> loadImage(String filePath) async {
    _isLoading = true;
    _errorMessage = null;
    _wasSwapped = false;
    notifyListeners();

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }

      // 检查文件类型
      final extension = filePath.toLowerCase().split('.').last;
      if (!['png', 'jpg', 'jpeg', 'webp'].contains(extension)) {
        throw Exception('不支持的图片格式，请使用 PNG、JPG 或 WEBP');
      }

      // 读取图片尺寸
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      _imageFile = file;
      _imageSize = Size(image.width.toDouble(), image.height.toDouble());

      // 智能网格适配（根据图片方向自动交换行列）
      _applySmartGridFit();

      // 重置 margin
      _margins = ImageMargins.zero;

      // 加载图片后自动检测边缘并生成网格
      await _generateGridLines(detectEdges: true);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      _imageFile = null;
      _imageSize = null;
      notifyListeners();
    }
  }

  /// 智能网格适配
  /// 如果图片是竖向的但网格是横向的，自动交换行列
  void _applySmartGridFit() {
    if (_imageSize == null) return;

    final imageIsPortrait = _imageSize!.height > _imageSize!.width;
    final gridIsLandscape = _gridConfig.cols > _gridConfig.rows;

    // 如果图片方向和网格方向不一致，自动交换
    if (imageIsPortrait && gridIsLandscape) {
      _gridConfig = _gridConfig.swap();
      _wasSwapped = true;
    } else if (!imageIsPortrait &&
        !gridIsLandscape &&
        _gridConfig.rows > _gridConfig.cols) {
      // 横向图片但网格是竖向的
      _gridConfig = _gridConfig.swap();
      _wasSwapped = true;
    }
  }

  /// 设置行数
  Future<void> setRows(int rows) async {
    if (rows > 0 && rows <= 50) {
      _gridConfig = _gridConfig.copyWith(rows: rows);
      _wasSwapped = false;
      await _generateGridLines();
      notifyListeners();
    }
  }

  /// 设置列数
  Future<void> setCols(int cols) async {
    if (cols > 0 && cols <= 50) {
      _gridConfig = _gridConfig.copyWith(cols: cols);
      _wasSwapped = false;
      await _generateGridLines();
      notifyListeners();
    }
  }

  /// 设置网格配置
  Future<void> setGridConfig(GridConfig config) async {
    _gridConfig = config;
    _wasSwapped = false;
    if (_imageSize != null) {
      _applySmartGridFit();
      await _generateGridLines();
    }
    notifyListeners();
  }

  /// 设置边距（不自动重新生成网格，需手动触发）
  void setMargins(ImageMargins margins) {
    if (_imageSize == null) return;

    // 验证边距有效性
    final error = margins.validate(_imageSize!);
    if (error != null) {
      // 无效边距，不应用
      return;
    }

    // 如果边距没有变化，不保存历史
    if (_margins == margins) return;

    _saveToHistory();
    _margins = margins;
    notifyListeners();
  }

  /// 设置单个边距值
  void setMarginTop(double value) {
    setMargins(_margins.copyWith(top: value.clamp(0, double.infinity)));
  }

  void setMarginBottom(double value) {
    setMargins(_margins.copyWith(bottom: value.clamp(0, double.infinity)));
  }

  void setMarginLeft(double value) {
    setMargins(_margins.copyWith(left: value.clamp(0, double.infinity)));
  }

  void setMarginRight(double value) {
    setMargins(_margins.copyWith(right: value.clamp(0, double.infinity)));
  }

  /// 重置边距为零（不自动重新生成网格，需手动触发）
  void resetMargins() {
    if (_margins == ImageMargins.zero) return;

    _saveToHistory();
    _margins = ImageMargins.zero;
    notifyListeners();
  }

  /// 更新网格线位置
  /// [index] 线的索引
  /// [newPosition] 新位置（相对位置 0.0-1.0）
  /// [isHorizontal] 是否是水平线
  void updateGridLine(int index, double newPosition, bool isHorizontal) {
    if (isHorizontal) {
      if (index >= 0 && index < _horizontalLines.length) {
        // 限制在 0.0-1.0 范围内
        _horizontalLines[index] = newPosition.clamp(0.0, 1.0);
        notifyListeners();
      }
    } else {
      if (index >= 0 && index < _verticalLines.length) {
        _verticalLines[index] = newPosition.clamp(0.0, 1.0);
        notifyListeners();
      }
    }
  }

  /// 重置状态
  void reset() {
    _imageFile = null;
    _imageSize = null;
    _pixelData = null;
    _isLoading = false;
    _errorMessage = null;
    _gridConfig = GridConfig.defaultConfig();
    _wasSwapped = false;
    _horizontalLines = [];
    _verticalLines = [];
    _isEditMode = false;
    _selectedLineIndex = null;
    _selectedLineIsHorizontal = null;
    _margins = ImageMargins.zero;
    notifyListeners();
  }

  /// 清除交换提示
  void clearSwapNotification() {
    _wasSwapped = false;
    notifyListeners();
  }
}

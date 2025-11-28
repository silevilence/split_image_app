import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/editor_history.dart';
import '../models/grid_config.dart';
import '../models/grid_line.dart';

/// 图片编辑器状态管理
class EditorProvider extends ChangeNotifier {
  // ============ 图片相关 ============

  /// 源图片文件
  File? _imageFile;
  File? get imageFile => _imageFile;

  /// 图片尺寸
  Size? _imageSize;
  Size? get imageSize => _imageSize;

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

  /// 水平网格线（相对位置 0.0-1.0）
  List<double> _horizontalLines = [];
  List<double> get horizontalLines => _horizontalLines;

  /// 垂直网格线（相对位置 0.0-1.0）
  List<double> _verticalLines = [];
  List<double> get verticalLines => _verticalLines;

  /// 是否已自动交换行列
  bool _wasSwapped = false;
  bool get wasSwapped => _wasSwapped;

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

  /// 获取当前网格线状态快照
  GridLinesSnapshot _getCurrentSnapshot() {
    return GridLinesSnapshot.from(
      horizontalLines: _horizontalLines,
      verticalLines: _verticalLines,
    );
  }

  /// 保存当前状态到历史记录（在修改前调用）
  void _saveToHistory() {
    _history.saveState(_getCurrentSnapshot());
  }

  /// 从快照恢复状态
  void _restoreFromSnapshot(GridLinesSnapshot snapshot) {
    _horizontalLines = List<double>.from(snapshot.horizontalLines);
    _verticalLines = List<double>.from(snapshot.verticalLines);
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
        final newPos = (_horizontalLines[_selectedLineIndex!] + delta).clamp(0.0, 1.0);
        _horizontalLines[_selectedLineIndex!] = newPos;
        notifyListeners();
      }
    } else {
      if (_selectedLineIndex! < _verticalLines.length) {
        final newPos = (_verticalLines[_selectedLineIndex!] + delta).clamp(0.0, 1.0);
        _verticalLines[_selectedLineIndex!] = newPos;
        notifyListeners();
      }
    }
  }

  /// 根据行列数生成均匀分布的网格线
  void _generateGridLines() {
    if (_imageSize == null) {
      _horizontalLines = [];
      _verticalLines = [];
      return;
    }

    // 生成水平线（行数-1条）
    _horizontalLines = List.generate(
      _gridConfig.rows - 1,
      (i) => (i + 1) / _gridConfig.rows,
    );

    // 生成垂直线（列数-1条）
    _verticalLines = List.generate(
      _gridConfig.cols - 1,
      (i) => (i + 1) / _gridConfig.cols,
    );
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

      // 智能网格适配
      _applySmartGridFit();

      // 生成网格线
      _generateGridLines();

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
    } else if (!imageIsPortrait && !gridIsLandscape && _gridConfig.rows > _gridConfig.cols) {
      // 横向图片但网格是竖向的
      _gridConfig = _gridConfig.swap();
      _wasSwapped = true;
    }
  }

  /// 设置行数
  void setRows(int rows) {
    if (rows > 0 && rows <= 50) {
      _gridConfig = _gridConfig.copyWith(rows: rows);
      _wasSwapped = false;
      _generateGridLines();
      notifyListeners();
    }
  }

  /// 设置列数
  void setCols(int cols) {
    if (cols > 0 && cols <= 50) {
      _gridConfig = _gridConfig.copyWith(cols: cols);
      _wasSwapped = false;
      _generateGridLines();
      notifyListeners();
    }
  }

  /// 设置网格配置
  void setGridConfig(GridConfig config) {
    _gridConfig = config;
    _wasSwapped = false;
    if (_imageSize != null) {
      _applySmartGridFit();
      _generateGridLines();
    }
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
    _isLoading = false;
    _errorMessage = null;
    _gridConfig = GridConfig.defaultConfig();
    _wasSwapped = false;
    _horizontalLines = [];
    _verticalLines = [];
    _isEditMode = false;
    _selectedLineIndex = null;
    _selectedLineIsHorizontal = null;
    notifyListeners();
  }

  /// 清除交换提示
  void clearSwapNotification() {
    _wasSwapped = false;
    notifyListeners();
  }
}

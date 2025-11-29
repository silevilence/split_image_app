/// 编辑器历史记录系统
/// 用于支持撤销/重做功能

import 'margins.dart';

/// 编辑器状态快照（包含网格线和边距）
class EditorSnapshot {
  final List<double> horizontalLines;
  final List<double> verticalLines;
  final ImageMargins margins;

  const EditorSnapshot({
    required this.horizontalLines,
    required this.verticalLines,
    required this.margins,
  });

  /// 创建当前状态的深拷贝
  EditorSnapshot.from({
    required List<double> horizontalLines,
    required List<double> verticalLines,
    required ImageMargins margins,
  }) : horizontalLines = List<double>.from(horizontalLines),
       verticalLines = List<double>.from(verticalLines),
       margins = margins;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EditorSnapshot) return false;
    if (horizontalLines.length != other.horizontalLines.length) return false;
    if (verticalLines.length != other.verticalLines.length) return false;
    if (margins != other.margins) return false;
    for (int i = 0; i < horizontalLines.length; i++) {
      if (horizontalLines[i] != other.horizontalLines[i]) return false;
    }
    for (int i = 0; i < verticalLines.length; i++) {
      if (verticalLines[i] != other.verticalLines[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(horizontalLines),
    Object.hashAll(verticalLines),
    margins,
  );
}

/// 旧版快照类型别名（保持向后兼容）
typedef GridLinesSnapshot = EditorSnapshot;

/// 编辑器历史记录管理器
class EditorHistory {
  /// 历史记录栈
  final List<EditorSnapshot> _undoStack = [];

  /// 重做栈
  final List<EditorSnapshot> _redoStack = [];

  /// 最大历史记录数量
  static const int maxHistorySize = 50;

  /// 是否可以撤销
  bool get canUndo => _undoStack.isNotEmpty;

  /// 是否可以重做
  bool get canRedo => _redoStack.isNotEmpty;

  /// 撤销栈长度
  int get undoStackLength => _undoStack.length;

  /// 重做栈长度
  int get redoStackLength => _redoStack.length;

  /// 保存当前状态到历史记录
  /// 调用此方法时，会清空重做栈
  void saveState(EditorSnapshot snapshot) {
    // 如果和上一个状态相同，不保存
    if (_undoStack.isNotEmpty && _undoStack.last == snapshot) {
      return;
    }

    _undoStack.add(snapshot);
    _redoStack.clear();

    // 限制历史记录数量
    while (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }

  /// 撤销操作
  /// 返回要恢复的状态，如果无法撤销则返回 null
  EditorSnapshot? undo(EditorSnapshot currentState) {
    if (!canUndo) return null;

    // 将当前状态保存到重做栈
    _redoStack.add(currentState);

    // 弹出上一个状态
    return _undoStack.removeLast();
  }

  /// 重做操作
  /// 返回要恢复的状态，如果无法重做则返回 null
  EditorSnapshot? redo(EditorSnapshot currentState) {
    if (!canRedo) return null;

    // 将当前状态保存到撤销栈
    _undoStack.add(currentState);

    // 弹出重做状态
    return _redoStack.removeLast();
  }

  /// 清空历史记录
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}

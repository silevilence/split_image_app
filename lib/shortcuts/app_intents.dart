import 'package:flutter/widgets.dart';

/// 应用快捷键 Intent 定义
///
/// 每个 Intent 代表一个可通过快捷键触发的操作

/// 切换编辑/查看模式
class ToggleModeIntent extends Intent {
  const ToggleModeIntent();
}

/// 删除选中的网格线
class DeleteLineIntent extends Intent {
  const DeleteLineIntent();
}

/// 撤销操作
class UndoIntent extends Intent {
  const UndoIntent();
}

/// 重做操作
class RedoIntent extends Intent {
  const RedoIntent();
}

/// 向上微调选中线
class NudgeUpIntent extends Intent {
  const NudgeUpIntent();
}

/// 向下微调选中线
class NudgeDownIntent extends Intent {
  const NudgeDownIntent();
}

/// 向左微调选中线
class NudgeLeftIntent extends Intent {
  const NudgeLeftIntent();
}

/// 向右微调选中线
class NudgeRightIntent extends Intent {
  const NudgeRightIntent();
}

/// 生成预览
class GeneratePreviewIntent extends Intent {
  const GeneratePreviewIntent();
}

/// 导出切片
class ExportSlicesIntent extends Intent {
  const ExportSlicesIntent();
}

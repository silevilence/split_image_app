import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../providers/editor_provider.dart';
import '../providers/preview_provider.dart';
import '../services/config_service.dart';
import 'app_intents.dart';
import 'shortcut_manager.dart';

/// 快捷键包装组件
///
/// 将 Flutter Shortcuts/Actions 系统包装到应用中，
/// 支持从配置文件读取快捷键，并在配置变化时自动更新。
class ShortcutWrapper extends StatefulWidget {
  final Widget child;

  /// 是否显示快捷键操作的 InfoBar 通知
  final bool showNotifications;

  const ShortcutWrapper({
    super.key,
    required this.child,
    this.showNotifications = true,
  });

  @override
  State<ShortcutWrapper> createState() => _ShortcutWrapperState();
}

class _ShortcutWrapperState extends State<ShortcutWrapper> {
  final _shortcutManager = AppShortcutManager.instance;

  @override
  void initState() {
    super.initState();
    // 监听快捷键配置变化
    _shortcutManager.addListener(_onShortcutChanged);
  }

  @override
  void dispose() {
    _shortcutManager.removeListener(_onShortcutChanged);
    super.dispose();
  }

  void _onShortcutChanged() {
    // 重新构建以更新快捷键映射
    if (mounted) {
      setState(() {});
    }
  }

  void _showNotification(
    String message, {
    InfoBarSeverity severity = InfoBarSeverity.info,
  }) {
    if (!widget.showNotifications || !mounted) return;

    displayInfoBar(
      context,
      builder: (ctx, close) =>
          InfoBar(title: Text(message), severity: severity),
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editorProvider = context.watch<EditorProvider>();

    return Shortcuts(
      shortcuts: _shortcutManager.shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          // 切换模式
          ToggleModeIntent: CallbackAction<ToggleModeIntent>(
            onInvoke: (intent) {
              editorProvider.toggleEditMode();
              _showNotification(
                editorProvider.isEditMode ? '已切换到编辑模式' : '已切换到查看模式',
              );
              return null;
            },
          ),

          // 删除线条
          DeleteLineIntent: CallbackAction<DeleteLineIntent>(
            onInvoke: (intent) {
              if (!editorProvider.isEditMode ||
                  !editorProvider.hasSelectedLine) {
                return null;
              }
              editorProvider.deleteSelectedLine();
              _showNotification('已删除网格线', severity: InfoBarSeverity.success);
              return null;
            },
          ),

          // 撤销
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (intent) {
              if (!editorProvider.canUndo) return null;
              editorProvider.undo();
              _showNotification('已撤销');
              return null;
            },
          ),

          // 重做
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (intent) {
              if (!editorProvider.canRedo) return null;
              editorProvider.redo();
              _showNotification('已重做');
              return null;
            },
          ),

          // 向上微调
          NudgeUpIntent: CallbackAction<NudgeUpIntent>(
            onInvoke: (intent) => _handleNudge(editorProvider, 0, -1),
          ),

          // 向下微调
          NudgeDownIntent: CallbackAction<NudgeDownIntent>(
            onInvoke: (intent) => _handleNudge(editorProvider, 0, 1),
          ),

          // 向左微调
          NudgeLeftIntent: CallbackAction<NudgeLeftIntent>(
            onInvoke: (intent) => _handleNudge(editorProvider, -1, 0),
          ),

          // 向右微调
          NudgeRightIntent: CallbackAction<NudgeRightIntent>(
            onInvoke: (intent) => _handleNudge(editorProvider, 1, 0),
          ),

          // 生成预览
          GeneratePreviewIntent: CallbackAction<GeneratePreviewIntent>(
            onInvoke: (intent) {
              if (editorProvider.imageFile == null) return null;
              final previewProvider = context.read<PreviewProvider>();
              previewProvider.generatePreview(
                imageFile: editorProvider.imageFile!,
                horizontalLines: editorProvider.horizontalLines,
                verticalLines: editorProvider.verticalLines,
                imageSize: editorProvider.imageSize!,
                margins: editorProvider.margins,
              );
              return null;
            },
          ),
        },
        child: widget.child,
      ),
    );
  }

  /// 处理方向键微调
  Object? _handleNudge(EditorProvider provider, int dx, int dy) {
    if (!provider.isEditMode ||
        !provider.hasSelectedLine ||
        provider.imageSize == null) {
      return null;
    }

    final imageSize = provider.imageSize!;
    final isHorizontal = provider.selectedLineIsHorizontal ?? false;

    double delta = 0;
    if (isHorizontal && dy != 0) {
      delta = dy / imageSize.height;
    } else if (!isHorizontal && dx != 0) {
      delta = dx / imageSize.width;
    }

    if (delta != 0) {
      provider.nudgeSelectedLine(delta, saveHistory: true);
    }

    return null;
  }
}

/// 获取快捷键提示文本
///
/// 用于在 Tooltip 中显示操作对应的快捷键
String getShortcutHint(String action) {
  final config = ConfigService.instance.config.shortcuts;
  String shortcut;

  switch (action) {
    case 'toggleMode':
      shortcut = config.toggleMode;
      break;
    case 'deleteLine':
      shortcut = config.deleteLine;
      break;
    case 'undo':
      shortcut = config.undo;
      break;
    case 'redo':
      shortcut = config.redo;
      break;
    default:
      return '';
  }

  return AppShortcutManager.formatShortcut(shortcut);
}

/// 构建带快捷键提示的 Tooltip 消息
String buildTooltipWithShortcut(String message, String action) {
  final hint = getShortcutHint(action);
  if (hint.isEmpty) return message;
  return '$message ($hint)';
}

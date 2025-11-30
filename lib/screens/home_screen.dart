import 'package:desktop_drop/desktop_drop.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../providers/editor_provider.dart';
import '../widgets/editor_canvas.dart';
import '../widgets/preview_panel.dart';

/// 主页面 - Split View 布局
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDraggingOverCanvas = false;
  double _panelWidth = 360; // 可调整的面板宽度
  static const double _minPanelWidth = 280;
  static const double _maxPanelWidth = 600;
  bool _isResizing = false;

  /// 处理拖拽到画布的文件
  Future<void> _handleDroppedFiles(List<String> paths) async {
    if (paths.isEmpty) return;

    final path = paths.first;
    final extension = path.toLowerCase().split('.').last;

    if (['png', 'jpg', 'jpeg', 'webp'].contains(extension)) {
      final provider = context.read<EditorProvider>();
      await provider.loadImage(path);
    } else {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('不支持的文件格式'),
            content: const Text('请使用 PNG、JPG 或 WEBP 格式的图片'),
            severity: InfoBarSeverity.warning,
            onClose: close,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return NavigationView(
      appBar: NavigationAppBar(
        automaticallyImplyLeading: false,
        title: _buildTitle(theme),
      ),
      content: Row(
        children: [
          // 左侧: 编辑器画布 (70%)
          Expanded(
            flex: 7,
            child: DropTarget(
              onDragEntered: (_) =>
                  setState(() => _isDraggingOverCanvas = true),
              onDragExited: (_) =>
                  setState(() => _isDraggingOverCanvas = false),
              onDragDone: (details) {
                setState(() => _isDraggingOverCanvas = false);
                _handleDroppedFiles(details.files.map((f) => f.path).toList());
              },
              child: Container(
                decoration: BoxDecoration(
                  border: _isDraggingOverCanvas
                      ? Border.all(color: theme.accentColor, width: 2)
                      : null,
                ),
                child: const EditorCanvas(),
              ),
            ),
          ),
          // 可拖拽的分隔条
          _buildResizeHandle(theme),
          // 右侧: 预览与控制面板 (可调整宽度)
          SizedBox(width: _panelWidth, child: const PreviewPanel()),
        ],
      ),
    );
  }

  /// 构建可拖拽的分隔条
  Widget _buildResizeHandle(FluentThemeData theme) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragStart: (_) => setState(() => _isResizing = true),
        onHorizontalDragEnd: (_) => setState(() => _isResizing = false),
        onHorizontalDragUpdate: (details) {
          setState(() {
            _panelWidth = (_panelWidth - details.delta.dx).clamp(
              _minPanelWidth,
              _maxPanelWidth,
            );
          });
        },
        child: Container(
          width: 6,
          color: _isResizing
              ? theme.accentColor.withValues(alpha: 0.3)
              : Colors.transparent,
          child: Center(
            child: Container(
              width: 2,
              height: 40,
              decoration: BoxDecoration(
                color: _isResizing
                    ? theme.accentColor
                    : theme.resources.dividerStrokeColorDefault,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildTitle(FluentThemeData theme) {
    final provider = context.watch<EditorProvider>();
    final fileName = provider.imageFile?.path.split('\\').last;

    return Row(
      children: [
        Icon(FluentIcons.grid_view_medium, color: theme.accentColor),
        const SizedBox(width: 8),
        Text(
          'SmartGridSlicer',
          style: theme.typography.body?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (fileName != null) ...[
          const SizedBox(width: 12),
          Text('- $fileName', style: theme.typography.caption),
        ],
      ],
    );
  }
}

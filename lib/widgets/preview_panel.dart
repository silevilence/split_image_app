import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../providers/editor_provider.dart';
import '../providers/preview_provider.dart';
import 'preview_gallery.dart';

/// 右侧预览与控制面板
class PreviewPanel extends StatefulWidget {
  const PreviewPanel({super.key});

  @override
  State<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<PreviewPanel> {
  final TextEditingController _rowsController = TextEditingController(text: '4');
  final TextEditingController _colsController = TextEditingController(text: '6');
  bool _isDragging = false;
  bool _isSettingsExpanded = true; // 设置区是否展开

  @override
  void initState() {
    super.initState();
    // 监听 Provider 变化更新输入框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<EditorProvider>();
      _rowsController.text = provider.gridConfig.rows.toString();
      _colsController.text = provider.gridConfig.cols.toString();
    });
  }

  @override
  void dispose() {
    _rowsController.dispose();
    _colsController.dispose();
    super.dispose();
  }

  /// 选择图片文件
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      dialogTitle: '选择图片',
    );

    if (result != null && result.files.single.path != null) {
      if (mounted) {
        final provider = context.read<EditorProvider>();
        await provider.loadImage(result.files.single.path!);
        _updateTextFields();
      }
    }
  }

  /// 处理拖拽文件
  Future<void> _handleDroppedFiles(List<String> paths) async {
    if (paths.isEmpty) return;

    // 只处理第一个文件
    final path = paths.first;
    final extension = path.toLowerCase().split('.').last;

    if (['png', 'jpg', 'jpeg', 'webp'].contains(extension)) {
      final provider = context.read<EditorProvider>();
      await provider.loadImage(path);
      _updateTextFields();
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

  /// 更新文本框显示
  void _updateTextFields() {
    final provider = context.read<EditorProvider>();
    _rowsController.text = provider.gridConfig.rows.toString();
    _colsController.text = provider.gridConfig.cols.toString();
  }

  /// 应用行列设置
  void _applyGridSettings() {
    final provider = context.read<EditorProvider>();
    final rows = int.tryParse(_rowsController.text) ?? 4;
    final cols = int.tryParse(_colsController.text) ?? 4;

    provider.setRows(rows.clamp(1, 50));
    provider.setCols(cols.clamp(1, 50));

    _updateTextFields();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();
    final theme = FluentTheme.of(context);

    // 显示自动交换提示
    if (provider.wasSwapped) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _updateTextFields();
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('已自动调整'),
            content: Text(
              '检测到图片方向与网格不匹配，已自动交换为 ${provider.gridConfig.rows} 行 ${provider.gridConfig.cols} 列',
            ),
            severity: InfoBarSeverity.info,
            onClose: close,
          ),
        );
        provider.clearSwapNotification();
      });
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        _handleDroppedFiles(details.files.map((f) => f.path).toList());
      },
      child: Container(
        decoration: BoxDecoration(
          color: _isDragging
              ? theme.accentColor.withValues(alpha: 0.1)
              : theme.cardColor,
          border: _isDragging
              ? Border.all(color: theme.accentColor, width: 2)
              : Border(
                  left: BorderSide(
                    color: theme.resources.dividerStrokeColorDefault,
                  ),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏
            _buildHeader(theme),
            // 上半部分：可折叠的设置区
            _buildCollapsibleSettings(theme, provider),
            // 分隔线
            Divider(
              style: DividerThemeData(
                horizontalMargin: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            // 下半部分：预览区（主要空间）
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildPreviewSection(theme, provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
      ),
      child: Text(
        '控制面板',
        style: theme.typography.subtitle,
      ),
    );
  }

  /// 构建可折叠的设置区
  Widget _buildCollapsibleSettings(FluentThemeData theme, EditorProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 折叠标题栏
        GestureDetector(
          onTap: () => setState(() => _isSettingsExpanded = !_isSettingsExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.transparent,
            child: Row(
              children: [
                Icon(
                  _isSettingsExpanded ? FluentIcons.chevron_down : FluentIcons.chevron_right,
                  size: 12,
                ),
                const SizedBox(width: 8),
                Text('设置', style: theme.typography.bodyStrong),
                const Spacer(),
                Text(
                  _isSettingsExpanded ? '点击收起' : '点击展开',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 展开的内容
        if (_isSettingsExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 文件操作区
                _buildFileSection(theme, provider),
                const SizedBox(height: 12),
                // 网格设置区（紧凑版）
                _buildCompactGridSettings(theme, provider),
                const SizedBox(height: 12),
                // 编辑操作区（紧凑版）
                _buildCompactEditActions(theme, provider),
              ],
            ),
          ),
      ],
    );
  }

  /// 紧凑版网格设置
  Widget _buildCompactGridSettings(FluentThemeData theme, EditorProvider provider) {
    return Row(
      children: [
        Text('网格:', style: theme.typography.body),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: NumberBox<int>(
            value: int.tryParse(_rowsController.text),
            min: 1,
            max: 50,
            mode: SpinButtonPlacementMode.none,
            onChanged: (value) {
              if (value != null) {
                _rowsController.text = value.toString();
                provider.setRows(value);
              }
            },
          ),
        ),
        const SizedBox(width: 4),
        const Text('×'),
        const SizedBox(width: 4),
        SizedBox(
          width: 60,
          child: NumberBox<int>(
            value: int.tryParse(_colsController.text),
            min: 1,
            max: 50,
            mode: SpinButtonPlacementMode.none,
            onChanged: (value) {
              if (value != null) {
                _colsController.text = value.toString();
                provider.setCols(value);
              }
            },
          ),
        ),
        const Spacer(),
        // 切片尺寸预估
        if (provider.imageSize != null)
          Text(
            '${(provider.imageSize!.width / provider.gridConfig.cols).toStringAsFixed(0)}×'
            '${(provider.imageSize!.height / provider.gridConfig.rows).toStringAsFixed(0)}px',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
      ],
    );
  }

  /// 紧凑版编辑操作
  Widget _buildCompactEditActions(FluentThemeData theme, EditorProvider provider) {
    return Row(
      children: [
        // 撤销
        Tooltip(
          message: '撤销 (Ctrl+Z)',
          child: IconButton(
            icon: const Icon(FluentIcons.undo, size: 16),
            onPressed: provider.canUndo ? provider.undo : null,
          ),
        ),
        // 重做
        Tooltip(
          message: '重做 (Ctrl+Y)',
          child: IconButton(
            icon: const Icon(FluentIcons.redo, size: 16),
            onPressed: provider.canRedo ? provider.redo : null,
          ),
        ),
        const Spacer(),
        // 编辑模式切换
        ToggleSwitch(
          checked: provider.isEditMode,
          onChanged: (v) => provider.setEditMode(v),
          content: Text(
            provider.isEditMode ? '编辑' : '查看',
            style: theme.typography.caption,
          ),
        ),
      ],
    );
  }

  /// 构建文件操作区
  Widget _buildFileSection(FluentThemeData theme, EditorProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: provider.isLoading ? null : _pickImage,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(FluentIcons.open_file, size: 14),
                    const SizedBox(width: 6),
                    Text(provider.isLoading ? '加载中...' : '选择图片'),
                  ],
                ),
              ),
            ),
            if (provider.imageFile != null) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: '清除图片',
                child: IconButton(
                  icon: const Icon(FluentIcons.clear, size: 16),
                  onPressed: provider.reset,
                ),
              ),
            ],
          ],
        ),
        // 错误提示
        if (provider.errorMessage != null) ...[
          const SizedBox(height: 8),
          InfoBar(
            title: const Text('加载失败'),
            content: Text(provider.errorMessage!),
            severity: InfoBarSeverity.error,
          ),
        ],
      ],
    );
  }

  /// 构建网格设置区
  Widget _buildGridSettingsSection(
      FluentThemeData theme, EditorProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('网格设置', style: theme.typography.bodyStrong),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InfoLabel(
                label: '行数',
                child: NumberBox<int>(
                  value: int.tryParse(_rowsController.text),
                  min: 1,
                  max: 50,
                  mode: SpinButtonPlacementMode.compact,
                  onChanged: (value) {
                    if (value != null) {
                      _rowsController.text = value.toString();
                      provider.setRows(value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InfoLabel(
                label: '列数',
                child: NumberBox<int>(
                  value: int.tryParse(_colsController.text),
                  min: 1,
                  max: 50,
                  mode: SpinButtonPlacementMode.compact,
                  onChanged: (value) {
                    if (value != null) {
                      _colsController.text = value.toString();
                      provider.setCols(value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 网格信息
        if (provider.imageSize != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.micaBackgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '每个切片尺寸 (预估)',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(provider.imageSize!.width / provider.gridConfig.cols).toStringAsFixed(0)} × '
                  '${(provider.imageSize!.height / provider.gridConfig.rows).toStringAsFixed(0)} px',
                  style: theme.typography.body,
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 构建编辑操作区（撤销/重做）
  Widget _buildEditActionsSection(
      FluentThemeData theme, EditorProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('编辑操作', style: theme.typography.bodyStrong),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Button(
                onPressed: provider.canUndo
                    ? () {
                        provider.undo();
                        displayInfoBar(
                          context,
                          builder: (ctx, close) => const InfoBar(
                            title: Text('已撤销'),
                            severity: InfoBarSeverity.info,
                          ),
                          duration: const Duration(milliseconds: 800),
                        );
                      }
                    : null,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FluentIcons.undo, size: 14),
                    SizedBox(width: 6),
                    Text('撤销'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Button(
                onPressed: provider.canRedo
                    ? () {
                        provider.redo();
                        displayInfoBar(
                          context,
                          builder: (ctx, close) => const InfoBar(
                            title: Text('已重做'),
                            severity: InfoBarSeverity.info,
                          ),
                          duration: const Duration(milliseconds: 800),
                        );
                      }
                    : null,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FluentIcons.redo, size: 14),
                    SizedBox(width: 6),
                    Text('重做'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 快捷键提示
        Text(
          '快捷键: Ctrl+Z 撤销, Ctrl+Y 重做',
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorTertiary,
          ),
        ),
      ],
    );
  }

  /// 生成预览
  Future<void> _generatePreview() async {
    final editorProvider = context.read<EditorProvider>();
    final previewProvider = context.read<PreviewProvider>();

    if (editorProvider.imageFile == null || editorProvider.imageSize == null) {
      return;
    }

    await previewProvider.generatePreview(
      imageFile: editorProvider.imageFile!,
      horizontalLines: editorProvider.horizontalLines,
      verticalLines: editorProvider.verticalLines,
      imageSize: editorProvider.imageSize!,
    );
  }

  /// 构建预览区
  Widget _buildPreviewSection(FluentThemeData theme, EditorProvider provider) {
    final previewProvider = context.watch<PreviewProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('预览与导出', style: theme.typography.bodyStrong),
            const Spacer(),
            if (previewProvider.hasPreview)
              Text(
                '${previewProvider.selectedCount}/${previewProvider.totalCount} 已选',
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // 生成预览按钮
        FilledButton(
          onPressed: provider.imageFile != null && !previewProvider.isGenerating
              ? _generatePreview
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (previewProvider.isGenerating)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: ProgressRing(strokeWidth: 2),
                  ),
                )
              else
                const Icon(FluentIcons.grid_view_medium, size: 16),
              const SizedBox(width: 8),
              Text(previewProvider.isGenerating ? '生成中...' : '生成预览'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 预览画廊
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.micaBackgroundColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.resources.dividerStrokeColorDefault,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: const PreviewGallery(),
          ),
        ),
      ],
    );
  }
}

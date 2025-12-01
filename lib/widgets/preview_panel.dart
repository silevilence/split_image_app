import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../providers/editor_provider.dart';
import '../providers/pipeline_provider.dart';
import '../providers/preview_provider.dart';
import '../services/config_service.dart';
import '../shortcuts/shortcut_wrapper.dart';
import '../utils/image_processor.dart';
import 'export_dialog.dart';
import 'margins_input.dart';
import 'pipeline_summary.dart';
import 'preview_gallery.dart';
import 'progress_dialog.dart';

/// 右侧预览与控制面板
class PreviewPanel extends StatefulWidget {
  const PreviewPanel({super.key});

  @override
  State<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<PreviewPanel> {
  late final TextEditingController _rowsController;
  late final TextEditingController _colsController;
  bool _isDragging = false;
  bool _isPickingFile = false; // 防止重复打开文件选择器

  @override
  void initState() {
    super.initState();
    // 从配置读取默认行列数作为输入框初始值
    final config = ConfigService.instance.config;
    _rowsController = TextEditingController(
      text: config.grid.defaultRows.toString(),
    );
    _colsController = TextEditingController(
      text: config.grid.defaultCols.toString(),
    );

    // 监听 Provider 变化更新输入框（用于智能交换后同步）
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
    // 防止重复打开文件选择器
    if (_isPickingFile) return;

    setState(() => _isPickingFile = true);

    try {
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
    } finally {
      if (mounted) {
        setState(() => _isPickingFile = false);
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
            // 三分区布局：设置、图片处理、预览导出
            Expanded(child: _buildThreeSectionLayout(theme, provider)),
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
      child: Text('控制面板', style: theme.typography.subtitle),
    );
  }

  /// 构建三分区布局（设置、图片处理、预览导出）
  Widget _buildThreeSectionLayout(
    FluentThemeData theme,
    EditorProvider provider,
  ) {
    final previewProvider = context.watch<PreviewProvider>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 设置分区
          _buildSettingsExpander(theme, provider),
          // 图片处理分区
          _buildPipelineExpander(theme),
          // 预览与导出分区
          _buildPreviewExpander(theme, provider, previewProvider),
        ],
      ),
    );
  }

  /// 设置区 Expander
  Widget _buildSettingsExpander(
    FluentThemeData theme,
    EditorProvider provider,
  ) {
    return Expander(
      initiallyExpanded: true,
      header: Row(
        children: [
          Icon(FluentIcons.settings, size: 16, color: theme.accentColor),
          const SizedBox(width: 8),
          Text('设置', style: theme.typography.bodyStrong),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 文件操作区
          _buildFileSection(theme, provider),
          const SizedBox(height: 16),
          // 网格设置区
          _buildCompactGridSettings(theme, provider),
          const SizedBox(height: 16),
          // 边距设置区
          const MarginsInput(),
          const SizedBox(height: 16),
          // 编辑操作区
          _buildCompactEditActions(theme, provider),
        ],
      ),
    );
  }

  /// 图片处理 Expander
  Widget _buildPipelineExpander(FluentThemeData theme) {
    return Expander(
      initiallyExpanded: true,
      header: Row(
        children: [
          Icon(FluentIcons.flow, size: 16, color: theme.accentColor),
          const SizedBox(width: 8),
          Text('图片处理', style: theme.typography.bodyStrong),
        ],
      ),
      content: PipelineSummary(onReapply: _applyPipeline),
    );
  }

  /// 预览与导出 Expander
  Widget _buildPreviewExpander(
    FluentThemeData theme,
    EditorProvider provider,
    PreviewProvider previewProvider,
  ) {
    return Expander(
      initiallyExpanded: true,
      header: Row(
        children: [
          Icon(
            FluentIcons.grid_view_medium,
            size: 16,
            color: theme.accentColor,
          ),
          const SizedBox(width: 8),
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
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 生成预览按钮
          FilledButton(
            onPressed:
                provider.imageFile != null && !previewProvider.isGenerating
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
          const SizedBox(height: 8),
          // 导出按钮
          Button(
            onPressed:
                previewProvider.hasPreview && previewProvider.selectedCount > 0
                ? _exportSlices
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(FluentIcons.save, size: 16),
                const SizedBox(width: 8),
                Text('导出选中 (${previewProvider.selectedCount})'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 预览画廊 - 固定高度
          Container(
            height: 300,
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
        ],
      ),
    );
  }

  /// 应用图片处理流水线
  Future<void> _applyPipeline() async {
    final pipelineProvider = context.read<PipelineProvider>();

    // TODO: 实现实际的图片处理逻辑
    // 目前先标记更改已应用
    pipelineProvider.markChangesApplied();

    if (mounted) {
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('处理完成'),
          content: const Text('图片处理流水线已应用'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    }
  }

  /// 紧凑版网格设置
  Widget _buildCompactGridSettings(
    FluentThemeData theme,
    EditorProvider provider,
  ) {
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
  Widget _buildCompactEditActions(
    FluentThemeData theme,
    EditorProvider provider,
  ) {
    return Row(
      children: [
        // 撤销
        Tooltip(
          message: buildTooltipWithShortcut('撤销', 'undo'),
          child: IconButton(
            icon: const Icon(FluentIcons.undo, size: 16),
            onPressed: provider.canUndo ? provider.undo : null,
          ),
        ),
        // 重做
        Tooltip(
          message: buildTooltipWithShortcut('重做', 'redo'),
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
    final isButtonDisabled = provider.isLoading || _isPickingFile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: isButtonDisabled ? null : _pickImage,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(FluentIcons.open_file, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      provider.isLoading
                          ? '加载中...'
                          : (_isPickingFile ? '选择中...' : '选择图片'),
                    ),
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
      margins: editorProvider.margins,
    );
  }

  /// 导出选中的切片
  Future<void> _exportSlices() async {
    final editorProvider = context.read<EditorProvider>();
    final previewProvider = context.read<PreviewProvider>();

    // 检查是否有选中的切片
    final selectedSlices = previewProvider.slices
        .where((s) => s.isSelected)
        .toList();
    if (selectedSlices.isEmpty) {
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('没有选中的切片'),
          content: const Text('请先选中要导出的切片'),
          severity: InfoBarSeverity.warning,
          onClose: close,
        ),
      );
      return;
    }

    // 获取源文件名
    final sourceFileName =
        editorProvider.imageFile?.path.split('\\').last ??
        editorProvider.imageFile?.path.split('/').last;

    // 显示导出设置对话框
    final settings = await ExportDialog.show(
      context,
      sourceFileName: sourceFileName,
      selectedCount: selectedSlices.length,
    );

    if (settings == null) return;

    // 读取原图字节数据
    final imageBytes = await editorProvider.imageFile!.readAsBytes();

    // 构建导出任务
    final exportSlices = selectedSlices
        .map(
          (slice) => ExportSlice(
            x: slice.region.left.toInt(),
            y: slice.region.top.toInt(),
            width: slice.region.width.toInt(),
            height: slice.region.height.toInt(),
            suffix: slice.customSuffix,
          ),
        )
        .toList();

    final task = ExportTask(
      imageBytes: imageBytes,
      slices: exportSlices,
      outputDir: settings.outputDir,
      prefix: settings.prefix,
      format: settings.format,
    );

    // 开始导出
    final progressStream = ImageProcessor.exportSlices(task);

    // 显示进度对话框
    if (mounted) {
      await ProgressDialog.show(
        context,
        progressStream: progressStream,
        outputDir: settings.outputDir,
        onComplete: () {
          // 导出完成后保存目录到配置
          ConfigService.instance.setLastExportDirectory(settings.outputDir);
        },
      );
    }
  }
}

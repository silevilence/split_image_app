import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../processors/processors.dart';
import '../providers/pipeline_provider.dart';
import 'processor_step_editor.dart';

/// Pipeline 管理弹窗
///
/// 用于编辑处理器链：添加/删除/重排序/重命名/参数编辑。
/// 支持导入/导出配置到 JSON 文件。
class PipelineManagerModal extends StatefulWidget {
  const PipelineManagerModal({super.key});

  /// 显示弹窗
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const PipelineManagerModal(),
    );
  }

  @override
  State<PipelineManagerModal> createState() => _PipelineManagerModalState();
}

class _PipelineManagerModalState extends State<PipelineManagerModal> {
  /// 当前选中的处理器索引
  int? _selectedIndex;

  /// 是否正在导入/导出
  bool _isImportExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final provider = context.watch<PipelineProvider>();

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
      title: Row(
        children: [
          Icon(FluentIcons.processing, color: theme.accentColor),
          const SizedBox(width: 8),
          const Text('图片处理流水线'),
          const Spacer(),
          // 导入按钮
          _buildImportButton(context, provider),
          const SizedBox(width: 8),
          // 导出按钮
          _buildExportButton(context, provider),
          const SizedBox(width: 12),
          // 添加处理器按钮
          _buildAddButton(context, provider),
        ],
      ),
      content: SizedBox(
        width: 750,
        height: 450,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左侧：处理器列表
            Expanded(
              flex: 2,
              child: _buildProcessorList(context, theme, provider),
            ),
            // 分隔线
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: theme.resources.dividerStrokeColorDefault,
            ),
            // 右侧：参数编辑
            Expanded(
              flex: 3,
              child: _buildParamEditor(context, theme, provider),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          child: const Text('关闭'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// 构建导入按钮
  Widget _buildImportButton(BuildContext context, PipelineProvider provider) {
    return Tooltip(
      message: '从 JSON 文件导入流水线配置',
      child: IconButton(
        icon: Icon(
          FluentIcons.import,
          size: 16,
          color: _isImportExporting ? Colors.grey[100] : null,
        ),
        onPressed: _isImportExporting
            ? null
            : () => _handleImport(context, provider),
      ),
    );
  }

  /// 构建导出按钮
  Widget _buildExportButton(BuildContext context, PipelineProvider provider) {
    final isEmpty = provider.processors.isEmpty;
    return Tooltip(
      message: isEmpty ? '流水线为空，无法导出' : '导出流水线配置到 JSON 文件',
      child: IconButton(
        icon: Icon(
          FluentIcons.export,
          size: 16,
          color: (isEmpty || _isImportExporting) ? Colors.grey[100] : null,
        ),
        onPressed: (isEmpty || _isImportExporting)
            ? null
            : () => _handleExport(context, provider),
      ),
    );
  }

  /// 处理导入操作
  Future<void> _handleImport(
    BuildContext context,
    PipelineProvider provider,
  ) async {
    // 如果已有内容，询问用户是覆盖还是追加
    bool append = false;
    if (provider.processors.isNotEmpty) {
      final choice = await _showImportModeDialog(context);
      if (choice == null) return; // 用户取消
      append = choice;
    }

    setState(() => _isImportExporting = true);

    try {
      final count = await provider.importPipelineFromJson(append: append);

      if (!context.mounted) return;

      if (count > 0) {
        // 成功导入
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('导入成功'),
            content: Text('已导入 $count 个处理步骤'),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );
        // 清除选中状态
        setState(() => _selectedIndex = null);
      } else if (count == 0) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('导入完成'),
            content: const Text('没有找到有效的处理步骤'),
            severity: InfoBarSeverity.warning,
            onClose: close,
          ),
        );
      }
      // count == -1 表示用户取消，不显示任何提示
    } finally {
      if (mounted) {
        setState(() => _isImportExporting = false);
      }
    }
  }

  /// 处理导出操作
  Future<void> _handleExport(
    BuildContext context,
    PipelineProvider provider,
  ) async {
    setState(() => _isImportExporting = true);

    try {
      final success = await provider.exportPipelineToJson();

      if (!context.mounted) return;

      if (success) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('导出成功'),
            content: const Text('流水线配置已保存'),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );
      } else if (provider.errorMessage != null) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('导出失败'),
            content: Text(provider.errorMessage!),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
        provider.clearError();
      }
    } finally {
      if (mounted) {
        setState(() => _isImportExporting = false);
      }
    }
  }

  /// 显示导入模式选择对话框
  ///
  /// 返回 true 表示追加，false 表示覆盖，null 表示取消
  Future<bool?> _showImportModeDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('导入方式'),
        content: const Text(
          '流水线中已有处理步骤，请选择导入方式：\n\n'
          '• 覆盖：清空现有步骤，使用导入的配置\n'
          '• 追加：在现有步骤后添加导入的配置',
        ),
        actions: [
          Button(
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(null),
          ),
          FilledButton(
            child: const Text('覆盖'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(
                FluentTheme.of(context).accentColor,
              ),
            ),
            child: const Text('追加'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  /// 构建添加处理器按钮
  Widget _buildAddButton(BuildContext context, PipelineProvider provider) {
    return DropDownButton(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.add, size: 14),
          SizedBox(width: 6),
          Text('添加'),
        ],
      ),
      items: ProcessorType.values.map((type) {
        return MenuFlyoutItem(
          leading: const Icon(FluentIcons.processing, size: 14),
          text: Text(type.displayName),
          onPressed: () {
            provider.addProcessor(type);
            setState(() {
              _selectedIndex = provider.processors.length - 1;
            });
          },
        );
      }).toList(),
    );
  }

  /// 构建处理器列表
  Widget _buildProcessorList(
    BuildContext context,
    FluentThemeData theme,
    PipelineProvider provider,
  ) {
    if (provider.processors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FluentIcons.processing,
              size: 48,
              color: theme.resources.textFillColorSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              '没有处理步骤',
              style: theme.typography.body?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击上方"添加"按钮\n添加图片处理步骤',
              textAlign: TextAlign.center,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: provider.processors.length,
      onReorder: (oldIndex, newIndex) {
        provider.reorderProcessor(oldIndex, newIndex);
        // 更新选中索引
        if (_selectedIndex != null) {
          if (_selectedIndex == oldIndex) {
            setState(() {
              _selectedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
            });
          } else if (oldIndex < _selectedIndex! && newIndex > _selectedIndex!) {
            setState(() => _selectedIndex = _selectedIndex! - 1);
          } else if (oldIndex > _selectedIndex! &&
              newIndex <= _selectedIndex!) {
            setState(() => _selectedIndex = _selectedIndex! + 1);
          }
        }
      },
      itemBuilder: (context, index) {
        final processor = provider.processors[index];
        final isSelected = _selectedIndex == index;

        return _ProcessorListItem(
          key: ValueKey(processor.instanceId),
          index: index,
          processor: processor,
          isSelected: isSelected,
          onTap: () => setState(() => _selectedIndex = index),
          onToggle: (enabled) => provider.setProcessorEnabled(index, enabled),
          onDelete: () {
            provider.removeProcessorAt(index);
            if (_selectedIndex == index) {
              setState(() => _selectedIndex = null);
            } else if (_selectedIndex != null && _selectedIndex! > index) {
              setState(() => _selectedIndex = _selectedIndex! - 1);
            }
          },
        );
      },
    );
  }

  /// 构建参数编辑区
  Widget _buildParamEditor(
    BuildContext context,
    FluentThemeData theme,
    PipelineProvider provider,
  ) {
    if (_selectedIndex == null ||
        _selectedIndex! >= provider.processors.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FluentIcons.edit,
              size: 48,
              color: theme.resources.textFillColorSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              '选择一个处理步骤',
              style: theme.typography.body?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '从左侧列表选择\n一个处理步骤进行编辑',
              textAlign: TextAlign.center,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final processor = provider.processors[_selectedIndex!];

    return ProcessorStepEditor(
      processor: processor,
      onNameChanged: (name) {
        provider.updateProcessorName(_selectedIndex!, name);
      },
      onParamChanged: (paramId, value) {
        provider.updateProcessorParam(_selectedIndex!, paramId, value);
      },
      onReset: () {
        provider.resetProcessorParams(_selectedIndex!);
      },
    );
  }
}

/// 处理器列表项
class _ProcessorListItem extends StatelessWidget {
  final int index;
  final ImageProcessor processor;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _ProcessorListItem({
    super.key,
    required this.index,
    required this.processor,
    required this.isSelected,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile.selectable(
        selected: isSelected,
        onPressed: onTap,
        leading: ReorderableDragStartListener(
          index: index,
          child: Icon(
            FluentIcons.more,
            size: 16,
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        title: Row(
          children: [
            // 启用复选框
            Checkbox(
              checked: processor.enabled,
              onChanged: (v) => onToggle(v ?? false),
            ),
            const SizedBox(width: 8),
            // 处理器名称
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    processor.displayName,
                    style: TextStyle(
                      color: processor.enabled
                          ? null
                          : theme.resources.textFillColorSecondary,
                    ),
                  ),
                  Text(
                    processor.type.description,
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(FluentIcons.delete, size: 14, color: Colors.red.light),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../processors/processors.dart';
import '../providers/pipeline_provider.dart';
import 'processor_step_editor.dart';

/// Pipeline 管理弹窗
///
/// 用于编辑处理器链：添加/删除/重排序/重命名/参数编辑。
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

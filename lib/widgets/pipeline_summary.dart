import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../providers/pipeline_provider.dart';
import 'pipeline_manager_modal.dart';

/// Pipeline 概要显示组件
///
/// 显示当前处理链的概要信息和控制按钮。
/// 位于侧边栏设置区和预览区之间。
class PipelineSummary extends StatelessWidget {
  /// 重新应用处理的回调
  final VoidCallback? onReapply;

  const PipelineSummary({super.key, this.onReapply});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final provider = context.watch<PipelineProvider>();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行
          Row(
            children: [
              Icon(FluentIcons.processing, size: 16, color: theme.accentColor),
              const SizedBox(width: 8),
              Text('图片处理', style: theme.typography.bodyStrong),
              const Spacer(),
              // 状态指示
              if (provider.hasUnappliedChanges)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '待应用',
                    style: theme.typography.caption?.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 概要信息
          _buildSummaryInfo(context, theme, provider),
          const SizedBox(height: 8),
          // 操作按钮
          _buildActions(context, theme, provider),
        ],
      ),
    );
  }

  /// 构建概要信息
  Widget _buildSummaryInfo(
    BuildContext context,
    FluentThemeData theme,
    PipelineProvider provider,
  ) {
    if (provider.processors.isEmpty) {
      return Text(
        '无处理步骤',
        style: theme.typography.caption?.copyWith(
          color: theme.resources.textFillColorSecondary,
        ),
      );
    }

    final enabledProcessors = provider.chain.enabledProcessors;
    final totalCount = provider.processors.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 处理器数量概要
        Row(
          children: [
            Icon(FluentIcons.check_mark, size: 12, color: theme.accentColor),
            const SizedBox(width: 4),
            Text(provider.summary, style: theme.typography.caption),
          ],
        ),
        // 显示前几个处理器名称
        if (enabledProcessors.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (int i = 0; i < enabledProcessors.length.clamp(0, 3); i++)
                _ProcessorChip(
                  name: enabledProcessors[i].displayName,
                  theme: theme,
                ),
              if (totalCount > 3)
                Text(
                  '+${totalCount - 3}',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActions(
    BuildContext context,
    FluentThemeData theme,
    PipelineProvider provider,
  ) {
    return Row(
      children: [
        // 编辑 Pipeline 按钮
        Expanded(
          child: Button(
            onPressed: () => _showPipelineManager(context),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.edit, size: 14),
                SizedBox(width: 6),
                Text('编辑'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 重新应用按钮
        Expanded(
          child: FilledButton(
            onPressed: provider.hasProcessors ? onReapply : null,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.play, size: 14),
                SizedBox(width: 6),
                Text('应用'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 显示 Pipeline 管理弹窗
  void _showPipelineManager(BuildContext context) {
    PipelineManagerModal.show(context);
  }
}

/// 处理器标签
class _ProcessorChip extends StatelessWidget {
  final String name;
  final FluentThemeData theme;

  const _ProcessorChip({required this.name, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        name,
        style: theme.typography.caption?.copyWith(color: theme.accentColor),
      ),
    );
  }
}

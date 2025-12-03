import 'package:fluent_ui/fluent_ui.dart';

import '../processors/processors.dart';
import 'color_picker_button.dart';

/// 单图参数覆盖编辑器
///
/// 用于在预览模态框中编辑单张图片的处理器参数覆盖。
/// 仅显示支持单图覆盖 (supportsPerImageOverride) 的参数。
class PerImageOverrideEditor extends StatefulWidget {
  /// 处理器链
  final ProcessorChain chain;

  /// 当前切片的覆盖参数 (processorInstanceId -> ProcessorParams)
  final Map<String, ProcessorParams> currentOverrides;

  /// 覆盖参数变更回调
  final void Function(
    String processorInstanceId,
    String paramId,
    dynamic value,
    bool isOverridden,
  )?
  onOverrideChanged;

  /// 移除覆盖回调
  final void Function(String processorInstanceId, String paramId)?
  onOverrideRemoved;

  /// 清除所有覆盖回调
  final VoidCallback? onClearAll;

  const PerImageOverrideEditor({
    super.key,
    required this.chain,
    required this.currentOverrides,
    this.onOverrideChanged,
    this.onOverrideRemoved,
    this.onClearAll,
  });

  @override
  State<PerImageOverrideEditor> createState() => _PerImageOverrideEditorState();
}

class _PerImageOverrideEditorState extends State<PerImageOverrideEditor> {
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final enabledProcessors = widget.chain.enabledProcessors;

    // 筛选有单图覆盖参数的处理器
    final processorsWithPerImageParams = enabledProcessors
        .where((p) => p.hasPerImageParams)
        .toList();

    if (processorsWithPerImageParams.isEmpty) {
      return _buildEmptyState(theme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标题栏
        _buildHeader(theme),
        const SizedBox(height: 12),
        // 处理器列表
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final processor in processorsWithPerImageParams)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildProcessorSection(theme, processor),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(FluentThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.processing,
            size: 32,
            color: theme.resources.textFillColorTertiary,
          ),
          const SizedBox(height: 8),
          Text(
            '当前 Pipeline 没有\n支持单图微调的参数',
            style: theme.typography.body?.copyWith(
              color: theme.resources.textFillColorTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(FluentThemeData theme) {
    final hasOverrides = widget.currentOverrides.isNotEmpty;

    return Row(
      children: [
        Icon(
          FluentIcons.single_column_edit,
          size: 16,
          color: theme.accentColor,
        ),
        const SizedBox(width: 8),
        Text('单图参数微调', style: theme.typography.bodyStrong),
        const Spacer(),
        if (hasOverrides)
          Tooltip(
            message: '清除所有覆盖',
            child: IconButton(
              icon: const Icon(FluentIcons.clear, size: 14),
              onPressed: widget.onClearAll,
            ),
          ),
      ],
    );
  }

  /// 构建处理器区域
  Widget _buildProcessorSection(
    FluentThemeData theme,
    ImageProcessor processor,
  ) {
    final perImageParams = processor.perImageParams;
    final overrides = widget.currentOverrides[processor.instanceId];

    return Container(
      decoration: BoxDecoration(
        color: theme.micaBackgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 处理器标题
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.resources.cardBackgroundFillColorDefault,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    processor.displayName,
                    style: theme.typography.bodyStrong,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (overrides != null && overrides.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${overrides.toMap().length} 项覆盖',
                      style: theme.typography.caption?.copyWith(
                        color: theme.accentColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 参数列表
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final param in perImageParams)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildParamRow(theme, processor, param, overrides),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建参数行
  Widget _buildParamRow(
    FluentThemeData theme,
    ImageProcessor processor,
    ProcessorParamDef param,
    ProcessorParams? overrides,
  ) {
    // 判断是否有覆盖
    final isOverridden = overrides?.has(param.id) ?? false;
    // 获取当前值（覆盖值或全局值）
    final currentValue = isOverridden
        ? overrides!.get(param.id)
        : processor.globalParams.get(param.id) ?? param.defaultValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 参数标签和覆盖开关
        Row(
          children: [
            Checkbox(
              checked: isOverridden,
              onChanged: (value) {
                if (value == true) {
                  // 启用覆盖，使用当前全局值作为初始值
                  final globalValue =
                      processor.globalParams.get(param.id) ??
                      param.defaultValue;
                  widget.onOverrideChanged?.call(
                    processor.instanceId,
                    param.id,
                    globalValue,
                    true,
                  );
                } else {
                  // 取消覆盖
                  widget.onOverrideRemoved?.call(
                    processor.instanceId,
                    param.id,
                  );
                }
              },
              content: Text(
                param.displayName,
                style: theme.typography.body?.copyWith(
                  color: isOverridden
                      ? theme.resources.textFillColorPrimary
                      : theme.resources.textFillColorSecondary,
                ),
              ),
            ),
            if (isOverridden) ...[
              const SizedBox(width: 4),
              Icon(FluentIcons.edit, size: 12, color: theme.accentColor),
            ],
          ],
        ),
        // 参数输入（仅当覆盖启用时）
        if (isOverridden) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: _buildParamInput(theme, processor, param, currentValue),
          ),
        ],
        // 参数说明
        if (param.description.isNotEmpty && isOverridden) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              param.description,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorTertiary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 构建参数输入控件
  Widget _buildParamInput(
    FluentThemeData theme,
    ImageProcessor processor,
    ProcessorParamDef def,
    dynamic currentValue,
  ) {
    switch (def.type) {
      case ParamType.integer:
        return SizedBox(
          width: double.infinity,
          child: NumberBox<int>(
            value: currentValue as int?,
            min: def.minValue?.toInt(),
            max: def.maxValue?.toInt(),
            onChanged: (value) {
              if (value != null) {
                widget.onOverrideChanged?.call(
                  processor.instanceId,
                  def.id,
                  value,
                  true,
                );
              }
            },
          ),
        );

      case ParamType.double_:
        return SizedBox(
          width: double.infinity,
          child: NumberBox<double>(
            value: (currentValue as num?)?.toDouble(),
            min: def.minValue?.toDouble(),
            max: def.maxValue?.toDouble(),
            smallChange: 0.1,
            onChanged: (value) {
              if (value != null) {
                widget.onOverrideChanged?.call(
                  processor.instanceId,
                  def.id,
                  value,
                  true,
                );
              }
            },
          ),
        );

      case ParamType.boolean:
        return ToggleSwitch(
          checked: currentValue as bool? ?? false,
          onChanged: (value) {
            widget.onOverrideChanged?.call(
              processor.instanceId,
              def.id,
              value,
              true,
            );
          },
        );

      case ParamType.string:
        return TextBox(
          placeholder: '输入文本...',
          onChanged: (value) {
            widget.onOverrideChanged?.call(
              processor.instanceId,
              def.id,
              value,
              true,
            );
          },
        );

      case ParamType.color:
        final colorValue = currentValue as int? ?? 0xFFFFFFFF;
        return ColorPickerButton(
          value: colorValue,
          onChanged: (value) {
            widget.onOverrideChanged?.call(
              processor.instanceId,
              def.id,
              value,
              true,
            );
          },
        );

      case ParamType.enumChoice:
        return SizedBox(
          width: double.infinity,
          child: ComboBox<String>(
            value: currentValue as String?,
            items:
                def.enumOptions?.map((option) {
                  return ComboBoxItem<String>(
                    value: option,
                    child: Text(option),
                  );
                }).toList() ??
                [],
            onChanged: (value) {
              if (value != null) {
                widget.onOverrideChanged?.call(
                  processor.instanceId,
                  def.id,
                  value,
                  true,
                );
              }
            },
          ),
        );
    }
  }
}

import 'package:fluent_ui/fluent_ui.dart';

import '../processors/processors.dart';
import 'color_picker_button.dart';

/// 处理器步骤编辑器
///
/// 用于编辑单个处理器的名称和参数。
class ProcessorStepEditor extends StatefulWidget {
  /// 处理器实例
  final ImageProcessor processor;

  /// 名称变更回调
  final ValueChanged<String>? onNameChanged;

  /// 参数变更回调
  final void Function(String paramId, dynamic value)? onParamChanged;

  /// 重置参数回调
  final VoidCallback? onReset;

  const ProcessorStepEditor({
    super.key,
    required this.processor,
    this.onNameChanged,
    this.onParamChanged,
    this.onReset,
  });

  @override
  State<ProcessorStepEditor> createState() => _ProcessorStepEditorState();
}

class _ProcessorStepEditorState extends State<ProcessorStepEditor> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.processor.customName);
  }

  @override
  void didUpdateWidget(covariant ProcessorStepEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.processor.instanceId != widget.processor.instanceId) {
      _nameController.text = widget.processor.customName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final processor = widget.processor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 处理器类型标题
          _buildHeader(theme, processor),
          const SizedBox(height: 16),
          // 名称编辑
          _buildNameField(theme),
          const SizedBox(height: 16),
          // 参数列表
          _buildParamSection(theme, processor),
          const SizedBox(height: 16),
          // 重置按钮
          _buildResetButton(theme),
        ],
      ),
    );
  }

  /// 构建标题
  Widget _buildHeader(FluentThemeData theme, ImageProcessor processor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                processor.type.displayName,
                style: theme.typography.bodyStrong?.copyWith(
                  color: theme.accentColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (!processor.enabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x33808080), // grey with 0.2 opacity
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '已禁用',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          processor.description,
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
        ),
      ],
    );
  }

  /// 构建名称编辑字段
  Widget _buildNameField(FluentThemeData theme) {
    return InfoLabel(
      label: '显示名称',
      child: TextBox(
        controller: _nameController,
        placeholder: '输入自定义名称...',
        onChanged: (value) {
          widget.onNameChanged?.call(value);
        },
      ),
    );
  }

  /// 构建参数区域
  Widget _buildParamSection(FluentThemeData theme, ImageProcessor processor) {
    final paramDefs = processor.paramDefinitions;

    if (paramDefs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.micaBackgroundColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.resources.dividerStrokeColorDefault),
        ),
        child: Column(
          children: [
            Icon(
              FluentIcons.info,
              size: 24,
              color: theme.resources.textFillColorSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              '此处理器没有可配置参数',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('参数设置', style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        ...paramDefs.map(
          (def) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildParamEditor(theme, processor, def),
          ),
        ),
      ],
    );
  }

  /// 构建单个参数编辑器
  Widget _buildParamEditor(
    FluentThemeData theme,
    ImageProcessor processor,
    ProcessorParamDef def,
  ) {
    final currentValue = processor.globalParams.get(def.id) ?? def.defaultValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildParamLabel(theme, def),
        const SizedBox(height: 4),
        _buildParamInput(theme, def, currentValue),
        // 显示参数说明
        if (def.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            def.description,
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ],
    );
  }

  /// 构建参数标签
  Widget _buildParamLabel(FluentThemeData theme, ProcessorParamDef def) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(def.displayName),
        if (def.supportsPerImageOverride) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: '此参数支持单图覆盖',
            child: Icon(
              FluentIcons.single_column_edit,
              size: 12,
              color: theme.accentColor,
            ),
          ),
        ],
      ],
    );
  }

  /// 构建参数输入控件
  Widget _buildParamInput(
    FluentThemeData theme,
    ProcessorParamDef def,
    dynamic currentValue,
  ) {
    switch (def.type) {
      case ParamType.integer:
        return NumberBox<int>(
          value: currentValue as int?,
          min: def.minValue?.toInt(),
          max: def.maxValue?.toInt(),
          onChanged: (value) {
            if (value != null) {
              widget.onParamChanged?.call(def.id, value);
            }
          },
        );

      case ParamType.double_:
        return NumberBox<double>(
          value: (currentValue as num?)?.toDouble(),
          min: def.minValue?.toDouble(),
          max: def.maxValue?.toDouble(),
          smallChange: 0.1,
          onChanged: (value) {
            if (value != null) {
              widget.onParamChanged?.call(def.id, value);
            }
          },
        );

      case ParamType.boolean:
        return ToggleSwitch(
          checked: currentValue as bool? ?? false,
          onChanged: (value) {
            widget.onParamChanged?.call(def.id, value);
          },
        );

      case ParamType.string:
        return TextBox(
          placeholder: '输入文本...',
          onChanged: (value) {
            widget.onParamChanged?.call(def.id, value);
          },
        );

      case ParamType.color:
        // 使用颜色选择器
        final colorValue = currentValue as int? ?? 0xFFFFFFFF;
        return ColorPickerButton(
          value: colorValue,
          onChanged: (value) {
            widget.onParamChanged?.call(def.id, value);
          },
        );

      case ParamType.enumChoice:
        return ComboBox<String>(
          value: currentValue as String?,
          items:
              def.enumOptions?.map((option) {
                return ComboBoxItem<String>(value: option, child: Text(option));
              }).toList() ??
              [],
          onChanged: (value) {
            if (value != null) {
              widget.onParamChanged?.call(def.id, value);
            }
          },
        );
    }
  }

  /// 构建重置按钮
  Widget _buildResetButton(FluentThemeData theme) {
    return Button(
      onPressed: widget.onReset,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.refresh, size: 14),
          SizedBox(width: 6),
          Text('重置为默认'),
        ],
      ),
    );
  }
}

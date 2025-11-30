import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../models/margins.dart';
import '../providers/editor_provider.dart';

/// 边距输入组件
/// 提供四个方向的边距输入框，支持实时预览
class MarginsInput extends StatefulWidget {
  const MarginsInput({super.key});

  @override
  State<MarginsInput> createState() => _MarginsInputState();
}

class _MarginsInputState extends State<MarginsInput> {
  late TextEditingController _topController;
  late TextEditingController _bottomController;
  late TextEditingController _leftController;
  late TextEditingController _rightController;

  bool _isExpanded = false;

  // 记录上次同步的边距值，用于检测 Provider 变化
  ImageMargins? _lastSyncedMargins;

  @override
  void initState() {
    super.initState();
    _topController = TextEditingController(text: '0');
    _bottomController = TextEditingController(text: '0');
    _leftController = TextEditingController(text: '0');
    _rightController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _topController.dispose();
    _bottomController.dispose();
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  /// 从 Provider 同步边距值到输入框
  void _syncFromProvider(EditorProvider provider) {
    final margins = provider.margins;
    _topController.text = margins.top.toStringAsFixed(0);
    _bottomController.text = margins.bottom.toStringAsFixed(0);
    _leftController.text = margins.left.toStringAsFixed(0);
    _rightController.text = margins.right.toStringAsFixed(0);
  }

  /// 解析输入值
  double _parseValue(String text) {
    return double.tryParse(text) ?? 0;
  }

  /// 应用单个边距变化
  void _applyMarginChange(
    EditorProvider provider,
    String direction,
    String value,
  ) {
    final doubleValue = _parseValue(value);
    switch (direction) {
      case 'top':
        provider.setMarginTop(doubleValue);
        break;
      case 'bottom':
        provider.setMarginBottom(doubleValue);
        break;
      case 'left':
        provider.setMarginLeft(doubleValue);
        break;
      case 'right':
        provider.setMarginRight(doubleValue);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final provider = context.watch<EditorProvider>();
    final hasImage = provider.imageFile != null;
    final margins = provider.margins;

    // 检测 Provider 中的边距是否发生变化（由外部修改，如智能检测）
    // 如果变化了，同步到输入框
    if (_lastSyncedMargins != margins) {
      _lastSyncedMargins = margins;
      // 使用 addPostFrameCallback 避免在 build 中直接修改状态
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _topController.text = margins.top.toStringAsFixed(0);
          _bottomController.text = margins.bottom.toStringAsFixed(0);
          _leftController.text = margins.left.toStringAsFixed(0);
          _rightController.text = margins.right.toStringAsFixed(0);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 折叠标题
        GestureDetector(
          onTap: hasImage
              ? () => setState(() => _isExpanded = !_isExpanded)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.transparent,
            child: Row(
              children: [
                Icon(
                  _isExpanded
                      ? FluentIcons.chevron_down
                      : FluentIcons.chevron_right,
                  size: 12,
                  color: hasImage
                      ? null
                      : theme.resources.textFillColorDisabled,
                ),
                const SizedBox(width: 8),
                Text(
                  '边距',
                  style: theme.typography.body?.copyWith(
                    color: hasImage
                        ? null
                        : theme.resources.textFillColorDisabled,
                  ),
                ),
                const Spacer(),
                if (!margins.isZero)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '已设置',
                      style: theme.typography.caption?.copyWith(
                        color: theme.accentColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // 展开内容
        if (_isExpanded && hasImage) ...[
          const SizedBox(height: 8),
          _buildMarginsEditor(theme, provider),
        ],
      ],
    );
  }

  /// 构建边距编辑器
  Widget _buildMarginsEditor(FluentThemeData theme, EditorProvider provider) {
    final imageSize = provider.imageSize;
    final effectiveSize = provider.effectiveSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 可视化布局（类似 CSS box model）
        _buildVisualLayout(theme, provider),
        const SizedBox(height: 12),
        // 有效区域信息
        if (imageSize != null && effectiveSize != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.micaBackgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '有效区域',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${effectiveSize.width.toStringAsFixed(0)} × ${effectiveSize.height.toStringAsFixed(0)} px',
                  style: theme.typography.body,
                ),
                Text(
                  '原图: ${imageSize.width.toStringAsFixed(0)} × ${imageSize.height.toStringAsFixed(0)} px',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorTertiary,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        // 应用并重新切割按钮
        FilledButton(
          onPressed: () async {
            await provider.regenerateGrid();
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FluentIcons.grid_view_medium, size: 14),
              SizedBox(width: 6),
              Text('应用并重新切割'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 智能检测按钮
        Button(
          onPressed: () async {
            await provider.detectEdgesAndRegenerate();
            _syncFromProvider(provider);
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FluentIcons.auto_enhance_on, size: 14),
              SizedBox(width: 6),
              Text('智能检测边缘'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 重置按钮
        if (!provider.margins.isZero)
          Button(
            onPressed: () {
              provider.resetMargins();
              _syncFromProvider(provider);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.clear, size: 14),
                SizedBox(width: 6),
                Text('重置边距'),
              ],
            ),
          ),
      ],
    );
  }

  /// 构建可视化布局（类似 CSS box model 编辑器）
  Widget _buildVisualLayout(FluentThemeData theme, EditorProvider provider) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // 上边距
          _buildMarginInput(
            theme: theme,
            provider: provider,
            controller: _topController,
            direction: 'top',
            label: '上',
          ),
          const SizedBox(height: 4),
          // 中间行：左 + 有效区域 + 右
          Row(
            children: [
              // 左边距
              Expanded(
                child: _buildMarginInput(
                  theme: theme,
                  provider: provider,
                  controller: _leftController,
                  direction: 'left',
                  label: '左',
                ),
              ),
              // 有效区域指示
              Container(
                width: 60,
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.1),
                  border: Border.all(color: theme.accentColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    '有效',
                    style: theme.typography.caption?.copyWith(
                      color: theme.accentColor,
                    ),
                  ),
                ),
              ),
              // 右边距
              Expanded(
                child: _buildMarginInput(
                  theme: theme,
                  provider: provider,
                  controller: _rightController,
                  direction: 'right',
                  label: '右',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 下边距
          _buildMarginInput(
            theme: theme,
            provider: provider,
            controller: _bottomController,
            direction: 'bottom',
            label: '下',
          ),
        ],
      ),
    );
  }

  /// 构建单个边距输入
  Widget _buildMarginInput({
    required FluentThemeData theme,
    required EditorProvider provider,
    required TextEditingController controller,
    required String direction,
    required String label,
  }) {
    final imageSize = provider.imageSize;
    final maxValue = imageSize != null
        ? (direction == 'left' || direction == 'right'
              ? imageSize.width / 2
              : imageSize.height / 2)
        : 9999.0;

    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              label,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 70,
            child: NumberBox<double>(
              value: _parseValue(controller.text),
              min: 0,
              max: maxValue,
              mode: SpinButtonPlacementMode.none,
              smallChange: 1,
              largeChange: 10,
              onChanged: (value) {
                if (value != null) {
                  controller.text = value.toStringAsFixed(0);
                  _applyMarginChange(
                    provider,
                    direction,
                    value.toStringAsFixed(0),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

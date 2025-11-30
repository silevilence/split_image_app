import 'package:fluent_ui/fluent_ui.dart';

/// 可调整大小的垂直分割视图
///
/// 将两个子组件垂直分割，中间有一个可拖拽的分隔条。
/// 支持最小高度约束和比例持久化。
class ResizableSplitView extends StatefulWidget {
  const ResizableSplitView({
    super.key,
    required this.topChild,
    required this.bottomChild,
    this.initialRatio = 0.4,
    this.minTopHeight = 200,
    this.minBottomHeight = 200,
    this.onRatioChanged,
    this.dividerHeight = 6,
  });

  /// 上方子组件
  final Widget topChild;

  /// 下方子组件
  final Widget bottomChild;

  /// 初始分割比例 (0.0-1.0)，表示上方组件占总高度的比例
  final double initialRatio;

  /// 上方组件最小高度
  final double minTopHeight;

  /// 下方组件最小高度
  final double minBottomHeight;

  /// 比例变化回调，用于持久化
  final ValueChanged<double>? onRatioChanged;

  /// 分隔条高度
  final double dividerHeight;

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  late double _ratio;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio.clamp(0.1, 0.9);
  }

  @override
  void didUpdateWidget(ResizableSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果初始比例改变（如从配置加载），更新状态
    if (oldWidget.initialRatio != widget.initialRatio && !_isDragging) {
      _ratio = widget.initialRatio.clamp(0.1, 0.9);
    }
  }

  void _handleDragUpdate(DragUpdateDetails details, double totalHeight) {
    final availableHeight = totalHeight - widget.dividerHeight;

    // 计算新的分割位置
    final newTopHeight = (_ratio * availableHeight + details.delta.dy).clamp(
      widget.minTopHeight,
      availableHeight - widget.minBottomHeight,
    );

    final newRatio = newTopHeight / availableHeight;

    if (newRatio != _ratio) {
      setState(() {
        _ratio = newRatio;
      });
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    // 拖拽结束时通知外部保存比例
    widget.onRatioChanged?.call(_ratio);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final availableHeight = totalHeight - widget.dividerHeight;

        // 确保比例在有效范围内
        final minRatio = widget.minTopHeight / availableHeight;
        final maxRatio =
            (availableHeight - widget.minBottomHeight) / availableHeight;
        final effectiveRatio = _ratio.clamp(minRatio, maxRatio);

        final topHeight = availableHeight * effectiveRatio;
        final bottomHeight = availableHeight - topHeight;

        return Column(
          children: [
            // 上方区域（设置区）
            SizedBox(height: topHeight, child: widget.topChild),
            // 分隔条
            _buildDivider(theme, totalHeight),
            // 下方区域（预览区）
            SizedBox(height: bottomHeight, child: widget.bottomChild),
          ],
        );
      },
    );
  }

  /// 构建可拖拽的分隔条
  Widget _buildDivider(FluentThemeData theme, double totalHeight) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        onVerticalDragStart: (_) => setState(() => _isDragging = true),
        onVerticalDragUpdate: (details) =>
            _handleDragUpdate(details, totalHeight),
        onVerticalDragEnd: _handleDragEnd,
        child: Container(
          height: widget.dividerHeight,
          color: _isDragging
              ? theme.accentColor.withValues(alpha: 0.3)
              : Colors.transparent,
          child: Center(
            child: Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: _isDragging
                    ? theme.accentColor
                    : theme.resources.dividerStrokeColorDefault,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

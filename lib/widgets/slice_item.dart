import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';

import '../models/slice_preview.dart';

/// 单个切片项组件 - 列表样式
class SliceItem extends StatefulWidget {
  final SlicePreview slice;
  final bool isSelected;
  final ValueChanged<bool>? onSelectionToggle; // 点击切换选中（会触发拖拽模式）
  final void Function(bool value, {bool startDrag})? onSelectionChanged; // 更精细的选择控制
  final ValueChanged<String>? onSuffixChanged;
  final VoidCallback? onPreviewRequested; // 请求预览大图

  const SliceItem({
    super.key,
    required this.slice,
    required this.isSelected,
    this.onSelectionToggle,
    this.onSelectionChanged,
    this.onSuffixChanged,
    this.onPreviewRequested,
  });

  @override
  State<SliceItem> createState() => _SliceItemState();
}

class _SliceItemState extends State<SliceItem> {
  // 静态变量：全局跟踪是否有右键菜单打开
  static bool _anyContextMenuOpen = false;
  
  late TextEditingController _suffixController;
  bool _isEditing = false;
  final FocusNode _focusNode = FocusNode();
  final _contextMenuController = FlyoutController();
  final _contextMenuAttachKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _suffixController = TextEditingController(text: widget.slice.customSuffix);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(SliceItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当切片数据变化时更新控制器（但不在编辑中时）
    if (!_isEditing && widget.slice.customSuffix != _suffixController.text) {
      _suffixController.text = widget.slice.customSuffix;
    }
  }

  @override
  void dispose() {
    _suffixController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _contextMenuController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      // 失去焦点时保存
      _saveChanges();
    }
  }

  void _saveChanges() {
    setState(() => _isEditing = false);
    final newSuffix = _suffixController.text.trim();
    if (newSuffix.isNotEmpty && newSuffix != widget.slice.customSuffix) {
      widget.onSuffixChanged?.call(newSuffix);
    } else if (newSuffix.isEmpty) {
      // 如果为空，恢复默认值
      _suffixController.text = widget.slice.customSuffix;
    }
  }

  void _showContextMenu(Offset position) {
    _anyContextMenuOpen = true;
    _contextMenuController.showFlyout(
      position: position,
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      builder: (context) => MenuFlyout(
        items: [
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.full_screen),
            text: const Text('查看大图'),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onPreviewRequested?.call();
            },
          ),
          const MenuFlyoutSeparator(),
          MenuFlyoutItem(
            leading: Icon(
              widget.isSelected ? FluentIcons.checkbox_fill : FluentIcons.checkbox,
            ),
            text: Text(widget.isSelected ? '取消导出' : '选择导出'),
            onPressed: () {
              Navigator.of(context).pop();
              // 从菜单切换，不触发拖拽模式
              if (widget.onSelectionChanged != null) {
                widget.onSelectionChanged!(!widget.isSelected, startDrag: false);
              } else {
                widget.onSelectionToggle?.call(!widget.isSelected);
              }
            },
          ),
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.edit),
            text: const Text('编辑后缀'),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _isEditing = true);
              Future.microtask(() => _focusNode.requestFocus());
            },
          ),
        ],
      ),
    ).then((_) {
      // 菜单关闭后延迟重置状态，避免关闭时的点击被当作选择
      Future.delayed(const Duration(milliseconds: 150), () {
        _anyContextMenuOpen = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return FlyoutTarget(
      key: _contextMenuAttachKey,
      controller: _contextMenuController,
      child: GestureDetector(
        onSecondaryTapUp: (details) {
          _showContextMenu(details.globalPosition);
        },
        onDoubleTap: widget.onPreviewRequested,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? theme.accentColor.withValues(alpha: 0.1)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: widget.isSelected
                  ? theme.accentColor
                  : theme.resources.dividerStrokeColorDefault,
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // 左侧可选中区域：勾选框 + 缩略图（按下立即切换选中）
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    // 只响应左键，且没有任何右键菜单打开时
                    if (event.buttons == kPrimaryButton && !_anyContextMenuOpen) {
                      // 直接点击，触发拖拽模式
                      if (widget.onSelectionChanged != null) {
                        widget.onSelectionChanged!(!widget.isSelected, startDrag: true);
                      } else {
                        widget.onSelectionToggle?.call(!widget.isSelected);
                      }
                    }
                  },
                  child: Row(
                    children: [
                      // 勾选框
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: IgnorePointer(
                          child: Checkbox(
                            checked: widget.isSelected,
                            onChanged: null,
                          ),
                        ),
                      ),
                      // 缩略图
                      Tooltip(
                        message: '双击查看大图',
                        child: Container(
                          width: 56,
                          height: 56,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.micaBackgroundColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: theme.resources.dividerStrokeColorDefault,
                              width: 0.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Image.memory(
                              widget.slice.thumbnailBytes,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 右侧：信息（点击不改变选中状态）
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 可编辑的后缀名
                    SizedBox(
                      height: 28,
                      child: _isEditing
                          ? TextBox(
                              controller: _suffixController,
                              focusNode: _focusNode,
                              style: theme.typography.body?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              onSubmitted: (_) => _saveChanges(),
                            )
                          : GestureDetector(
                              onTap: () {
                                setState(() => _isEditing = true);
                                // 延迟请求焦点，确保 TextBox 已经构建
                                Future.microtask(() => _focusNode.requestFocus());
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.transparent),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.slice.customSuffix,
                                        style: theme.typography.body?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      FluentIcons.edit,
                                      size: 12,
                                      color: theme.resources.textFillColorTertiary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    // 尺寸信息
                    Text(
                      '${widget.slice.width.toInt()} × ${widget.slice.height.toInt()} px',
                      style: theme.typography.caption?.copyWith(
                        color: theme.resources.textFillColorSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 预览按钮
              Tooltip(
                message: '查看大图',
                child: IconButton(
                  icon: Icon(
                    FluentIcons.full_screen,
                    size: 16,
                    color: theme.resources.textFillColorSecondary,
                  ),
                  onPressed: widget.onPreviewRequested,
                ),
              ),
              // 右侧边距
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

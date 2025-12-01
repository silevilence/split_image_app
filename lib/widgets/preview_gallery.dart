import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import '../providers/editor_provider.dart';
import '../providers/preview_provider.dart';
import 'preview_modal.dart';
import 'slice_item.dart';

/// 预览画廊组件
/// 显示所有切片的缩略图，支持选择操作
class PreviewGallery extends StatefulWidget {
  const PreviewGallery({super.key});

  @override
  State<PreviewGallery> createState() => _PreviewGalleryState();
}

class _PreviewGalleryState extends State<PreviewGallery> {
  // 用于连续勾选的状态
  bool _isDragging = false;
  bool? _dragSelectValue; // 拖拽时要设置的选中状态
  int? _dragStartIndex; // 拖拽起始索引
  int? _lastDragIndex; // 上次拖拽经过的索引
  
  // 滚动控制器和自动滚动
  final ScrollController _scrollController = ScrollController();
  double? _dragPointerY; // 当前拖拽指针的 Y 坐标
  double? _listTop; // 列表顶部位置
  double? _listBottom; // 列表底部位置
  static const double _scrollEdgeThreshold = 50.0; // 边缘触发滚动的距离
  static const double _scrollSpeed = 8.0; // 滚动速度

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 打开预览模态框
  void _openPreviewModal(BuildContext context, int index) {
    final previewProvider = context.read<PreviewProvider>();
    final editorProvider = context.read<EditorProvider>();

    PreviewModal.show(
      context: context,
      slices: previewProvider.slices,
      initialIndex: index,
      sourceImageFile: editorProvider.imageFile,
      onSelectionChanged: (idx, isSelected) {
        previewProvider.setSliceSelection(idx, isSelected);
      },
      onSuffixChanged: (idx, suffix) {
        previewProvider.updateSliceSuffix(idx, suffix);
      },
    );
  }

  /// 处理拖拽时的自动滚动
  void _handleAutoScroll() {
    if (!_isDragging || _dragPointerY == null || _listTop == null || _listBottom == null) {
      return;
    }

    final distanceFromTop = _dragPointerY! - _listTop!;
    final distanceFromBottom = _listBottom! - _dragPointerY!;

    double scrollDelta = 0;

    if (distanceFromTop < _scrollEdgeThreshold && distanceFromTop >= 0) {
      // 靠近顶部，向上滚动
      scrollDelta = -_scrollSpeed * (1 - distanceFromTop / _scrollEdgeThreshold);
    } else if (distanceFromBottom < _scrollEdgeThreshold && distanceFromBottom >= 0) {
      // 靠近底部，向下滚动
      scrollDelta = _scrollSpeed * (1 - distanceFromBottom / _scrollEdgeThreshold);
    }

    if (scrollDelta != 0 && _scrollController.hasClients) {
      final newOffset = (_scrollController.offset + scrollDelta)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(newOffset);
      
      // 持续滚动
      if (_isDragging) {
        Future.delayed(const Duration(milliseconds: 16), _handleAutoScroll);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PreviewProvider>();
    final theme = FluentTheme.of(context);

    // 生成中状态
    if (provider.isGenerating) {
      return _buildGeneratingState(theme, provider);
    }

    // 错误状态
    if (provider.errorMessage != null) {
      return _buildErrorState(theme, provider);
    }

    // 无数据状态
    if (!provider.hasPreview) {
      return _buildEmptyState(theme);
    }

    // 正常显示画廊
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 选择操作栏
        _buildSelectionBar(theme, provider),
        const SizedBox(height: 8),
        // 切片网格
        Expanded(
          child: _buildSliceGrid(provider),
        ),
      ],
    );
  }

  /// 生成中状态
  Widget _buildGeneratingState(FluentThemeData theme, PreviewProvider provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProgressRing(),
          const SizedBox(height: 16),
          Text(
            '正在生成预览...',
            style: theme.typography.body,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 200,
            child: ProgressBar(value: provider.progress * 100),
          ),
          const SizedBox(height: 4),
          Text(
            '${(provider.progress * 100).toStringAsFixed(0)}%',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 错误状态
  Widget _buildErrorState(FluentThemeData theme, PreviewProvider provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.error,
            size: 32,
            color: Colors.red,
          ),
          const SizedBox(height: 12),
          Text(
            provider.errorMessage!,
            style: theme.typography.body?.copyWith(
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Button(
            onPressed: provider.clearError,
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState(FluentThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.photo_collection,
            size: 32,
            color: theme.resources.textFillColorTertiary,
          ),
          const SizedBox(height: 8),
          Text(
            '点击"生成预览"查看切片',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorTertiary,
            ),
          ),
        ],
      ),
    );
  }

  /// 选择操作栏
  Widget _buildSelectionBar(FluentThemeData theme, PreviewProvider provider) {
    return Row(
      children: [
        // 选择统计
        Text(
          '已选 ${provider.selectedCount}/${provider.totalCount}',
          style: theme.typography.caption,
        ),
        const Spacer(),
        // 全选按钮
        Button(
          onPressed: provider.isAllSelected ? null : provider.selectAll,
          child: const Text('全选'),
        ),
        const SizedBox(width: 4),
        // 全不选按钮
        Button(
          onPressed: provider.isNoneSelected ? null : provider.selectNone,
          child: const Text('全不选'),
        ),
        const SizedBox(width: 4),
        // 反选按钮
        Button(
          onPressed: provider.invertSelection,
          child: const Text('反选'),
        ),
      ],
    );
  }

  /// 切片列表
  Widget _buildSliceGrid(PreviewProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerDown: (event) {
            // 只响应左键
            if (event.buttons != kPrimaryButton) return;
            // 记录列表区域位置
            final RenderBox box = context.findRenderObject() as RenderBox;
            final position = box.localToGlobal(Offset.zero);
            _listTop = position.dy;
            _listBottom = position.dy + constraints.maxHeight;
          },
          onPointerMove: (event) {
            if (_isDragging) {
              _dragPointerY = event.position.dy;
              _handleAutoScroll();
            }
          },
          onPointerUp: (_) {
            // 拖拽结束
            _isDragging = false;
            _dragSelectValue = null;
            _dragStartIndex = null;
            _lastDragIndex = null;
            _dragPointerY = null;
          },
          // 当指针离开窗口或被取消时也要重置拖拽状态
          onPointerCancel: (_) {
            _isDragging = false;
            _dragSelectValue = null;
            _dragStartIndex = null;
            _lastDragIndex = null;
            _dragPointerY = null;
          },
          child: ListView.separated(
            controller: _scrollController,
            itemCount: provider.slices.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final slice = provider.slices[index];
              return MouseRegion(
                onEnter: (_) {
                  // 只有在按住鼠标拖拽时才触发连续选中
                  if (_isDragging && _dragSelectValue != null && _dragStartIndex != null) {
                    if (_lastDragIndex != index) {
                      _lastDragIndex = index;
                      // 计算起止范围，设置范围内所有项
                      final start = _dragStartIndex! < index ? _dragStartIndex! : index;
                      final end = _dragStartIndex! > index ? _dragStartIndex! : index;
                      for (int i = start; i <= end; i++) {
                        provider.setSliceSelection(i, _dragSelectValue!);
                      }
                    }
                  }
                },
                child: SliceItem(
                  slice: slice,
                  isSelected: slice.isSelected,
                  onSelectionChanged: (newValue, {bool startDrag = true}) {
                    // 切换选中状态
                    provider.setSliceSelection(index, newValue);
                    // 只有直接点击才开始拖拽模式
                    if (startDrag) {
                      _isDragging = true;
                      _dragSelectValue = newValue;
                      _dragStartIndex = index;
                      _lastDragIndex = index;
                    }
                  },
                  onSuffixChanged: (suffix) {
                    provider.updateSliceSuffix(index, suffix);
                  },
                  onPreviewRequested: () {
                    // 打开预览前重置拖拽状态
                    _isDragging = false;
                    _openPreviewModal(context, index);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

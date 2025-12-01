import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../models/slice_preview.dart';

/// 预览模态框 - 显示切片大图
/// 支持左右导航、编辑后缀、切换导出状态
class PreviewModal extends StatefulWidget {
  /// 所有切片列表
  final List<SlicePreview> slices;

  /// 初始显示的切片索引
  final int initialIndex;

  /// 源图片文件（用于生成高清预览）
  final File? sourceImageFile;

  /// 切片选中状态变更回调
  final void Function(int index, bool isSelected)? onSelectionChanged;

  /// 后缀变更回调
  final void Function(int index, String suffix)? onSuffixChanged;

  const PreviewModal({
    super.key,
    required this.slices,
    required this.initialIndex,
    this.sourceImageFile,
    this.onSelectionChanged,
    this.onSuffixChanged,
  });

  /// 显示预览模态框
  static Future<void> show({
    required BuildContext context,
    required List<SlicePreview> slices,
    required int initialIndex,
    File? sourceImageFile,
    void Function(int index, bool isSelected)? onSelectionChanged,
    void Function(int index, String suffix)? onSuffixChanged,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PreviewModal(
        slices: slices,
        initialIndex: initialIndex,
        sourceImageFile: sourceImageFile,
        onSelectionChanged: onSelectionChanged,
        onSuffixChanged: onSuffixChanged,
      ),
    );
  }

  @override
  State<PreviewModal> createState() => _PreviewModalState();
}

class _PreviewModalState extends State<PreviewModal> {
  late int _currentIndex;
  late TextEditingController _suffixController;
  final FocusNode _dialogFocusNode = FocusNode();
  final FocusNode _suffixFocusNode = FocusNode();
  bool _isEditingSuffix = false;

  // 高清预览图缓存
  final Map<int, ui.Image> _highResCache = {};
  bool _isLoadingHighRes = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.slices.length - 1);
    _suffixController = TextEditingController(
      text: widget.slices[_currentIndex].customSuffix,
    );
    // 预加载当前图片的高清版本
    _loadHighResImage(_currentIndex);
  }

  @override
  void dispose() {
    _suffixController.dispose();
    _dialogFocusNode.dispose();
    _suffixFocusNode.dispose();
    // 释放高清图片缓存
    for (final image in _highResCache.values) {
      image.dispose();
    }
    super.dispose();
  }

  SlicePreview get _currentSlice => widget.slices[_currentIndex];

  bool get _hasPrevious => _currentIndex > 0;
  bool get _hasNext => _currentIndex < widget.slices.length - 1;

  void _goToPrevious() {
    if (_hasPrevious) {
      _saveSuffixIfNeeded();
      setState(() {
        _currentIndex--;
        _suffixController.text = _currentSlice.customSuffix;
      });
      _loadHighResImage(_currentIndex);
    }
  }

  void _goToNext() {
    if (_hasNext) {
      _saveSuffixIfNeeded();
      setState(() {
        _currentIndex++;
        _suffixController.text = _currentSlice.customSuffix;
      });
      _loadHighResImage(_currentIndex);
    }
  }

  void _saveSuffixIfNeeded() {
    final newSuffix = _suffixController.text.trim();
    if (newSuffix.isNotEmpty && newSuffix != _currentSlice.customSuffix) {
      widget.onSuffixChanged?.call(_currentIndex, newSuffix);
    }
  }

  void _toggleExport() {
    final newValue = !_currentSlice.isSelected;
    widget.onSelectionChanged?.call(_currentIndex, newValue);
    setState(() {});
  }

  /// 加载高清预览图
  Future<void> _loadHighResImage(int index) async {
    if (_highResCache.containsKey(index) || widget.sourceImageFile == null) {
      return;
    }

    setState(() => _isLoadingHighRes = true);

    try {
      final bytes = await widget.sourceImageFile!.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final sourceImage = frame.image;

      // 裁剪指定区域
      final slice = widget.slices[index];
      final region = slice.region;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.drawImageRect(
        sourceImage,
        region,
        Rect.fromLTWH(0, 0, region.width, region.height),
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(
        region.width.toInt(),
        region.height.toInt(),
      );

      picture.dispose();
      sourceImage.dispose();

      if (mounted) {
        setState(() {
          _highResCache[index] = croppedImage;
          _isLoadingHighRes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHighRes = false);
      }
    }
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    // 如果正在编辑后缀，不处理快捷键
    if (_isEditingSuffix) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _goToPrevious();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _goToNext();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.space) {
        _toggleExport();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final screenSize = MediaQuery.of(context).size;

    // 计算对话框尺寸 (屏幕的 80%)
    final dialogWidth = screenSize.width * 0.8;
    final dialogHeight = screenSize.height * 0.85;

    return Focus(
      focusNode: _dialogFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(event),
      child: ContentDialog(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogHeight,
        ),
        content: Column(
          children: [
            // 顶部标题栏
            _buildHeader(theme),
            const SizedBox(height: 12),
            // 图片预览区
            Expanded(
              child: _buildImagePreview(theme),
            ),
            const SizedBox(height: 12),
            // 底部控制栏
            _buildControls(theme),
          ],
        ),
      ),
    );
  }

  /// 构建顶部标题栏
  Widget _buildHeader(FluentThemeData theme) {
    return Row(
      children: [
        // 标题：切片位置
        Text(
          '切片预览 (${_currentIndex + 1}/${widget.slices.length})',
          style: theme.typography.subtitle,
        ),
        const Spacer(),
        // 尺寸信息
        Text(
          '${_currentSlice.width.toInt()} × ${_currentSlice.height.toInt()} px',
          style: theme.typography.body?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        const SizedBox(width: 16),
        // 关闭按钮
        IconButton(
          icon: const Icon(FluentIcons.chrome_close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// 构建图片预览区
  Widget _buildImagePreview(FluentThemeData theme) {
    return Stack(
      children: [
        // 图片容器
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: theme.micaBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.resources.dividerStrokeColorDefault,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: _buildImage(),
            ),
          ),
        ),
        // 左侧导航按钮
        if (_hasPrevious)
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildNavButton(
                icon: FluentIcons.chevron_left,
                onPressed: _goToPrevious,
                tooltip: '上一张 (←)',
              ),
            ),
          ),
        // 右侧导航按钮
        if (_hasNext)
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildNavButton(
                icon: FluentIcons.chevron_right,
                onPressed: _goToNext,
                tooltip: '下一张 (→)',
              ),
            ),
          ),
        // 加载指示器
        if (_isLoadingHighRes)
          const Positioned(
            top: 8,
            right: 8,
            child: ProgressRing(strokeWidth: 2),
          ),
      ],
    );
  }

  /// 构建图片
  Widget _buildImage() {
    // 优先使用高清缓存
    if (_highResCache.containsKey(_currentIndex)) {
      return RawImage(
        image: _highResCache[_currentIndex],
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }

    // 降级使用缩略图
    return Image.memory(
      _currentSlice.thumbnailBytes,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }

  /// 构建导航按钮
  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 24),
          onPressed: onPressed,
        ),
      ),
    );
  }

  /// 构建底部控制栏
  Widget _buildControls(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行：导出切换和后缀编辑
        Row(
          children: [
            // 导出切换
            Checkbox(
              checked: _currentSlice.isSelected,
              onChanged: (value) {
                if (value != null) {
                  widget.onSelectionChanged?.call(_currentIndex, value);
                  setState(() {});
                }
              },
              content: const Text('导出此切片'),
            ),
            const SizedBox(width: 24),
            // 后缀编辑
            Text(
              '文件后缀:',
              style: theme.typography.body,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: Focus(
                onFocusChange: (hasFocus) {
                  setState(() => _isEditingSuffix = hasFocus);
                  if (!hasFocus) {
                    _saveSuffixIfNeeded();
                  }
                },
                child: TextBox(
                  controller: _suffixController,
                  focusNode: _suffixFocusNode,
                  placeholder: _currentSlice.defaultSuffix,
                  onSubmitted: (_) {
                    _saveSuffixIfNeeded();
                    _suffixFocusNode.unfocus();
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 重置后缀按钮
            Tooltip(
              message: '重置为默认后缀',
              child: IconButton(
                icon: const Icon(FluentIcons.refresh),
                onPressed: () {
                  _suffixController.text = _currentSlice.defaultSuffix;
                  widget.onSuffixChanged?.call(_currentIndex, _currentSlice.defaultSuffix);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 第二行：快捷键提示
        Text(
          '← → 导航  |  Space 切换导出  |  Esc 关闭',
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorTertiary,
          ),
        ),
      ],
    );
  }
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/slice_preview.dart';
import '../processors/processors.dart';
import '../providers/pipeline_provider.dart';
import 'per_image_override_editor.dart';

/// 预览模态框 - 显示切片大图
/// 支持左右导航、编辑后缀、切换导出状态、单图参数微调
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

  /// 覆盖参数变更回调
  final void Function(
    int sliceIndex,
    String processorId,
    ProcessorParams params,
  )?
  onOverridesChanged;

  const PreviewModal({
    super.key,
    required this.slices,
    required this.initialIndex,
    this.sourceImageFile,
    this.onSelectionChanged,
    this.onSuffixChanged,
    this.onOverridesChanged,
  });

  /// 显示预览模态框
  static Future<void> show({
    required BuildContext context,
    required List<SlicePreview> slices,
    required int initialIndex,
    File? sourceImageFile,
    void Function(int index, bool isSelected)? onSelectionChanged,
    void Function(int index, String suffix)? onSuffixChanged,
    void Function(int sliceIndex, String processorId, ProcessorParams params)?
    onOverridesChanged,
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
        onOverridesChanged: onOverridesChanged,
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

  // Pipeline 面板展开状态
  bool _isPipelinePanelExpanded = true;

  // 处理后的预览图缓存
  final Map<int, ui.Image> _processedCache = {};
  bool _isProcessing = false;
  String? _processingError;

  // 本地覆盖参数副本（编辑中）
  late Map<String, ProcessorParams> _localOverrides;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.slices.length - 1);
    _suffixController = TextEditingController(
      text: widget.slices[_currentIndex].customSuffix,
    );
    // 初始化本地覆盖参数
    _localOverrides = Map.from(widget.slices[_currentIndex].processorOverrides);
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
    for (final image in _processedCache.values) {
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
      _saveOverridesIfNeeded();
      setState(() {
        _currentIndex--;
        _suffixController.text = _currentSlice.customSuffix;
        _localOverrides = Map.from(_currentSlice.processorOverrides);
        _processingError = null;
      });
      _loadHighResImage(_currentIndex);
    }
  }

  void _goToNext() {
    if (_hasNext) {
      _saveSuffixIfNeeded();
      _saveOverridesIfNeeded();
      setState(() {
        _currentIndex++;
        _suffixController.text = _currentSlice.customSuffix;
        _localOverrides = Map.from(_currentSlice.processorOverrides);
        _processingError = null;
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

  void _saveOverridesIfNeeded() {
    // 检查是否有变更
    final current = _currentSlice.processorOverrides;
    if (_localOverrides.length != current.length) {
      _notifyOverridesChanged();
      return;
    }
    for (final entry in _localOverrides.entries) {
      if (!current.containsKey(entry.key) ||
          current[entry.key] != entry.value) {
        _notifyOverridesChanged();
        return;
      }
    }
  }

  void _notifyOverridesChanged() {
    for (final entry in _localOverrides.entries) {
      widget.onOverridesChanged?.call(_currentIndex, entry.key, entry.value);
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

  /// 处理单图预览
  Future<void> _processCurrentImage() async {
    final pipelineProvider = context.read<PipelineProvider>();
    if (!pipelineProvider.hasProcessors) {
      return;
    }

    // 确保高清图已加载
    if (!_highResCache.containsKey(_currentIndex)) {
      await _loadHighResImage(_currentIndex);
    }

    final sourceImage = _highResCache[_currentIndex];
    if (sourceImage == null) {
      setState(() {
        _processingError = '无法加载源图片';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingError = null;
    });

    try {
      // 创建处理输入
      final input = await ProcessorInput.fromImage(
        sourceImage,
        sliceIndex: _currentIndex,
        row: _currentSlice.row,
        col: _currentSlice.col,
      );

      // 临时设置覆盖参数到 chain
      for (final entry in _localOverrides.entries) {
        pipelineProvider.chain.setSliceOverride(
          _currentIndex,
          entry.key,
          entry.value,
        );
      }

      // 执行处理
      final output = await pipelineProvider.chain.process(
        input,
        sliceIndex: _currentIndex,
      );

      // 转换为图片
      final processedImage = await output.toImage();

      // 清除旧的缓存
      _processedCache[_currentIndex]?.dispose();

      if (mounted) {
        setState(() {
          _processedCache[_currentIndex] = processedImage;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingError = '处理失败: $e';
        });
      }
    }
  }

  /// 更新本地覆盖参数
  void _updateLocalOverride(
    String processorId,
    String paramId,
    dynamic value,
    bool isOverridden,
  ) {
    setState(() {
      if (isOverridden) {
        final existing =
            _localOverrides[processorId] ?? const ProcessorParams();
        _localOverrides[processorId] = existing.copyWith(paramId, value);
      }
      // 清除处理后的缓存，因为参数已变更
      _processedCache[_currentIndex]?.dispose();
      _processedCache.remove(_currentIndex);
    });
  }

  /// 移除本地覆盖参数
  void _removeLocalOverride(String processorId, String paramId) {
    setState(() {
      final existing = _localOverrides[processorId];
      if (existing != null) {
        final updated = existing.remove(paramId);
        if (updated.isEmpty) {
          _localOverrides.remove(processorId);
        } else {
          _localOverrides[processorId] = updated;
        }
      }
      // 清除处理后的缓存
      _processedCache[_currentIndex]?.dispose();
      _processedCache.remove(_currentIndex);
    });
  }

  /// 清除所有本地覆盖
  void _clearAllLocalOverrides() {
    setState(() {
      _localOverrides.clear();
      // 清除处理后的缓存
      _processedCache[_currentIndex]?.dispose();
      _processedCache.remove(_currentIndex);
    });
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
        _saveSuffixIfNeeded();
        _saveOverridesIfNeeded();
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
    final pipelineProvider = context.watch<PipelineProvider>();

    // 计算对话框尺寸 (屏幕的 85%)
    final dialogWidth = screenSize.width * 0.85;
    final dialogHeight = screenSize.height * 0.88;

    // 判断是否显示 Pipeline 面板
    final showPipelinePanel =
        pipelineProvider.hasProcessors && _isPipelinePanelExpanded;
    // ignore: unused_local_variable
    final pipelinePanelWidth = showPipelinePanel ? 300.0 : 0.0;

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
            _buildHeader(theme, pipelineProvider),
            const SizedBox(height: 12),
            // 主内容区
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 左侧：图片预览区
                  Expanded(child: _buildImagePreview(theme)),
                  // 右侧：Pipeline 面板（可折叠）
                  if (pipelineProvider.hasProcessors) ...[
                    _buildPipelinePanelToggle(theme),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: showPipelinePanel ? 300.0 : 0.0,
                      child: showPipelinePanel
                          ? _buildPipelinePanel(theme, pipelineProvider)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
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
  Widget _buildHeader(
    FluentThemeData theme,
    PipelineProvider pipelineProvider,
  ) {
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
        // 覆盖参数指示
        if (_localOverrides.isNotEmpty) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FluentIcons.single_column_edit,
                  size: 12,
                  color: theme.accentColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '有单图覆盖',
                  style: theme.typography.caption?.copyWith(
                    color: theme.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(width: 16),
        // 关闭按钮
        IconButton(
          icon: const Icon(FluentIcons.chrome_close),
          onPressed: () {
            _saveSuffixIfNeeded();
            _saveOverridesIfNeeded();
            Navigator.of(context).pop();
          },
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
        // 加载/处理指示器
        if (_isLoadingHighRes || _isProcessing)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: ProgressRing(strokeWidth: 2),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isProcessing ? '处理中...' : '加载中...',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        // 处理后标识
        if (_processedCache.containsKey(_currentIndex) && !_isProcessing)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.completed, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    '已处理',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        // 错误提示
        if (_processingError != null)
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _processingError!,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  /// 构建图片
  Widget _buildImage() {
    // 优先使用处理后的缓存
    if (_processedCache.containsKey(_currentIndex)) {
      return RawImage(
        image: _processedCache[_currentIndex],
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }

    // 其次使用高清缓存
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

  /// 构建 Pipeline 面板折叠按钮
  Widget _buildPipelinePanelToggle(FluentThemeData theme) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isPipelinePanelExpanded = !_isPipelinePanelExpanded;
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 24,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: theme.resources.cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.resources.dividerStrokeColorDefault,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isPipelinePanelExpanded
                    ? FluentIcons.chevron_right
                    : FluentIcons.chevron_left,
                size: 12,
                color: theme.resources.textFillColorSecondary,
              ),
              const SizedBox(height: 4),
              RotatedBox(
                quarterTurns: 1,
                child: Text(
                  'Pipeline',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建 Pipeline 面板
  Widget _buildPipelinePanel(
    FluentThemeData theme,
    PipelineProvider pipelineProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        border: Border(
          left: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 面板内容
          Expanded(
            child: PerImageOverrideEditor(
              chain: pipelineProvider.chain,
              currentOverrides: _localOverrides,
              onOverrideChanged: _updateLocalOverride,
              onOverrideRemoved: _removeLocalOverride,
              onClearAll: _clearAllLocalOverrides,
            ),
          ),
          // 预览按钮
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: _isProcessing ? null : _processCurrentImage,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: ProgressRing(strokeWidth: 2),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(FluentIcons.play, size: 14),
                    ),
                  Text(_isProcessing ? '处理中...' : '预览处理效果'),
                ],
              ),
            ),
          ),
        ],
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
            Text('文件后缀:', style: theme.typography.body),
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
                  widget.onSuffixChanged?.call(
                    _currentIndex,
                    _currentSlice.defaultSuffix,
                  );
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

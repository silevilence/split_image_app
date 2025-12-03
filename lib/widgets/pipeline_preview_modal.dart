import 'dart:async';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../models/slice_preview.dart';
import '../processors/processor_io.dart';
import '../providers/editor_provider.dart';
import '../providers/pipeline_provider.dart';
import '../providers/preview_provider.dart';

/// Pipeline 预览弹窗
///
/// 显示所有切片应用 Pipeline 处理后的效果。
class PipelinePreviewModal extends StatefulWidget {
  const PipelinePreviewModal({super.key});

  /// 显示预览弹窗
  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const PipelinePreviewModal(),
    );
  }

  @override
  State<PipelinePreviewModal> createState() => _PipelinePreviewModalState();
}

class _PipelinePreviewModalState extends State<PipelinePreviewModal> {
  /// 处理后的图片数据列表
  List<_ProcessedSlice>? _processedSlices;

  /// 是否正在处理
  bool _isProcessing = true;

  /// 处理进度
  double _progress = 0.0;

  /// 当前处理的索引
  int _currentIndex = 0;

  /// 错误信息
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _processAllSlices();
  }

  @override
  void dispose() {
    // 清理处理后的图片内存
    if (_processedSlices != null) {
      for (final slice in _processedSlices!) {
        slice.processedImage?.dispose();
      }
    }
    super.dispose();
  }

  /// 处理所有切片
  Future<void> _processAllSlices() async {
    final editorProvider = context.read<EditorProvider>();
    final previewProvider = context.read<PreviewProvider>();
    final pipelineProvider = context.read<PipelineProvider>();

    if (editorProvider.imageFile == null) {
      setState(() {
        _isProcessing = false;
        _errorMessage = '未加载图片';
      });
      return;
    }

    if (previewProvider.slices.isEmpty) {
      setState(() {
        _isProcessing = false;
        _errorMessage = '未生成切片预览';
      });
      return;
    }

    if (!pipelineProvider.hasProcessors) {
      setState(() {
        _isProcessing = false;
        _errorMessage = '未配置处理器';
      });
      return;
    }

    try {
      // 读取源图片
      final bytes = await editorProvider.imageFile!.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final sourceImage = frame.image;

      final slices = previewProvider.slices;
      final processedSlices = <_ProcessedSlice>[];

      for (int i = 0; i < slices.length; i++) {
        final slice = slices[i];

        setState(() {
          _currentIndex = i;
          _progress = i / slices.length;
        });

        // 提取切片区域的像素数据
        final region = slice.region;
        final width = region.width.toInt();
        final height = region.height.toInt();

        // 使用 Canvas 裁剪切片
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);

        canvas.drawImageRect(
          sourceImage,
          region,
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          Paint(),
        );

        final picture = recorder.endRecording();
        final sliceImage = await picture.toImage(width, height);
        picture.dispose();

        // 转换为 RGBA 像素数据
        final byteData = await sliceImage.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        sliceImage.dispose();

        if (byteData == null) {
          processedSlices.add(
            _ProcessedSlice(
              slice: slice,
              processedImage: null,
              error: '无法读取像素数据',
            ),
          );
          continue;
        }

        // 创建 ProcessorInput
        final input = ProcessorInput(
          pixels: byteData.buffer.asUint8List(),
          width: width,
          height: height,
          sliceIndex: i,
          row: slice.row,
          col: slice.col,
        );

        // 执行处理
        final output = await pipelineProvider.processImage(
          input,
          sliceIndex: i,
        );

        // 将处理结果转换为 ui.Image
        ui.Image? processedImage;
        if (output.hasChanges || output.pixels.isNotEmpty) {
          final pixels = output.pixels.isNotEmpty
              ? output.pixels
              : input.pixels;
          final w = output.width > 0 ? output.width : input.width;
          final h = output.height > 0 ? output.height : input.height;

          processedImage = await _createImageFromPixels(pixels, w, h);
        }

        processedSlices.add(
          _ProcessedSlice(
            slice: slice,
            processedImage: processedImage,
            originalWidth: width,
            originalHeight: height,
            processedWidth: output.width > 0 ? output.width : width,
            processedHeight: output.height > 0 ? output.height : height,
          ),
        );
      }

      sourceImage.dispose();

      setState(() {
        _processedSlices = processedSlices;
        _isProcessing = false;
        _progress = 1.0;
      });

      // 标记更改已应用
      pipelineProvider.markChangesApplied();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = '处理失败: $e';
      });
    }
  }

  /// 从 RGBA 像素数据创建 ui.Image
  Future<ui.Image> _createImageFromPixels(
    Uint8List pixels,
    int width,
    int height,
  ) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.85,
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      title: Row(
        children: [
          Icon(FluentIcons.picture, color: theme.accentColor),
          const SizedBox(width: 8),
          const Text('处理效果预览'),
          const Spacer(),
          if (_processedSlices != null)
            Text(
              '${_processedSlices!.length} 张图片',
              style: theme.typography.caption,
            ),
        ],
      ),
      content: _buildContent(context, theme),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, FluentThemeData theme) {
    if (_isProcessing) {
      return _buildProcessingView(theme);
    }

    if (_errorMessage != null) {
      return _buildErrorView(theme);
    }

    if (_processedSlices == null || _processedSlices!.isEmpty) {
      return Center(child: Text('无可预览的图片', style: theme.typography.body));
    }

    return _buildGalleryView(theme);
  }

  Widget _buildProcessingView(FluentThemeData theme) {
    final sliceCount = context.read<PreviewProvider>().slices.length;
    return SizedBox(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ProgressRing(),
          const SizedBox(height: 16),
          Text('正在处理图片...', style: theme.typography.bodyStrong),
          const SizedBox(height: 8),
          Text(
            '${_currentIndex + 1} / $sliceCount',
            style: theme.typography.caption,
          ),
          const SizedBox(height: 16),
          SizedBox(width: 300, child: ProgressBar(value: _progress * 100)),
        ],
      ),
    );
  }

  Widget _buildErrorView(FluentThemeData theme) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: theme.typography.body?.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryView(FluentThemeData theme) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          childAspectRatio: 0.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _processedSlices!.length,
        itemBuilder: (context, index) {
          final processed = _processedSlices![index];
          return _ProcessedSliceItem(
            processed: processed,
            index: index,
            theme: theme,
          );
        },
      ),
    );
  }
}

/// 处理后的切片数据
class _ProcessedSlice {
  final SlicePreview slice;
  final ui.Image? processedImage;
  final String? error;
  final int originalWidth;
  final int originalHeight;
  final int processedWidth;
  final int processedHeight;

  _ProcessedSlice({
    required this.slice,
    required this.processedImage,
    this.error,
    this.originalWidth = 0,
    this.originalHeight = 0,
    this.processedWidth = 0,
    this.processedHeight = 0,
  });
}

/// 处理后的切片项组件
class _ProcessedSliceItem extends StatelessWidget {
  final _ProcessedSlice processed;
  final int index;
  final FluentThemeData theme;

  const _ProcessedSliceItem({
    required this.processed,
    required this.index,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 图片区域
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
              child: Container(
                color: _getCheckerboardColor(theme),
                child: _buildImageContent(),
              ),
            ),
          ),
          // 信息区域
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${processed.slice.row + 1}-${processed.slice.col + 1}',
                  style: theme.typography.bodyStrong,
                ),
                const SizedBox(height: 2),
                if (processed.error != null)
                  Text(
                    processed.error!,
                    style: theme.typography.caption?.copyWith(
                      color: Colors.red,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (processed.originalWidth != processed.processedWidth ||
                    processed.originalHeight != processed.processedHeight)
                  Text(
                    '${processed.originalWidth}×${processed.originalHeight} → '
                    '${processed.processedWidth}×${processed.processedHeight}',
                    style: theme.typography.caption?.copyWith(
                      color: theme.accentColor,
                    ),
                  )
                else
                  Text(
                    '${processed.processedWidth}×${processed.processedHeight}',
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    if (processed.error != null) {
      return Center(
        child: Icon(FluentIcons.error, size: 32, color: Colors.red),
      );
    }

    if (processed.processedImage != null) {
      return Center(
        child: RawImage(image: processed.processedImage, fit: BoxFit.contain),
      );
    }

    return Center(
      child: Image.memory(processed.slice.thumbnailBytes, fit: BoxFit.contain),
    );
  }

  Color _getCheckerboardColor(FluentThemeData theme) {
    // 简单的棋盘格背景色（用于显示透明区域）
    return theme.brightness == Brightness.dark
        ? const Color(0xFF2D2D2D)
        : const Color(0xFFE0E0E0);
  }
}

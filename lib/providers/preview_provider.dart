import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/margins.dart';
import '../models/slice_preview.dart';
import '../processors/processor_param.dart';

/// 预览系统状态管理
class PreviewProvider extends ChangeNotifier {
  /// 切片预览列表
  List<SlicePreview> _slices = [];
  List<SlicePreview> get slices => _slices;

  /// 是否正在生成预览
  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  /// 生成进度 (0.0 - 1.0)
  double _progress = 0.0;
  double get progress => _progress;

  /// 错误信息
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// 缩略图尺寸（最大边长）
  static const int thumbnailMaxSize = 120;

  /// 是否有预览数据
  bool get hasPreview => _slices.isNotEmpty;

  /// 选中的切片数量
  int get selectedCount => _slices.where((s) => s.isSelected).length;

  /// 总切片数量
  int get totalCount => _slices.length;

  /// 是否全部选中
  bool get isAllSelected =>
      _slices.isNotEmpty && _slices.every((s) => s.isSelected);

  /// 是否全部未选中
  bool get isNoneSelected =>
      _slices.isEmpty || _slices.every((s) => !s.isSelected);

  /// 生成预览切片
  /// [imageFile] 源图片文件
  /// [horizontalLines] 水平线位置列表（相对于整个图片的位置 0.0-1.0）
  /// [verticalLines] 垂直线位置列表（相对于整个图片的位置 0.0-1.0）
  /// [imageSize] 图片尺寸
  /// [margins] 边距设置（用于确定切片边界）
  Future<void> generatePreview({
    required File imageFile,
    required List<double> horizontalLines,
    required List<double> verticalLines,
    required Size imageSize,
    ImageMargins margins = ImageMargins.zero,
  }) async {
    _isGenerating = true;
    _progress = 0.0;
    _errorMessage = null;
    _slices = [];
    notifyListeners();

    try {
      // 读取源图片
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final sourceImage = frame.image;

      // 计算有效区域
      final effectiveRect = margins.getEffectiveRect(imageSize);

      // 计算所有切片区域
      final regions = _calculateSliceRegions(
        imageSize,
        horizontalLines,
        verticalLines,
        effectiveRect,
      );

      final totalSlices = regions.length;
      final newSlices = <SlicePreview>[];

      // 逐个生成缩略图
      for (int i = 0; i < regions.length; i++) {
        final regionInfo = regions[i];
        final thumbnailBytes = await _generateThumbnail(
          sourceImage,
          regionInfo['region'] as ui.Rect,
        );

        newSlices.add(
          SlicePreview(
            row: regionInfo['row'] as int,
            col: regionInfo['col'] as int,
            region: regionInfo['region'] as ui.Rect,
            thumbnailBytes: thumbnailBytes,
          ),
        );

        _progress = (i + 1) / totalSlices;
        notifyListeners();
      }

      sourceImage.dispose();
      _slices = newSlices;
      _isGenerating = false;
      notifyListeners();
    } catch (e) {
      _isGenerating = false;
      _errorMessage = '生成预览失败: $e';
      notifyListeners();
    }
  }

  /// 计算所有切片区域
  /// [effectiveRect] 有效区域（排除边距后的区域）
  List<Map<String, dynamic>> _calculateSliceRegions(
    Size imageSize,
    List<double> horizontalLines,
    List<double> verticalLines,
    Rect effectiveRect,
  ) {
    final regions = <Map<String, dynamic>>[];

    // 将有效区域的边界转换为相对位置
    final effectiveTop = effectiveRect.top / imageSize.height;
    final effectiveBottom = effectiveRect.bottom / imageSize.height;
    final effectiveLeft = effectiveRect.left / imageSize.width;
    final effectiveRight = effectiveRect.right / imageSize.width;

    // 添加有效区域的边界作为起止点（而不是 0.0 和 1.0）
    final hLines = [effectiveTop, ...horizontalLines, effectiveBottom];
    final vLines = [effectiveLeft, ...verticalLines, effectiveRight];

    // 计算每个切片区域
    for (int row = 0; row < hLines.length - 1; row++) {
      for (int col = 0; col < vLines.length - 1; col++) {
        final left = vLines[col] * imageSize.width;
        final top = hLines[row] * imageSize.height;
        final right = vLines[col + 1] * imageSize.width;
        final bottom = hLines[row + 1] * imageSize.height;

        regions.add({
          'row': row,
          'col': col,
          'region': ui.Rect.fromLTRB(left, top, right, bottom),
        });
      }
    }

    return regions;
  }

  /// 生成缩略图
  Future<Uint8List> _generateThumbnail(ui.Image source, ui.Rect region) async {
    // 计算缩略图尺寸（保持宽高比）
    final aspectRatio = region.width / region.height;
    int thumbWidth, thumbHeight;

    if (aspectRatio > 1) {
      thumbWidth = thumbnailMaxSize;
      thumbHeight = (thumbnailMaxSize / aspectRatio).round();
    } else {
      thumbHeight = thumbnailMaxSize;
      thumbWidth = (thumbnailMaxSize * aspectRatio).round();
    }

    // 确保尺寸至少为 1
    thumbWidth = thumbWidth.clamp(1, thumbnailMaxSize);
    thumbHeight = thumbHeight.clamp(1, thumbnailMaxSize);

    // 创建 Picture Recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制裁剪后的图片
    final srcRect = region;
    final dstRect = ui.Rect.fromLTWH(
      0,
      0,
      thumbWidth.toDouble(),
      thumbHeight.toDouble(),
    );

    canvas.drawImageRect(
      source,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.medium,
    );

    // 转换为图片
    final picture = recorder.endRecording();
    final image = await picture.toImage(thumbWidth, thumbHeight);

    // 编码为 PNG
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();

    return byteData!.buffer.asUint8List();
  }

  /// 切换单个切片的选中状态
  void toggleSliceSelection(int index) {
    if (index >= 0 && index < _slices.length) {
      _slices[index].isSelected = !_slices[index].isSelected;
      notifyListeners();
    }
  }

  /// 设置单个切片的选中状态
  void setSliceSelection(int index, bool selected) {
    if (index >= 0 && index < _slices.length) {
      _slices[index].isSelected = selected;
      notifyListeners();
    }
  }

  /// 全选
  void selectAll() {
    for (final slice in _slices) {
      slice.isSelected = true;
    }
    notifyListeners();
  }

  /// 全不选
  void selectNone() {
    for (final slice in _slices) {
      slice.isSelected = false;
    }
    notifyListeners();
  }

  /// 反选
  void invertSelection() {
    for (final slice in _slices) {
      slice.isSelected = !slice.isSelected;
    }
    notifyListeners();
  }

  /// 选择指定范围内的切片（用于框选）
  void selectRange(Set<int> indices, {bool addToSelection = false}) {
    if (!addToSelection) {
      // 先取消所有选中
      for (final slice in _slices) {
        slice.isSelected = false;
      }
    }
    // 选中指定范围
    for (final index in indices) {
      if (index >= 0 && index < _slices.length) {
        _slices[index].isSelected = true;
      }
    }
    notifyListeners();
  }

  /// 更新切片的自定义后缀
  void updateSliceSuffix(int index, String suffix) {
    if (index >= 0 && index < _slices.length) {
      _slices[index].customSuffix = suffix;
      notifyListeners();
    }
  }

  /// 设置切片的处理器覆盖参数
  void setSliceOverrides(
    int index,
    String processorId,
    ProcessorParams params,
  ) {
    if (index >= 0 && index < _slices.length) {
      _slices[index].setOverrides(processorId, params);
      notifyListeners();
    }
  }

  /// 移除切片的处理器覆盖参数
  void removeSliceOverrides(int index, String processorId) {
    if (index >= 0 && index < _slices.length) {
      _slices[index].removeOverrides(processorId);
      notifyListeners();
    }
  }

  /// 清除切片的所有覆盖参数
  void clearSliceOverrides(int index) {
    if (index >= 0 && index < _slices.length) {
      _slices[index].clearOverrides();
      notifyListeners();
    }
  }

  /// 重置所有切片的后缀为默认值
  void resetAllSuffixes() {
    for (final slice in _slices) {
      slice.resetSuffix();
    }
    notifyListeners();
  }

  /// 获取选中的切片列表
  List<SlicePreview> get selectedSlices =>
      _slices.where((s) => s.isSelected).toList();

  /// 清空预览
  void clearPreview() {
    _slices = [];
    _progress = 0.0;
    _errorMessage = null;
    notifyListeners();
  }

  /// 清除错误
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

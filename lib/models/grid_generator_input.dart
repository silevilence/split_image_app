import 'dart:typed_data';
import 'dart:ui';

/// 网格生成器输入参数
///
/// 包含生成网格线所需的所有信息，作为策略模式的标准输入。
class GridGeneratorInput {
  /// 有效区域（排除边距后的区域）
  final Rect effectiveRect;

  /// 目标行数
  final int targetRows;

  /// 目标列数
  final int targetCols;

  /// 图片宽度（像素）
  final int imageWidth;

  /// 图片高度（像素）
  final int imageHeight;

  /// 图片像素数据（可选，仅智能算法需要）
  ///
  /// 格式为 RGBA 字节数组，每个像素 4 字节。
  /// 智能算法（如投影分析）需要此数据来分析图片内容。
  /// 均匀分割算法不需要此数据。
  final Uint8List? pixelData;

  /// 用户是否手动设置了边距
  ///
  /// 如果为 true，智能算法应跳过边缘检测，直接在有效区域内工作。
  /// 如果为 false，智能算法可以检测边缘并建议新的边距。
  final bool hasUserMargins;

  const GridGeneratorInput({
    required this.effectiveRect,
    required this.targetRows,
    required this.targetCols,
    required this.imageWidth,
    required this.imageHeight,
    this.pixelData,
    this.hasUserMargins = false,
  });

  /// 图片尺寸
  Size get imageSize => Size(imageWidth.toDouble(), imageHeight.toDouble());

  /// 有效区域宽度
  double get effectiveWidth => effectiveRect.width;

  /// 有效区域高度
  double get effectiveHeight => effectiveRect.height;

  /// 是否包含像素数据
  bool get hasPixelData => pixelData != null && pixelData!.isNotEmpty;

  @override
  String toString() {
    return 'GridGeneratorInput('
        'effectiveRect: $effectiveRect, '
        'targetRows: $targetRows, '
        'targetCols: $targetCols, '
        'imageSize: ${imageWidth}x$imageHeight, '
        'hasPixelData: $hasPixelData)';
  }
}

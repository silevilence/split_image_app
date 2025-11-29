import 'package:fluent_ui/fluent_ui.dart';

import '../models/margins.dart';

/// 网格线绘制器
/// 支持高亮、拖拽状态、选中状态显示、边距遮罩
class GridPainter extends CustomPainter {
  /// 水平线位置列表（相对于图片尺寸的比例 0.0-1.0）
  final List<double> horizontalLines;

  /// 垂直线位置列表（相对于图片尺寸的比例 0.0-1.0）
  final List<double> verticalLines;

  /// 当前悬停的线索引（用于高亮）
  final int? hoveredHorizontalIndex;
  final int? hoveredVerticalIndex;

  /// 选中的线索引
  final int? selectedHorizontalIndex;
  final int? selectedVerticalIndex;

  /// 是否正在拖拽
  final bool isDragging;

  /// 边距设置（用于绘制遮罩）
  final ImageMargins margins;

  /// 图片实际尺寸（用于计算边距的像素位置）
  final Size imageSize;

  GridPainter({
    required this.horizontalLines,
    required this.verticalLines,
    required this.imageSize,
    this.hoveredHorizontalIndex,
    this.hoveredVerticalIndex,
    this.selectedHorizontalIndex,
    this.selectedVerticalIndex,
    this.isDragging = false,
    this.margins = ImageMargins.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制边距遮罩（在网格线下方）
    if (!margins.isZero) {
      _drawMarginsMask(canvas, size);
    }

    // 绘制边框
    final borderPaint = Paint()
      ..color = const Color(0xFFFF5722)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Offset.zero & size, borderPaint);

    // 绘制有效区域边框（如果有边距）
    if (!margins.isZero) {
      _drawEffectiveAreaBorder(canvas, size);
    }

    // 绘制水平线
    for (int i = 0; i < horizontalLines.length; i++) {
      final y = size.height * horizontalLines[i];
      final isHovered = hoveredHorizontalIndex == i;
      final isSelected = selectedHorizontalIndex == i;
      _drawLine(
        canvas,
        Offset(0, y),
        Offset(size.width, y),
        isHovered,
        isSelected,
      );
    }

    // 绘制垂直线
    for (int i = 0; i < verticalLines.length; i++) {
      final x = size.width * verticalLines[i];
      final isHovered = hoveredVerticalIndex == i;
      final isSelected = selectedVerticalIndex == i;
      _drawLine(
        canvas,
        Offset(x, 0),
        Offset(x, size.height),
        isHovered,
        isSelected,
      );
    }
  }

  /// 绘制边距遮罩
  void _drawMarginsMask(Canvas canvas, Size size) {
    final maskPaint = Paint()
      ..color = const Color(0x60000000) // 半透明黑色
      ..style = PaintingStyle.fill;

    // 计算边距在渲染尺寸中的位置（按比例缩放）
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    final left = margins.left * scaleX;
    final right = margins.right * scaleX;
    final top = margins.top * scaleY;
    final bottom = margins.bottom * scaleY;

    // 上方遮罩
    if (top > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, top),
        maskPaint,
      );
    }

    // 下方遮罩
    if (bottom > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, size.height - bottom, size.width, bottom),
        maskPaint,
      );
    }

    // 左侧遮罩（排除上下已绘制的部分）
    if (left > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, top, left, size.height - top - bottom),
        maskPaint,
      );
    }

    // 右侧遮罩（排除上下已绘制的部分）
    if (right > 0) {
      canvas.drawRect(
        Rect.fromLTWH(size.width - right, top, right, size.height - top - bottom),
        maskPaint,
      );
    }
  }

  /// 绘制有效区域边框
  void _drawEffectiveAreaBorder(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    final effectiveRect = Rect.fromLTRB(
      margins.left * scaleX,
      margins.top * scaleY,
      size.width - margins.right * scaleX,
      size.height - margins.bottom * scaleY,
    );

    final borderPaint = Paint()
      ..color = const Color(0xFF00BCD4) // 青色边框
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // 绘制虚线效果
    final dashPath = Path()..addRect(effectiveRect);
    canvas.drawPath(dashPath, borderPaint);
  }

  /// 绘制单条线
  void _drawLine(Canvas canvas, Offset start, Offset end, bool isHovered, bool isSelected) {
    Color lineColor;
    double lineWidth;

    if (isSelected) {
      // 选中状态：蓝色加粗
      lineColor = const Color(0xFF0078D4);
      lineWidth = 3.0;
    } else if (isHovered) {
      // 悬停状态：黄色高亮
      lineColor = const Color(0xFFFFEB3B);
      lineWidth = 2.5;
    } else {
      // 普通状态：半透明橙色
      lineColor = const Color(0x80FF5722);
      lineWidth = 1.5;
    }

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, paint);

    // 绘制额外的阴影效果
    if (isSelected) {
      final shadowPaint = Paint()
        ..color = const Color(0x400078D4)
        ..strokeWidth = 10.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(start, end, shadowPaint);
    } else if (isHovered) {
      final shadowPaint = Paint()
        ..color = const Color(0x40FFEB3B)
        ..strokeWidth = 8.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(start, end, shadowPaint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return oldDelegate.horizontalLines != horizontalLines ||
        oldDelegate.verticalLines != verticalLines ||
        oldDelegate.hoveredHorizontalIndex != hoveredHorizontalIndex ||
        oldDelegate.hoveredVerticalIndex != hoveredVerticalIndex ||
        oldDelegate.selectedHorizontalIndex != selectedHorizontalIndex ||
        oldDelegate.selectedVerticalIndex != selectedVerticalIndex ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.margins != margins ||
        oldDelegate.imageSize != imageSize;
  }
}

import 'package:fluent_ui/fluent_ui.dart';

/// 网格线绘制器
/// 支持高亮、拖拽状态、选中状态显示
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

  GridPainter({
    required this.horizontalLines,
    required this.verticalLines,
    this.hoveredHorizontalIndex,
    this.hoveredVerticalIndex,
    this.selectedHorizontalIndex,
    this.selectedVerticalIndex,
    this.isDragging = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制边框
    final borderPaint = Paint()
      ..color = const Color(0xFFFF5722)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Offset.zero & size, borderPaint);

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
        oldDelegate.isDragging != isDragging;
  }
}

/// 网格线数据模型
class GridLine {
  /// 线的位置（像素坐标，相对于图片）
  final double position;

  /// 线的类型
  final LineType type;

  const GridLine({
    required this.position,
    required this.type,
  });

  GridLine copyWith({double? position, LineType? type}) {
    return GridLine(
      position: position ?? this.position,
      type: type ?? this.type,
    );
  }

  @override
  String toString() => 'GridLine(position: $position, type: $type)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GridLine &&
        other.position == position &&
        other.type == type;
  }

  @override
  int get hashCode => position.hashCode ^ type.hashCode;
}

/// 线的类型
enum LineType {
  horizontal,
  vertical,
}

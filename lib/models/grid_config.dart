/// 网格配置数据模型
class GridConfig {
  /// 行数
  final int rows;

  /// 列数
  final int cols;

  const GridConfig({
    required this.rows,
    required this.cols,
  });

  /// 默认配置: 4行6列
  factory GridConfig.defaultConfig() => const GridConfig(rows: 4, cols: 6);

  /// 交换行列
  GridConfig swap() => GridConfig(rows: cols, cols: rows);

  /// 计算网格宽高比 (cols / rows)
  double get aspectRatio => cols / rows;

  GridConfig copyWith({int? rows, int? cols}) {
    return GridConfig(
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
    );
  }

  @override
  String toString() => 'GridConfig(rows: $rows, cols: $cols)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GridConfig && other.rows == rows && other.cols == cols;
  }

  @override
  int get hashCode => rows.hashCode ^ cols.hashCode;
}

import 'dart:typed_data';
import 'dart:ui' as ui;

/// 切片预览数据模型
class SlicePreview {
  /// 行索引（从0开始）
  final int row;

  /// 列索引（从0开始）
  final int col;

  /// 在原图中的区域（像素坐标）
  final ui.Rect region;

  /// 缩略图字节数据（PNG 格式）
  final Uint8List thumbnailBytes;

  /// 是否被选中
  bool isSelected;

  /// 自定义后缀名（用于导出文件名）
  String customSuffix;

  SlicePreview({
    required this.row,
    required this.col,
    required this.region,
    required this.thumbnailBytes,
    this.isSelected = true, // 默认选中
    String? customSuffix,
  }) : customSuffix = customSuffix ?? '${row + 1}_${col + 1}';

  /// 获取切片的宽度（像素）
  double get width => region.width;

  /// 获取切片的高度（像素）
  double get height => region.height;

  /// 生成默认的文件名后缀
  String get defaultSuffix => '${row + 1}_${col + 1}';

  /// 重置为默认后缀
  void resetSuffix() {
    customSuffix = defaultSuffix;
  }

  /// 复制并修改选中状态
  SlicePreview copyWith({
    bool? isSelected,
    String? customSuffix,
  }) {
    return SlicePreview(
      row: row,
      col: col,
      region: region,
      thumbnailBytes: thumbnailBytes,
      isSelected: isSelected ?? this.isSelected,
      customSuffix: customSuffix ?? this.customSuffix,
    );
  }

  @override
  String toString() {
    return 'SlicePreview(row: $row, col: $col, region: $region, selected: $isSelected)';
  }
}

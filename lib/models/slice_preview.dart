import 'dart:typed_data';
import 'dart:ui' as ui;

import '../processors/processor_param.dart';

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

  /// 单图参数覆盖 (processorInstanceId -> ProcessorParams)
  ///
  /// 存储该切片对特定处理器的参数覆盖。
  /// 当处理器链执行时，会将此处的参数与处理器的全局参数合并。
  Map<String, ProcessorParams> processorOverrides;

  SlicePreview({
    required this.row,
    required this.col,
    required this.region,
    required this.thumbnailBytes,
    this.isSelected = true, // 默认选中
    String? customSuffix,
    Map<String, ProcessorParams>? processorOverrides,
  }) : customSuffix = customSuffix ?? '${row + 1}_${col + 1}',
       processorOverrides = processorOverrides ?? {};

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

  /// 是否有处理器参数覆盖
  bool get hasOverrides => processorOverrides.isNotEmpty;

  /// 获取指定处理器的覆盖参数
  ProcessorParams? getOverrides(String processorInstanceId) {
    return processorOverrides[processorInstanceId];
  }

  /// 设置指定处理器的覆盖参数
  void setOverrides(String processorInstanceId, ProcessorParams params) {
    processorOverrides[processorInstanceId] = params;
  }

  /// 移除指定处理器的覆盖参数
  void removeOverrides(String processorInstanceId) {
    processorOverrides.remove(processorInstanceId);
  }

  /// 清除所有覆盖参数
  void clearOverrides() {
    processorOverrides.clear();
  }

  /// 复制并修改属性
  SlicePreview copyWith({
    bool? isSelected,
    String? customSuffix,
    Map<String, ProcessorParams>? processorOverrides,
  }) {
    return SlicePreview(
      row: row,
      col: col,
      region: region,
      thumbnailBytes: thumbnailBytes,
      isSelected: isSelected ?? this.isSelected,
      customSuffix: customSuffix ?? this.customSuffix,
      processorOverrides:
          processorOverrides ?? Map.from(this.processorOverrides),
    );
  }

  @override
  String toString() {
    return 'SlicePreview(row: $row, col: $col, region: $region, selected: $isSelected, overrides: ${processorOverrides.length})';
  }
}

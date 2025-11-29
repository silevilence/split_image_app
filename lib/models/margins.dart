import 'dart:ui';

/// 图片边缘留白配置
/// 用于排除图片四周不参与网格计算的区域
class ImageMargins {
  /// 上边距（像素）
  final double top;

  /// 下边距（像素）
  final double bottom;

  /// 左边距（像素）
  final double left;

  /// 右边距（像素）
  final double right;

  const ImageMargins({
    this.top = 0,
    this.bottom = 0,
    this.left = 0,
    this.right = 0,
  });

  /// 零边距（无留白）
  static const ImageMargins zero = ImageMargins();

  /// 统一边距
  factory ImageMargins.all(double value) => ImageMargins(
        top: value,
        bottom: value,
        left: value,
        right: value,
      );

  /// 对称边距
  factory ImageMargins.symmetric({double horizontal = 0, double vertical = 0}) =>
      ImageMargins(
        top: vertical,
        bottom: vertical,
        left: horizontal,
        right: horizontal,
      );

  /// 是否为零边距
  bool get isZero => top == 0 && bottom == 0 && left == 0 && right == 0;

  /// 水平方向总边距
  double get horizontal => left + right;

  /// 垂直方向总边距
  double get vertical => top + bottom;

  /// 计算有效区域（Effective Rect）
  /// [imageSize] 原图尺寸
  /// 返回排除边距后的有效区域
  Rect getEffectiveRect(Size imageSize) {
    // 确保边距不超过图片尺寸
    final clampedLeft = left.clamp(0.0, imageSize.width - 1);
    final clampedRight = right.clamp(0.0, imageSize.width - clampedLeft - 1);
    final clampedTop = top.clamp(0.0, imageSize.height - 1);
    final clampedBottom = bottom.clamp(0.0, imageSize.height - clampedTop - 1);

    return Rect.fromLTRB(
      clampedLeft,
      clampedTop,
      imageSize.width - clampedRight,
      imageSize.height - clampedBottom,
    );
  }

  /// 验证边距是否有效
  /// [imageSize] 原图尺寸
  /// 返回 null 表示有效，否则返回错误信息
  String? validate(Size imageSize) {
    if (left < 0 || right < 0 || top < 0 || bottom < 0) {
      return '边距不能为负数';
    }
    if (left + right >= imageSize.width) {
      return '左右边距之和超过图片宽度';
    }
    if (top + bottom >= imageSize.height) {
      return '上下边距之和超过图片高度';
    }
    return null;
  }

  ImageMargins copyWith({
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return ImageMargins(
      top: top ?? this.top,
      bottom: bottom ?? this.bottom,
      left: left ?? this.left,
      right: right ?? this.right,
    );
  }

  @override
  String toString() =>
      'ImageMargins(top: $top, bottom: $bottom, left: $left, right: $right)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageMargins &&
        other.top == top &&
        other.bottom == bottom &&
        other.left == left &&
        other.right == right;
  }

  @override
  int get hashCode =>
      top.hashCode ^ bottom.hashCode ^ left.hashCode ^ right.hashCode;

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
        'top': top,
        'bottom': bottom,
        'left': left,
        'right': right,
      };

  /// 从 JSON 创建
  factory ImageMargins.fromJson(Map<String, dynamic> json) => ImageMargins(
        top: (json['top'] as num?)?.toDouble() ?? 0,
        bottom: (json['bottom'] as num?)?.toDouble() ?? 0,
        left: (json['left'] as num?)?.toDouble() ?? 0,
        right: (json['right'] as num?)?.toDouble() ?? 0,
      );
}

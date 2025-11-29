/// 网格生成器输出结果
///
/// 包含生成的网格线位置，作为策略模式的标准输出。
class GridGeneratorResult {
  /// 水平网格线位置（相对位置 0.0-1.0，基于整个图片）
  final List<double> horizontalLines;

  /// 垂直网格线位置（相对位置 0.0-1.0，基于整个图片）
  final List<double> verticalLines;

  /// 可选的提示信息（如算法执行结果、警告等）
  final String? message;

  /// 算法是否成功执行
  final bool success;

  /// 建议的边距（相对于原始图片的像素值）
  /// 如果算法检测到边缘留白，会建议设置这些边距
  final SuggestedMargins? suggestedMargins;

  const GridGeneratorResult({
    required this.horizontalLines,
    required this.verticalLines,
    this.message,
    this.success = true,
    this.suggestedMargins,
  });

  /// 创建成功的结果
  factory GridGeneratorResult.success({
    required List<double> horizontalLines,
    required List<double> verticalLines,
    String? message,
    SuggestedMargins? suggestedMargins,
  }) {
    return GridGeneratorResult(
      horizontalLines: horizontalLines,
      verticalLines: verticalLines,
      message: message,
      success: true,
      suggestedMargins: suggestedMargins,
    );
  }

  /// 创建失败的结果
  factory GridGeneratorResult.failure(String message) {
    return GridGeneratorResult(
      horizontalLines: const [],
      verticalLines: const [],
      message: message,
      success: false,
    );
  }

  /// 水平线数量
  int get horizontalLineCount => horizontalLines.length;

  /// 垂直线数量
  int get verticalLineCount => verticalLines.length;

  /// 实际行数（水平线数量 + 1）
  int get actualRows => horizontalLines.length + 1;

  /// 实际列数（垂直线数量 + 1）
  int get actualCols => verticalLines.length + 1;

  @override
  String toString() {
    return 'GridGeneratorResult('
        'horizontalLines: $horizontalLineCount, '
        'verticalLines: $verticalLineCount, '
        'success: $success'
        '${message != null ? ', message: $message' : ''}'
        '${suggestedMargins != null ? ', suggestedMargins: $suggestedMargins' : ''})';
  }
}

/// 建议的边距值（像素）
class SuggestedMargins {
  final int top;
  final int bottom;
  final int left;
  final int right;

  const SuggestedMargins({
    this.top = 0,
    this.bottom = 0,
    this.left = 0,
    this.right = 0,
  });

  /// 是否有任何非零边距
  bool get hasMargins => top > 0 || bottom > 0 || left > 0 || right > 0;

  @override
  String toString() =>
      'SuggestedMargins(top: $top, bottom: $bottom, left: $left, right: $right)';
}

import '../models/grid_algorithm_type.dart';
import '../models/grid_generator_input.dart';
import '../models/grid_generator_result.dart';
import 'grid_generator_strategy.dart';

/// 均匀分割策略
///
/// 将有效区域按照目标行列数进行等分。
/// 这是最基础的网格生成算法，不需要分析图片内容。
class FixedEvenSplitStrategy extends GridGeneratorStrategy {
  @override
  GridAlgorithmType get type => GridAlgorithmType.fixedEvenSplit;

  @override
  bool get requiresPixelData => false;

  @override
  Future<GridGeneratorResult> generate(GridGeneratorInput input) async {
    // 生成水平线（行数-1条）
    // 相对位置需要从有效区域映射到整个图片
    final horizontalLines = List<double>.generate(input.targetRows - 1, (i) {
      // 在有效区域内的相对位置
      final relativeInEffective = (i + 1) / input.targetRows;
      // 在有效区域内的实际 Y 坐标
      final actualY =
          input.effectiveRect.top + input.effectiveHeight * relativeInEffective;
      // 转换为整个图片的相对位置
      return actualY / input.imageHeight;
    });

    // 生成垂直线（列数-1条）
    final verticalLines = List<double>.generate(input.targetCols - 1, (i) {
      // 在有效区域内的相对位置
      final relativeInEffective = (i + 1) / input.targetCols;
      // 在有效区域内的实际 X 坐标
      final actualX =
          input.effectiveRect.left + input.effectiveWidth * relativeInEffective;
      // 转换为整个图片的相对位置
      return actualX / input.imageWidth;
    });

    return GridGeneratorResult.success(
      horizontalLines: horizontalLines,
      verticalLines: verticalLines,
    );
  }
}

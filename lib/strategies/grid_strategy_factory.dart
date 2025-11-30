import '../models/grid_algorithm_type.dart';
import 'edge_detection_strategy.dart';
import 'fixed_even_split_strategy.dart';
import 'grid_generator_strategy.dart';
import 'projection_profile_strategy.dart';

/// 网格生成策略工厂
///
/// 根据算法类型创建对应的策略实例。
/// 新增算法只需在 [create] 方法中添加对应的 switch case。
class GridStrategyFactory {
  GridStrategyFactory._();

  /// 根据算法类型创建策略实例
  ///
  /// [type] 算法类型
  ///
  /// 抛出 [UnimplementedError] 如果算法尚未实现。
  static GridGeneratorStrategy create(GridAlgorithmType type) {
    switch (type) {
      case GridAlgorithmType.fixedEvenSplit:
        return FixedEvenSplitStrategy();
      case GridAlgorithmType.projectionProfile:
        return ProjectionProfileStrategy();
      case GridAlgorithmType.edgeDetection:
        return EdgeDetectionStrategy();
    }
  }

  /// 尝试创建策略实例，如果未实现则返回 null
  static GridGeneratorStrategy? tryCreate(GridAlgorithmType type) {
    try {
      return create(type);
    } on UnimplementedError {
      return null;
    }
  }

  /// 获取所有已实现的策略列表
  static List<GridGeneratorStrategy> getAllImplementedStrategies() {
    return GridAlgorithmType.values
        .where((type) => type.isImplemented)
        .map((type) => create(type))
        .toList();
  }

  /// 获取所有算法类型（包括未实现的）
  static List<GridAlgorithmType> getAllAlgorithmTypes() {
    return GridAlgorithmType.values.toList();
  }

  /// 获取所有已实现的算法类型
  static List<GridAlgorithmType> getImplementedAlgorithmTypes() {
    return GridAlgorithmType.values
        .where((type) => type.isImplemented)
        .toList();
  }
}

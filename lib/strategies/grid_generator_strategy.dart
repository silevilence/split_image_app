import '../models/grid_algorithm_type.dart';
import '../models/grid_generator_input.dart';
import '../models/grid_generator_result.dart';

/// 网格生成器策略抽象基类
///
/// 使用策略模式 (Strategy Pattern) 解耦网格生成算法与业务逻辑。
/// 新增算法只需：
/// 1. 在 [GridAlgorithmType] 添加枚举值
/// 2. 创建新的策略实现类
/// 3. 在 [GridStrategyFactory] 添加 switch case
abstract class GridGeneratorStrategy {
  /// 获取算法类型
  GridAlgorithmType get type;

  /// 获取算法显示名称
  String get displayName => type.displayName;

  /// 获取算法描述
  String get description => type.description;

  /// 是否需要像素数据
  ///
  /// 智能算法（如投影分析）需要像素数据来分析图片内容，
  /// 均匀分割等简单算法不需要。
  bool get requiresPixelData => false;

  /// 生成网格线
  ///
  /// [input] 包含有效区域、目标行列数、图片尺寸等信息
  ///
  /// 返回 [GridGeneratorResult] 包含生成的网格线位置。
  /// 此方法应设计为可在 Isolate 中运行（避免使用 UI 相关 API）。
  Future<GridGeneratorResult> generate(GridGeneratorInput input);
}

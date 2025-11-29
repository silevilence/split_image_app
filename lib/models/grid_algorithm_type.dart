/// 网格生成算法类型枚举
enum GridAlgorithmType {
  /// 均匀分割 - 将有效区域等分为指定的行列数
  fixedEvenSplit,

  /// 投影分析法 - 基于图片投影分析自动检测网格线位置
  projectionProfile,

  /// 边缘检测 - 基于边缘检测算法识别贴纸边界
  edgeDetection,
}

/// 算法类型扩展方法
extension GridAlgorithmTypeExtension on GridAlgorithmType {
  /// 获取显示名称
  String get displayName {
    switch (this) {
      case GridAlgorithmType.fixedEvenSplit:
        return '均匀分割';
      case GridAlgorithmType.projectionProfile:
        return '投影分析法';
      case GridAlgorithmType.edgeDetection:
        return '边缘检测 (暂未实现)';
    }
  }

  /// 获取算法描述
  String get description {
    switch (this) {
      case GridAlgorithmType.fixedEvenSplit:
        return '将图片均匀分割为指定的行列数';
      case GridAlgorithmType.projectionProfile:
        return '基于投影分析自动检测贴纸间隙位置';
      case GridAlgorithmType.edgeDetection:
        return '基于边缘检测算法识别贴纸边界 (暂未实现)';
    }
  }

  /// 是否已实现
  bool get isImplemented {
    switch (this) {
      case GridAlgorithmType.fixedEvenSplit:
        return true;
      case GridAlgorithmType.projectionProfile:
        return true;
      case GridAlgorithmType.edgeDetection:
        return false; // 待实现
    }
  }

  /// 配置文件中使用的键名
  String get configKey {
    switch (this) {
      case GridAlgorithmType.fixedEvenSplit:
        return 'fixedEvenSplit';
      case GridAlgorithmType.projectionProfile:
        return 'projectionProfile';
      case GridAlgorithmType.edgeDetection:
        return 'edgeDetection';
    }
  }

  /// 从配置键名解析
  static GridAlgorithmType fromConfigKey(String key) {
    switch (key) {
      case 'fixedEvenSplit':
        return GridAlgorithmType.fixedEvenSplit;
      case 'projectionProfile':
        return GridAlgorithmType.projectionProfile;
      case 'edgeDetection':
        return GridAlgorithmType.edgeDetection;
      default:
        return GridAlgorithmType.fixedEvenSplit;
    }
  }
}

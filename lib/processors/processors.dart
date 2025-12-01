/// 图片后处理流水线模块
///
/// 提供图片处理器架构、处理器链管理、参数配置等功能。
library;

export 'image_processor.dart';
export 'processor_chain.dart';
export 'processor_factory.dart';
export 'processor_io.dart';
export 'processor_param.dart';

// 具体处理器实现
export 'background_removal_processor.dart';
export 'smart_crop_processor.dart';
export 'color_replace_processor.dart';
export 'resize_processor.dart';

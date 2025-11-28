/// 应用配置模型
/// 
/// 用于存储和管理应用的持久化配置，包括导出设置、快捷键绑定、网格默认值等。
library;

/// 导出相关配置
class ExportConfig {
  /// 上次导出的目录路径
  String? lastDirectory;

  /// 默认文件前缀
  String defaultPrefix;

  /// 默认导出格式 (png, jpg, webp)
  String defaultFormat;

  ExportConfig({
    this.lastDirectory,
    this.defaultPrefix = '',
    this.defaultFormat = 'png',
  });

  /// 从 Map 创建配置
  factory ExportConfig.fromMap(Map<String, dynamic> map) {
    return ExportConfig(
      lastDirectory: map['last_directory'] as String?,
      defaultPrefix: map['default_prefix'] as String? ?? '',
      defaultFormat: map['default_format'] as String? ?? 'png',
    );
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      if (lastDirectory != null) 'last_directory': lastDirectory,
      'default_prefix': defaultPrefix,
      'default_format': defaultFormat,
    };
  }

  /// 复制并修改
  ExportConfig copyWith({
    String? lastDirectory,
    String? defaultPrefix,
    String? defaultFormat,
  }) {
    return ExportConfig(
      lastDirectory: lastDirectory ?? this.lastDirectory,
      defaultPrefix: defaultPrefix ?? this.defaultPrefix,
      defaultFormat: defaultFormat ?? this.defaultFormat,
    );
  }
}

/// 快捷键配置
class ShortcutsConfig {
  /// 切换模式快捷键
  String toggleMode;

  /// 删除线条快捷键
  String deleteLine;

  /// 撤销快捷键
  String undo;

  /// 重做快捷键
  String redo;

  ShortcutsConfig({
    this.toggleMode = 'V',
    this.deleteLine = 'Delete',
    this.undo = 'Ctrl+Z',
    this.redo = 'Ctrl+Y',
  });

  /// 从 Map 创建配置
  factory ShortcutsConfig.fromMap(Map<String, dynamic> map) {
    return ShortcutsConfig(
      toggleMode: map['toggle_mode'] as String? ?? 'V',
      deleteLine: map['delete_line'] as String? ?? 'Delete',
      undo: map['undo'] as String? ?? 'Ctrl+Z',
      redo: map['redo'] as String? ?? 'Ctrl+Y',
    );
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'toggle_mode': toggleMode,
      'delete_line': deleteLine,
      'undo': undo,
      'redo': redo,
    };
  }
}

/// 网格默认配置
class GridConfig {
  /// 默认行数
  int defaultRows;

  /// 默认列数
  int defaultCols;

  GridConfig({
    this.defaultRows = 3,
    this.defaultCols = 3,
  });

  /// 从 Map 创建配置
  factory GridConfig.fromMap(Map<String, dynamic> map) {
    return GridConfig(
      defaultRows: (map['default_rows'] as num?)?.toInt() ?? 3,
      defaultCols: (map['default_cols'] as num?)?.toInt() ?? 3,
    );
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'default_rows': defaultRows,
      'default_cols': defaultCols,
    };
  }
}

/// 应用全局配置
class AppConfig {
  /// 导出配置
  ExportConfig export;

  /// 快捷键配置
  ShortcutsConfig shortcuts;

  /// 网格配置
  GridConfig grid;

  AppConfig({
    ExportConfig? export,
    ShortcutsConfig? shortcuts,
    GridConfig? grid,
  })  : export = export ?? ExportConfig(),
        shortcuts = shortcuts ?? ShortcutsConfig(),
        grid = grid ?? GridConfig();

  /// 创建默认配置
  factory AppConfig.defaults() => AppConfig();

  /// 从 Map 创建配置
  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      export: map['export'] != null
          ? ExportConfig.fromMap(Map<String, dynamic>.from(map['export'] as Map))
          : null,
      shortcuts: map['shortcuts'] != null
          ? ShortcutsConfig.fromMap(Map<String, dynamic>.from(map['shortcuts'] as Map))
          : null,
      grid: map['grid'] != null
          ? GridConfig.fromMap(Map<String, dynamic>.from(map['grid'] as Map))
          : null,
    );
  }

  /// 转换为 Map (用于 TOML 序列化)
  Map<String, dynamic> toMap() {
    return {
      'export': export.toMap(),
      'shortcuts': shortcuts.toMap(),
      'grid': grid.toMap(),
    };
  }
}

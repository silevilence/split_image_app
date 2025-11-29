import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:toml/toml.dart';

import '../models/app_config.dart';
import '../models/grid_algorithm_type.dart';

/// 配置服务 - 管理应用配置的读写和持久化
///
/// 使用单例模式，通过 [ConfigService.instance] 访问。
/// 配置文件使用 TOML 格式存储在软件根目录下的 `config.toml`。
class ConfigService extends ChangeNotifier {
  static ConfigService? _instance;

  /// 获取单例实例
  static ConfigService get instance {
    _instance ??= ConfigService._();
    return _instance!;
  }

  ConfigService._();

  /// 配置文件名
  static const String _configFileName = 'config.toml';

  /// 当前配置
  AppConfig _config = AppConfig.defaults();

  /// 获取当前配置
  AppConfig get config => _config;

  /// 配置文件路径
  String? _configFilePath;

  /// 是否已初始化
  bool _initialized = false;

  /// 是否已初始化
  bool get initialized => _initialized;

  /// 初始化配置服务
  ///
  /// 会尝试从配置文件加载配置，如果文件不存在则创建默认配置。
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 获取应用程序所在目录
      final exePath = Platform.resolvedExecutable;
      final appDir = p.dirname(exePath);

      _configFilePath = p.join(appDir, _configFileName);

      // 尝试加载配置
      await _loadConfig();

      _initialized = true;
      debugPrint('[ConfigService] Initialized. Config path: $_configFilePath');
    } catch (e) {
      debugPrint('[ConfigService] Initialize error: $e');
      // 使用默认配置
      _config = AppConfig.defaults();
      _initialized = true;
    }
  }

  /// 从文件加载配置
  Future<void> _loadConfig() async {
    if (_configFilePath == null) return;

    final file = File(_configFilePath!);

    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final tomlDoc = TomlDocument.parse(content);
        _config = AppConfig.fromMap(tomlDoc.toMap());
        debugPrint('[ConfigService] Config loaded successfully');
      } catch (e) {
        debugPrint(
          '[ConfigService] Failed to parse config, using defaults: $e',
        );
        _config = AppConfig.defaults();
        // 备份损坏的配置文件
        await _backupCorruptedConfig(file);
        // 保存默认配置
        await _saveConfig();
      }
    } else {
      // 文件不存在，使用默认配置并保存
      debugPrint('[ConfigService] Config file not found, creating defaults');
      _config = AppConfig.defaults();
      await _saveConfig();
    }
  }

  /// 备份损坏的配置文件
  Future<void> _backupCorruptedConfig(File file) async {
    try {
      final backupPath =
          '${file.path}.backup.${DateTime.now().millisecondsSinceEpoch}';
      await file.copy(backupPath);
      debugPrint('[ConfigService] Corrupted config backed up to: $backupPath');
    } catch (e) {
      debugPrint('[ConfigService] Failed to backup corrupted config: $e');
    }
  }

  /// 保存配置到文件
  Future<void> _saveConfig() async {
    if (_configFilePath == null) return;

    try {
      // 使用 TomlDocument.fromMap 生成 TOML 内容
      final tomlDoc = TomlDocument.fromMap(_config.toMap());
      final content =
          '# SmartGridSlicer Configuration\n'
          '# Auto-generated - Do not edit manually unless you know what you are doing\n\n'
          '${tomlDoc.toString()}';
      await File(_configFilePath!).writeAsString(content);
      debugPrint('[ConfigService] Config saved');
    } catch (e) {
      debugPrint('[ConfigService] Failed to save config: $e');
    }
  }

  // ==================== 配置更新方法 ====================

  /// 更新上次导出目录
  Future<void> setLastExportDirectory(String? directory) async {
    _config.export.lastDirectory = directory;
    await _saveConfig();
    notifyListeners();
  }

  /// 获取上次导出目录
  String? get lastExportDirectory => _config.export.lastDirectory;

  /// 更新默认导出前缀
  Future<void> setDefaultExportPrefix(String prefix) async {
    _config.export.defaultPrefix = prefix;
    await _saveConfig();
    notifyListeners();
  }

  /// 更新默认导出格式
  Future<void> setDefaultExportFormat(String format) async {
    _config.export.defaultFormat = format;
    await _saveConfig();
    notifyListeners();
  }

  /// 更新网格默认行数
  Future<void> setDefaultRows(int rows) async {
    _config.grid.defaultRows = rows;
    await _saveConfig();
    notifyListeners();
  }

  /// 更新网格默认列数
  Future<void> setDefaultCols(int cols) async {
    _config.grid.defaultCols = cols;
    await _saveConfig();
    notifyListeners();
  }

  /// 获取默认网格算法
  GridAlgorithmType get defaultAlgorithm => _config.grid.defaultAlgorithm;

  /// 更新默认网格算法
  Future<void> setDefaultAlgorithm(GridAlgorithmType algorithm) async {
    _config.grid.defaultAlgorithm = algorithm;
    await _saveConfig();
    notifyListeners();
  }

  /// 重置为默认配置
  Future<void> resetToDefaults() async {
    _config = AppConfig.defaults();
    await _saveConfig();
    notifyListeners();
  }

  // ==================== 快捷键配置 ====================

  /// 更新切换模式快捷键
  Future<void> setToggleModeShortcut(String shortcut) async {
    _config.shortcuts.toggleMode = shortcut;
    await _saveConfig();
    notifyListeners();
  }

  /// 更新删除线条快捷键
  Future<void> setDeleteLineShortcut(String shortcut) async {
    _config.shortcuts.deleteLine = shortcut;
    await _saveConfig();
    notifyListeners();
  }

  /// 更新撤销快捷键
  Future<void> setUndoShortcut(String shortcut) async {
    _config.shortcuts.undo = shortcut;
    await _saveConfig();
    notifyListeners();
  }

  /// 更新重做快捷键
  Future<void> setRedoShortcut(String shortcut) async {
    _config.shortcuts.redo = shortcut;
    await _saveConfig();
    notifyListeners();
  }

  /// 获取配置文件路径（用于调试）
  String? get configFilePath => _configFilePath;
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:toml/toml.dart';

import '../models/app_config.dart';

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
        debugPrint('[ConfigService] Failed to parse config, using defaults: $e');
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
      final backupPath = '${file.path}.backup.${DateTime.now().millisecondsSinceEpoch}';
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
      final content = _generateTomlContent();
      await File(_configFilePath!).writeAsString(content);
      debugPrint('[ConfigService] Config saved');
    } catch (e) {
      debugPrint('[ConfigService] Failed to save config: $e');
    }
  }

  /// 生成 TOML 格式内容
  String _generateTomlContent() {
    final buffer = StringBuffer();
    
    // 文件头注释
    buffer.writeln('# SmartGridSlicer Configuration');
    buffer.writeln('# Auto-generated - Do not edit manually unless you know what you are doing');
    buffer.writeln();

    // Export 配置
    buffer.writeln('[export]');
    if (_config.export.lastDirectory != null) {
      buffer.writeln('last_directory = "${_escapeTomlString(_config.export.lastDirectory!)}"');
    }
    buffer.writeln('default_prefix = "${_escapeTomlString(_config.export.defaultPrefix)}"');
    buffer.writeln('default_format = "${_config.export.defaultFormat}"');
    buffer.writeln();

    // Shortcuts 配置
    buffer.writeln('[shortcuts]');
    buffer.writeln('toggle_mode = "${_config.shortcuts.toggleMode}"');
    buffer.writeln('delete_line = "${_config.shortcuts.deleteLine}"');
    buffer.writeln('undo = "${_config.shortcuts.undo}"');
    buffer.writeln('redo = "${_config.shortcuts.redo}"');
    buffer.writeln();

    // Grid 配置
    buffer.writeln('[grid]');
    buffer.writeln('default_rows = ${_config.grid.defaultRows}');
    buffer.writeln('default_cols = ${_config.grid.defaultCols}');

    return buffer.toString();
  }

  /// 转义 TOML 字符串中的特殊字符
  String _escapeTomlString(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
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

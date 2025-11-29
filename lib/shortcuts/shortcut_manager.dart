import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../services/config_service.dart';
import 'app_intents.dart';

/// 应用快捷键管理器
///
/// 负责解析配置中的快捷键字符串，生成 Flutter Shortcuts 映射。
/// 支持动态更新快捷键配置。
class AppShortcutManager extends ChangeNotifier {
  static AppShortcutManager? _instance;

  /// 获取单例实例
  static AppShortcutManager get instance {
    _instance ??= AppShortcutManager._();
    return _instance!;
  }

  AppShortcutManager._() {
    // 监听配置变化
    ConfigService.instance.addListener(_onConfigChanged);
  }

  void _onConfigChanged() {
    // 配置变化时通知监听者更新快捷键映射
    notifyListeners();
  }

  @override
  void dispose() {
    ConfigService.instance.removeListener(_onConfigChanged);
    super.dispose();
  }

  /// 获取当前的快捷键映射
  Map<ShortcutActivator, Intent> get shortcuts {
    final config = ConfigService.instance.config.shortcuts;
    final map = <ShortcutActivator, Intent>{};

    // 解析配置中的快捷键
    final toggleModeActivator = parseShortcut(config.toggleMode);
    if (toggleModeActivator != null) {
      map[toggleModeActivator] = const ToggleModeIntent();
    }

    final deleteLineActivator = parseShortcut(config.deleteLine);
    if (deleteLineActivator != null) {
      map[deleteLineActivator] = const DeleteLineIntent();
    }

    final undoActivator = parseShortcut(config.undo);
    if (undoActivator != null) {
      map[undoActivator] = const UndoIntent();
    }

    final redoActivator = parseShortcut(config.redo);
    if (redoActivator != null) {
      map[redoActivator] = const RedoIntent();
    }

    // 方向键微调（固定，不可配置）
    map[const SingleActivator(LogicalKeyboardKey.arrowUp)] =
        const NudgeUpIntent();
    map[const SingleActivator(LogicalKeyboardKey.arrowDown)] =
        const NudgeDownIntent();
    map[const SingleActivator(LogicalKeyboardKey.arrowLeft)] =
        const NudgeLeftIntent();
    map[const SingleActivator(LogicalKeyboardKey.arrowRight)] =
        const NudgeRightIntent();

    return map;
  }

  /// 解析快捷键字符串为 ShortcutActivator
  ///
  /// 支持格式：
  /// - 单键: "V", "Delete", "F1"
  /// - 组合键: "Ctrl+Z", "Ctrl+Shift+S"
  ShortcutActivator? parseShortcut(String shortcut) {
    if (shortcut.isEmpty) return null;

    final parts = shortcut
        .split('+')
        .map((s) => s.trim().toLowerCase())
        .toList();

    bool ctrl = false;
    bool shift = false;
    bool alt = false;
    bool meta = false;
    LogicalKeyboardKey? key;

    for (final part in parts) {
      switch (part) {
        case 'ctrl':
        case 'control':
          ctrl = true;
          break;
        case 'shift':
          shift = true;
          break;
        case 'alt':
          alt = true;
          break;
        case 'meta':
        case 'cmd':
        case 'win':
          meta = true;
          break;
        default:
          // 尝试解析为按键
          key = _parseKeyLabel(part);
      }
    }

    if (key == null) return null;

    return SingleActivator(
      key,
      control: ctrl,
      shift: shift,
      alt: alt,
      meta: meta,
    );
  }

  /// 将按键标签解析为 LogicalKeyboardKey
  LogicalKeyboardKey? _parseKeyLabel(String label) {
    final upperLabel = label.toUpperCase();

    // 特殊按键映射
    final specialKeys = <String, LogicalKeyboardKey>{
      'DELETE': LogicalKeyboardKey.delete,
      'BACKSPACE': LogicalKeyboardKey.backspace,
      'ENTER': LogicalKeyboardKey.enter,
      'RETURN': LogicalKeyboardKey.enter,
      'TAB': LogicalKeyboardKey.tab,
      'SPACE': LogicalKeyboardKey.space,
      'ESCAPE': LogicalKeyboardKey.escape,
      'ESC': LogicalKeyboardKey.escape,
      'UP': LogicalKeyboardKey.arrowUp,
      'DOWN': LogicalKeyboardKey.arrowDown,
      'LEFT': LogicalKeyboardKey.arrowLeft,
      'RIGHT': LogicalKeyboardKey.arrowRight,
      'HOME': LogicalKeyboardKey.home,
      'END': LogicalKeyboardKey.end,
      'PAGEUP': LogicalKeyboardKey.pageUp,
      'PAGEDOWN': LogicalKeyboardKey.pageDown,
      'INSERT': LogicalKeyboardKey.insert,
      'F1': LogicalKeyboardKey.f1,
      'F2': LogicalKeyboardKey.f2,
      'F3': LogicalKeyboardKey.f3,
      'F4': LogicalKeyboardKey.f4,
      'F5': LogicalKeyboardKey.f5,
      'F6': LogicalKeyboardKey.f6,
      'F7': LogicalKeyboardKey.f7,
      'F8': LogicalKeyboardKey.f8,
      'F9': LogicalKeyboardKey.f9,
      'F10': LogicalKeyboardKey.f10,
      'F11': LogicalKeyboardKey.f11,
      'F12': LogicalKeyboardKey.f12,
    };

    if (specialKeys.containsKey(upperLabel)) {
      return specialKeys[upperLabel];
    }

    // 单字符按键（字母和数字）- 使用预定义映射
    // 尝试从 Flutter 的键盘映射中查找
    // 这个映射处理字母键
    final keysByLabel = <String, LogicalKeyboardKey>{
      'A': LogicalKeyboardKey.keyA,
      'B': LogicalKeyboardKey.keyB,
      'C': LogicalKeyboardKey.keyC,
      'D': LogicalKeyboardKey.keyD,
      'E': LogicalKeyboardKey.keyE,
      'F': LogicalKeyboardKey.keyF,
      'G': LogicalKeyboardKey.keyG,
      'H': LogicalKeyboardKey.keyH,
      'I': LogicalKeyboardKey.keyI,
      'J': LogicalKeyboardKey.keyJ,
      'K': LogicalKeyboardKey.keyK,
      'L': LogicalKeyboardKey.keyL,
      'M': LogicalKeyboardKey.keyM,
      'N': LogicalKeyboardKey.keyN,
      'O': LogicalKeyboardKey.keyO,
      'P': LogicalKeyboardKey.keyP,
      'Q': LogicalKeyboardKey.keyQ,
      'R': LogicalKeyboardKey.keyR,
      'S': LogicalKeyboardKey.keyS,
      'T': LogicalKeyboardKey.keyT,
      'U': LogicalKeyboardKey.keyU,
      'V': LogicalKeyboardKey.keyV,
      'W': LogicalKeyboardKey.keyW,
      'X': LogicalKeyboardKey.keyX,
      'Y': LogicalKeyboardKey.keyY,
      'Z': LogicalKeyboardKey.keyZ,
      '0': LogicalKeyboardKey.digit0,
      '1': LogicalKeyboardKey.digit1,
      '2': LogicalKeyboardKey.digit2,
      '3': LogicalKeyboardKey.digit3,
      '4': LogicalKeyboardKey.digit4,
      '5': LogicalKeyboardKey.digit5,
      '6': LogicalKeyboardKey.digit6,
      '7': LogicalKeyboardKey.digit7,
      '8': LogicalKeyboardKey.digit8,
      '9': LogicalKeyboardKey.digit9,
    };

    return keysByLabel[upperLabel];
  }

  /// 检查快捷键是否冲突
  ///
  /// 返回冲突的操作名称列表，如果没有冲突返回空列表
  List<String> checkConflicts(String shortcut, String currentAction) {
    final config = ConfigService.instance.config.shortcuts;
    final conflicts = <String>[];

    final normalizedShortcut = _normalizeShortcut(shortcut);

    final shortcuts = {
      '切换模式': config.toggleMode,
      '删除线条': config.deleteLine,
      '撤销': config.undo,
      '重做': config.redo,
    };

    for (final entry in shortcuts.entries) {
      if (entry.key != currentAction &&
          _normalizeShortcut(entry.value) == normalizedShortcut) {
        conflicts.add(entry.key);
      }
    }

    return conflicts;
  }

  /// 标准化快捷键字符串（用于比较）
  String _normalizeShortcut(String shortcut) {
    final parts = shortcut
        .split('+')
        .map((s) => s.trim().toLowerCase())
        .toList();

    // 分离修饰键和主键
    final modifiers = <String>[];
    String? mainKey;

    for (final part in parts) {
      if ([
        'ctrl',
        'control',
        'shift',
        'alt',
        'meta',
        'cmd',
        'win',
      ].contains(part)) {
        modifiers.add(
          part == 'control'
              ? 'ctrl'
              : (part == 'cmd' || part == 'win' ? 'meta' : part),
        );
      } else {
        mainKey = part;
      }
    }

    // 按字母顺序排序修饰键
    modifiers.sort();

    if (mainKey != null) {
      modifiers.add(mainKey);
    }

    return modifiers.join('+');
  }

  /// 格式化快捷键显示
  ///
  /// 用于在 Tooltip 中显示
  static String formatShortcut(String shortcut) {
    if (shortcut.isEmpty) return '';

    final parts = shortcut.split('+').map((s) {
      final trimmed = s.trim();
      switch (trimmed.toLowerCase()) {
        case 'ctrl':
        case 'control':
          return 'Ctrl';
        case 'shift':
          return 'Shift';
        case 'alt':
          return 'Alt';
        case 'meta':
        case 'cmd':
        case 'win':
          return 'Win';
        default:
          return trimmed.length == 1
              ? trimmed.toUpperCase()
              : trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
      }
    }).toList();

    return parts.join('+');
  }
}

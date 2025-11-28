import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../services/config_service.dart';

/// 设置对话框
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  /// 显示设置对话框
  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final ConfigService _configService = ConfigService.instance;
  
  late TextEditingController _rowsController;
  late TextEditingController _colsController;
  late TextEditingController _prefixController;
  late String _selectedFormat;
  
  // 快捷键编辑状态
  late String _toggleModeShortcut;
  late String _deleteLineShortcut;
  late String _undoShortcut;
  late String _redoShortcut;

  @override
  void initState() {
    super.initState();
    final config = _configService.config;
    _rowsController = TextEditingController(
      text: config.grid.defaultRows.toString(),
    );
    _colsController = TextEditingController(
      text: config.grid.defaultCols.toString(),
    );
    _prefixController = TextEditingController(
      text: config.export.defaultPrefix,
    );
    _selectedFormat = config.export.defaultFormat;
    
    // 初始化快捷键
    _toggleModeShortcut = config.shortcuts.toggleMode;
    _deleteLineShortcut = config.shortcuts.deleteLine;
    _undoShortcut = config.shortcuts.undo;
    _redoShortcut = config.shortcuts.redo;
  }

  @override
  void dispose() {
    _rowsController.dispose();
    _colsController.dispose();
    _prefixController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final rows = int.tryParse(_rowsController.text) ?? 3;
    final cols = int.tryParse(_colsController.text) ?? 3;
    
    await _configService.setDefaultRows(rows.clamp(1, 20));
    await _configService.setDefaultCols(cols.clamp(1, 20));
    await _configService.setDefaultExportPrefix(_prefixController.text.trim());
    await _configService.setDefaultExportFormat(_selectedFormat);
    
    // 保存快捷键
    await _configService.setToggleModeShortcut(_toggleModeShortcut);
    await _configService.setDeleteLineShortcut(_deleteLineShortcut);
    await _configService.setUndoShortcut(_undoShortcut);
    await _configService.setRedoShortcut(_redoShortcut);
    
    if (mounted) {
      Navigator.of(context).pop();
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('设置已保存'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    }
  }

  Future<void> _resetToDefaults() async {
    await _configService.resetToDefaults();
    
    // 更新 UI
    final config = _configService.config;
    setState(() {
      _rowsController.text = config.grid.defaultRows.toString();
      _colsController.text = config.grid.defaultCols.toString();
      _prefixController.text = config.export.defaultPrefix;
      _selectedFormat = config.export.defaultFormat;
      _toggleModeShortcut = config.shortcuts.toggleMode;
      _deleteLineShortcut = config.shortcuts.deleteLine;
      _undoShortcut = config.shortcuts.undo;
      _redoShortcut = config.shortcuts.redo;
    });
    
    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('已恢复默认设置'),
          severity: InfoBarSeverity.info,
          onClose: close,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: Row(
        children: [
          Icon(FluentIcons.settings, color: theme.accentColor),
          const SizedBox(width: 8),
          const Text('设置'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 网格默认值
            _buildSectionHeader(theme, '网格默认值', FluentIcons.grid_view_medium),
            const SizedBox(height: 12),
            _buildGridSettings(theme),
            
            const SizedBox(height: 24),
            
            // 导出设置
            _buildSectionHeader(theme, '导出设置', FluentIcons.save),
            const SizedBox(height: 12),
            _buildExportSettings(theme),
            
            const SizedBox(height: 24),
            
            // 快捷键
            _buildSectionHeader(theme, '快捷键', FluentIcons.keyboard_classic),
            const SizedBox(height: 8),
            Text(
              '点击快捷键进行修改，按 ESC 取消',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildShortcutsSection(theme),
            
            const SizedBox(height: 24),
            
            // 配置文件信息
            _buildConfigFileInfo(theme),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: _resetToDefaults,
          child: const Text('恢复默认'),
        ),
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saveSettings,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(FluentThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.accentColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.typography.bodyStrong,
        ),
      ],
    );
  }

  Widget _buildGridSettings(FluentThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: InfoLabel(
            label: '默认行数',
            child: NumberBox<int>(
              value: int.tryParse(_rowsController.text),
              min: 1,
              max: 20,
              mode: SpinButtonPlacementMode.inline,
              onChanged: (value) {
                if (value != null) {
                  _rowsController.text = value.toString();
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InfoLabel(
            label: '默认列数',
            child: NumberBox<int>(
              value: int.tryParse(_colsController.text),
              min: 1,
              max: 20,
              mode: SpinButtonPlacementMode.inline,
              onChanged: (value) {
                if (value != null) {
                  _colsController.text = value.toString();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExportSettings(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoLabel(
          label: '默认文件前缀',
          child: TextBox(
            controller: _prefixController,
            placeholder: '留空则不添加前缀',
          ),
        ),
        const SizedBox(height: 12),
        InfoLabel(
          label: '默认导出格式',
          child: ComboBox<String>(
            value: _selectedFormat,
            items: const [
              ComboBoxItem(value: 'png', child: Text('PNG')),
              ComboBoxItem(value: 'jpg', child: Text('JPG')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedFormat = value);
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        // 显示上次导出目录
        if (_configService.lastExportDirectory != null) ...[
          Text(
            '上次导出目录',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.resources.cardBackgroundFillColorDefault,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.resources.dividerStrokeColorDefault,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  FluentIcons.folder,
                  size: 14,
                  color: theme.resources.textFillColorSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _configService.lastExportDirectory!,
                    style: theme.typography.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildShortcutsSection(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.resources.dividerStrokeColorDefault,
        ),
      ),
      child: Column(
        children: [
          _ShortcutEditRow(
            action: '切换模式',
            shortcut: _toggleModeShortcut,
            onChanged: (value) => setState(() => _toggleModeShortcut = value),
          ),
          const Divider(style: DividerThemeData(horizontalMargin: EdgeInsets.symmetric(vertical: 8))),
          _ShortcutEditRow(
            action: '删除线条',
            shortcut: _deleteLineShortcut,
            onChanged: (value) => setState(() => _deleteLineShortcut = value),
          ),
          const Divider(style: DividerThemeData(horizontalMargin: EdgeInsets.symmetric(vertical: 8))),
          _ShortcutEditRow(
            action: '撤销',
            shortcut: _undoShortcut,
            onChanged: (value) => setState(() => _undoShortcut = value),
          ),
          const Divider(style: DividerThemeData(horizontalMargin: EdgeInsets.symmetric(vertical: 8))),
          _ShortcutEditRow(
            action: '重做',
            shortcut: _redoShortcut,
            onChanged: (value) => setState(() => _redoShortcut = value),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigFileInfo(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.resources.subtleFillColorTertiary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.info,
            size: 14,
            color: theme.resources.textFillColorSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '配置文件位置',
                  style: theme.typography.caption?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _configService.configFilePath ?? '未知',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                    fontFamily: 'Consolas',
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 快捷键编辑行
class _ShortcutEditRow extends StatefulWidget {
  final String action;
  final String shortcut;
  final ValueChanged<String> onChanged;

  const _ShortcutEditRow({
    required this.action,
    required this.shortcut,
    required this.onChanged,
  });

  @override
  State<_ShortcutEditRow> createState() => _ShortcutEditRowState();
}

class _ShortcutEditRowState extends State<_ShortcutEditRow> {
  bool _isEditing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 监听焦点变化，失去焦点时取消编辑
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        setState(() => _isEditing = false);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _isEditing = true);
    _focusNode.requestFocus();
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);
    // 不要让焦点离开，避免触发其他事件
    _focusNode.unfocus();
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (!_isEditing) return KeyEventResult.ignored;
    
    // 编辑模式下，所有按键事件都要处理，防止冒泡
    if (event is! KeyDownEvent) return KeyEventResult.handled;

    // ESC 取消编辑 - 必须返回 handled 阻止事件冒泡到对话框
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancelEditing();
      return KeyEventResult.handled;
    }

    // 构建快捷键字符串
    final parts = <String>[];
    
    if (HardwareKeyboard.instance.isControlPressed) {
      parts.add('Ctrl');
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      parts.add('Shift');
    }
    if (HardwareKeyboard.instance.isAltPressed) {
      parts.add('Alt');
    }
    
    // 获取按键名称
    final keyLabel = _getKeyLabel(event.logicalKey);
    if (keyLabel != null && !_isModifierKey(event.logicalKey)) {
      parts.add(keyLabel);
      
      // 完成编辑
      final shortcut = parts.join('+');
      widget.onChanged(shortcut);
      setState(() => _isEditing = false);
    }
    
    return KeyEventResult.handled;
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  String? _getKeyLabel(LogicalKeyboardKey key) {
    // 特殊按键映射
    final specialKeys = {
      LogicalKeyboardKey.delete: 'Delete',
      LogicalKeyboardKey.backspace: 'Backspace',
      LogicalKeyboardKey.enter: 'Enter',
      LogicalKeyboardKey.tab: 'Tab',
      LogicalKeyboardKey.space: 'Space',
      LogicalKeyboardKey.arrowUp: 'Up',
      LogicalKeyboardKey.arrowDown: 'Down',
      LogicalKeyboardKey.arrowLeft: 'Left',
      LogicalKeyboardKey.arrowRight: 'Right',
      LogicalKeyboardKey.home: 'Home',
      LogicalKeyboardKey.end: 'End',
      LogicalKeyboardKey.pageUp: 'PageUp',
      LogicalKeyboardKey.pageDown: 'PageDown',
      LogicalKeyboardKey.insert: 'Insert',
      LogicalKeyboardKey.f1: 'F1',
      LogicalKeyboardKey.f2: 'F2',
      LogicalKeyboardKey.f3: 'F3',
      LogicalKeyboardKey.f4: 'F4',
      LogicalKeyboardKey.f5: 'F5',
      LogicalKeyboardKey.f6: 'F6',
      LogicalKeyboardKey.f7: 'F7',
      LogicalKeyboardKey.f8: 'F8',
      LogicalKeyboardKey.f9: 'F9',
      LogicalKeyboardKey.f10: 'F10',
      LogicalKeyboardKey.f11: 'F11',
      LogicalKeyboardKey.f12: 'F12',
    };

    if (specialKeys.containsKey(key)) {
      return specialKeys[key];
    }

    // 字母和数字键
    final keyLabel = key.keyLabel;
    if (keyLabel.isNotEmpty && keyLabel.length == 1) {
      return keyLabel.toUpperCase();
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.action, style: theme.typography.body),
        Focus(
          focusNode: _focusNode,
          onKeyEvent: (node, event) => _handleKeyEvent(event),
          child: GestureDetector(
            onTap: _startEditing,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              constraints: const BoxConstraints(minWidth: 80),
              decoration: BoxDecoration(
                color: _isEditing
                    ? theme.accentColor.withOpacity(0.1)
                    : theme.resources.subtleFillColorSecondary,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _isEditing
                      ? theme.accentColor
                      : Colors.transparent,
                  width: _isEditing ? 2 : 1,
                ),
              ),
              child: Text(
                _isEditing ? '请按键...' : widget.shortcut,
                textAlign: TextAlign.center,
                style: theme.typography.caption?.copyWith(
                  fontFamily: 'Consolas',
                  fontWeight: FontWeight.w600,
                  color: _isEditing
                      ? theme.accentColor
                      : theme.resources.textFillColorPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

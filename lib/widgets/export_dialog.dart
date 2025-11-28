import 'package:fluent_ui/fluent_ui.dart';
import 'package:file_picker/file_picker.dart';

import '../services/config_service.dart';

/// 导出设置结果
class ExportSettings {
  /// 输出目录
  final String outputDir;

  /// 文件前缀
  final String prefix;

  /// 导出格式 (png, jpg, webp)
  final String format;

  ExportSettings({
    required this.outputDir,
    required this.prefix,
    required this.format,
  });
}

/// 导出设置对话框
class ExportDialog extends StatefulWidget {
  /// 原图文件名（用于生成默认前缀）
  final String? sourceFileName;

  /// 已选中的切片数量
  final int selectedCount;

  const ExportDialog({
    super.key,
    this.sourceFileName,
    required this.selectedCount,
  });

  /// 显示导出对话框
  /// 返回 ExportSettings 如果用户确认，返回 null 如果用户取消
  static Future<ExportSettings?> show(
    BuildContext context, {
    String? sourceFileName,
    required int selectedCount,
  }) async {
    return await showDialog<ExportSettings>(
      context: context,
      builder: (context) => ExportDialog(
        sourceFileName: sourceFileName,
        selectedCount: selectedCount,
      ),
    );
  }

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  final TextEditingController _prefixController = TextEditingController();
  String? _outputDir;
  String _selectedFormat = 'png';
  bool _isSelectingDir = false;

  @override
  void initState() {
    super.initState();
    final config = ConfigService.instance.config;
    
    // 使用配置的默认前缀，如果为空则使用源文件名
    if (config.export.defaultPrefix.isNotEmpty) {
      _prefixController.text = config.export.defaultPrefix;
    } else if (widget.sourceFileName != null) {
      final name = widget.sourceFileName!;
      final dotIndex = name.lastIndexOf('.');
      _prefixController.text = dotIndex > 0 ? name.substring(0, dotIndex) : name;
    }
    
    // 使用配置的默认格式
    _selectedFormat = config.export.defaultFormat;
    
    // 从配置中读取上次导出目录
    _outputDir = ConfigService.instance.lastExportDirectory;
  }

  @override
  void dispose() {
    _prefixController.dispose();
    super.dispose();
  }

  Future<void> _selectOutputDir() async {
    setState(() => _isSelectingDir = true);

    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择输出目录',
      );

      if (result != null) {
        setState(() => _outputDir = result);
      }
    } finally {
      setState(() => _isSelectingDir = false);
    }
  }

  void _confirm() {
    if (_outputDir == null) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('请选择输出目录'),
          severity: InfoBarSeverity.warning,
          onClose: close,
        ),
      );
      return;
    }

    Navigator.of(context).pop(ExportSettings(
      outputDir: _outputDir!,
      prefix: _prefixController.text.trim(),
      format: _selectedFormat,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: const Text('导出设置'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 选中数量提示
          InfoBar(
            title: Text('将导出 ${widget.selectedCount} 个切片'),
            severity: InfoBarSeverity.info,
          ),
          const SizedBox(height: 16),

          // 输出目录
          Text(
            '输出目录',
            style: theme.typography.body?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.resources.cardBackgroundFillColorDefault,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: theme.resources.dividerStrokeColorDefault,
                    ),
                  ),
                  child: Text(
                    _outputDir ?? '未选择',
                    style: theme.typography.body?.copyWith(
                      color: _outputDir == null
                          ? theme.resources.textFillColorTertiary
                          : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: _isSelectingDir ? null : _selectOutputDir,
                child: _isSelectingDir
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : const Text('浏览...'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 文件前缀
          Text(
            '文件前缀（可选）',
            style: theme.typography.body?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextBox(
            controller: _prefixController,
            placeholder: '留空则不添加前缀',
          ),
          const SizedBox(height: 16),

          // 导出格式
          Text(
            '导出格式',
            style: theme.typography.body?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ComboBox<String>(
            value: _selectedFormat,
            items: const [
              ComboBoxItem(value: 'png', child: Text('PNG - 无损压缩')),
              ComboBoxItem(value: 'jpg', child: Text('JPG - 有损压缩，文件小')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedFormat = value);
              }
            },
          ),
          const SizedBox(height: 16),

          // 文件名预览
          Text(
            '文件名格式预览：',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _prefixController.text.trim().isEmpty
                ? '1_1.$_selectedFormat, 1_2.$_selectedFormat, ...'
                : '${_prefixController.text.trim()}_1_1.$_selectedFormat, ${_prefixController.text.trim()}_1_2.$_selectedFormat, ...',
            style: theme.typography.caption?.copyWith(
              fontFamily: 'Consolas',
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('导出'),
        ),
      ],
    );
  }
}

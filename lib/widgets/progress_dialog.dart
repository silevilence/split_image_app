import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';

import '../utils/image_processor.dart';

/// 导出进度对话框
class ProgressDialog extends StatefulWidget {
  /// 进度流
  final Stream<ExportProgress> progressStream;

  /// 导出完成回调
  final VoidCallback? onComplete;

  /// 输出目录（用于打开文件夹）
  final String outputDir;

  const ProgressDialog({
    super.key,
    required this.progressStream,
    required this.outputDir,
    this.onComplete,
  });

  /// 显示进度对话框
  static Future<void> show(
    BuildContext context, {
    required Stream<ExportProgress> progressStream,
    required String outputDir,
    VoidCallback? onComplete,
  }) async {
    await showDialog(
      context: context,
      dismissWithEsc: false,
      builder: (context) => ProgressDialog(
        progressStream: progressStream,
        outputDir: outputDir,
        onComplete: onComplete,
      ),
    );
  }

  @override
  State<ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<ProgressDialog> {
  ExportProgress? _progress;
  bool _isComplete = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _listenProgress();
  }

  void _listenProgress() {
    widget.progressStream.listen(
      (progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _isComplete = progress.isComplete;
            _error = progress.error;
          });

          if (progress.isComplete) {
            widget.onComplete?.call();
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = error.toString();
          });
        }
      },
    );
  }

  void _openOutputDir() async {
    // 使用 Windows 资源管理器打开文件夹
    final uri = Uri.directory(widget.outputDir);
    // 使用 Process.run 打开文件夹
    await Process.run('explorer', [widget.outputDir]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: Text(_isComplete ? '导出完成' : (_error != null ? '导出失败' : '正在导出...')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            // 错误状态
            Icon(
              FluentIcons.error,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: theme.typography.body?.copyWith(
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
          ] else if (_isComplete) ...[
            // 完成状态
            Icon(
              FluentIcons.check_mark,
              size: 48,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              '成功导出 ${_progress?.total ?? 0} 个切片',
              style: theme.typography.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.outputDir,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ] else ...[
            // 进度状态
            const SizedBox(height: 8),
            ProgressBar(
              value: (_progress?.progress ?? 0) * 100,
            ),
            const SizedBox(height: 12),
            Text(
              '正在处理: ${(_progress?.current ?? 0) + 1} / ${_progress?.total ?? 0}',
              style: theme.typography.body,
              textAlign: TextAlign.center,
            ),
            if (_progress?.currentFile != null) ...[
              const SizedBox(height: 4),
              Text(
                _progress!.currentFile!,
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                  fontFamily: 'Consolas',
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ],
      ),
      actions: [
        if (_isComplete) ...[
          Button(
            onPressed: _openOutputDir,
            child: const Text('打开文件夹'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
        ] else if (_error != null) ...[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
        // 导出过程中不显示按钮，防止用户中断
      ],
    );
  }
}

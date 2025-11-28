import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'providers/editor_provider.dart';
import 'providers/preview_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器
  await windowManager.ensureInitialized();

  // 配置窗口选项
  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(960, 640),
    center: true,
    backgroundColor: Color(0x00000000),
    titleBarStyle: TitleBarStyle.hidden,
    title: 'SmartGridSlicer',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const SmartGridSlicerApp());
}

class SmartGridSlicerApp extends StatelessWidget {
  const SmartGridSlicerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EditorProvider()),
        ChangeNotifierProvider(create: (_) => PreviewProvider()),
      ],
      child: FluentApp(
        title: 'SmartGridSlicer',
        debugShowCheckedModeBanner: false,
        // 主题配置
        theme: FluentThemeData(
          brightness: Brightness.light,
          accentColor: Colors.orange,
          visualDensity: VisualDensity.standard,
        ),
        darkTheme: FluentThemeData(
          brightness: Brightness.dark,
          accentColor: Colors.orange,
          visualDensity: VisualDensity.standard,
        ),
        themeMode: ThemeMode.system,
        home: const _MainWindow(),
      ),
    );
  }
}

/// 主窗口 - 包含可拖拽标题栏
class _MainWindow extends StatelessWidget {
  const _MainWindow();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        // 自定义标题栏 (支持窗口拖拽)
        _TitleBar(),
        // 主内容
        Expanded(child: HomeScreen()),
      ],
    );
  }
}

/// 自定义标题栏
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 32,
        color: theme.micaBackgroundColor,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              FluentIcons.grid_view_medium,
              size: 16,
              color: theme.accentColor,
            ),
            const SizedBox(width: 8),
            Text(
              'SmartGridSlicer',
              style: theme.typography.caption?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // 窗口控制按钮
            _WindowButton(
              icon: FluentIcons.chrome_minimize,
              onPressed: windowManager.minimize,
            ),
            _WindowButton(
              icon: FluentIcons.checkbox,
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _WindowButton(
              icon: FluentIcons.chrome_close,
              isClose: true,
              onPressed: windowManager.close,
            ),
          ],
        ),
      ),
    );
  }
}

/// 窗口控制按钮
class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 32,
          color: _isHovered
              ? (widget.isClose ? Colors.red : theme.resources.subtleFillColorSecondary)
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 10,
            color: _isHovered && widget.isClose
                ? Colors.white
                : theme.resources.textFillColorPrimary,
          ),
        ),
      ),
    );
  }
}


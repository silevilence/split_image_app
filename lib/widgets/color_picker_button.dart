import 'dart:math' as math;
import 'package:fluent_ui/fluent_ui.dart';

/// 颜色选择按钮组件
///
/// 点击后弹出颜色选择器，支持 HSV 选择和自定义输入。
class ColorPickerButton extends StatefulWidget {
  /// 当前颜色值 (ARGB int)
  final int value;

  /// 颜色变更回调
  final ValueChanged<int>? onChanged;

  /// 是否显示透明度选项
  final bool showAlpha;

  const ColorPickerButton({
    super.key,
    required this.value,
    this.onChanged,
    this.showAlpha = true,
  });

  @override
  State<ColorPickerButton> createState() => _ColorPickerButtonState();
}

class _ColorPickerButtonState extends State<ColorPickerButton> {
  final _flyoutController = FlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final hasAlpha = ((widget.value >> 24) & 0xFF) < 255;

    return FlyoutTarget(
      controller: _flyoutController,
      child: Button(
        onPressed: _showColorPicker,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 颜色预览方块
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: theme.resources.dividerStrokeColorDefault,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: CustomPaint(
                  painter: hasAlpha ? _CheckerPainter() : null,
                  child: Container(color: Color(widget.value)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 颜色值文本
            Text(_colorToHex(widget.value), style: theme.typography.caption),
            const SizedBox(width: 4),
            const Icon(FluentIcons.chevron_down, size: 12),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    _flyoutController.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      builder: (context) {
        return _ColorPickerFlyout(
          initialColor: widget.value,
          showAlpha: widget.showAlpha,
          onColorSelected: (color) {
            widget.onChanged?.call(color);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  String _colorToHex(int color) {
    if (widget.showAlpha) {
      return '#${color.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    } else {
      return '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }
  }
}

/// 颜色选择器弹出面板
class _ColorPickerFlyout extends StatefulWidget {
  final int initialColor;
  final bool showAlpha;
  final ValueChanged<int> onColorSelected;

  const _ColorPickerFlyout({
    required this.initialColor,
    required this.showAlpha,
    required this.onColorSelected,
  });

  @override
  State<_ColorPickerFlyout> createState() => _ColorPickerFlyoutState();
}

class _ColorPickerFlyoutState extends State<_ColorPickerFlyout> {
  // HSV 值
  late double _hue; // 0-360
  late double _saturation; // 0-1
  late double _value; // 0-1
  late int _alpha; // 0-255

  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _alpha = (widget.initialColor >> 24) & 0xFF;
    final hsv = _rgbToHsv(widget.initialColor);
    _hue = hsv.$1;
    _saturation = hsv.$2;
    _value = hsv.$3;
    _hexController = TextEditingController(text: _colorToHex(_currentColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  int get _currentColor {
    final rgb = _hsvToRgb(_hue, _saturation, _value);
    return (_alpha << 24) | (rgb & 0x00FFFFFF);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      width: 300,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.menuColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          Text('选择颜色', style: theme.typography.bodyStrong),
          const SizedBox(height: 12),

          // 饱和度-亮度选择区
          _buildSaturationValuePicker(theme),
          const SizedBox(height: 12),

          // 色相滑块
          _buildHueSlider(theme),
          const SizedBox(height: 12),

          // Alpha 滑块
          if (widget.showAlpha) ...[
            _buildAlphaSlider(theme),
            const SizedBox(height: 12),
          ],

          // 当前颜色预览 + Hex 输入
          _buildColorPreviewAndInput(theme),
          const SizedBox(height: 12),

          // 确认按钮
          FilledButton(
            onPressed: () => widget.onColorSelected(_currentColor),
            child: const Center(child: Text('确定')),
          ),
        ],
      ),
    );
  }

  /// 饱和度-亮度选择区
  Widget _buildSaturationValuePicker(FluentThemeData theme) {
    return SizedBox(
      height: 150,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onPanStart: (details) =>
                _updateSaturationValue(details.localPosition, constraints),
            onPanUpdate: (details) =>
                _updateSaturationValue(details.localPosition, constraints),
            child: CustomPaint(
              painter: _SaturationValuePainter(hue: _hue),
              child: Stack(
                children: [
                  // 选择器指示圆点
                  Positioned(
                    left: _saturation * constraints.maxWidth - 8,
                    top: (1 - _value) * constraints.maxHeight - 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _updateSaturationValue(Offset position, BoxConstraints constraints) {
    setState(() {
      _saturation = (position.dx / constraints.maxWidth).clamp(0.0, 1.0);
      _value = 1 - (position.dy / constraints.maxHeight).clamp(0.0, 1.0);
      _hexController.text = _colorToHex(_currentColor);
    });
  }

  /// 色相滑块
  Widget _buildHueSlider(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('色相', style: theme.typography.caption),
        const SizedBox(height: 4),
        SizedBox(
          height: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onPanStart: (details) =>
                    _updateHue(details.localPosition.dx, constraints.maxWidth),
                onPanUpdate: (details) =>
                    _updateHue(details.localPosition.dx, constraints.maxWidth),
                child: CustomPaint(
                  painter: _HueSliderPainter(),
                  child: Stack(
                    children: [
                      Positioned(
                        left: (_hue / 360) * constraints.maxWidth - 4,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _updateHue(double x, double width) {
    setState(() {
      _hue = ((x / width) * 360).clamp(0.0, 360.0);
      _hexController.text = _colorToHex(_currentColor);
    });
  }

  /// Alpha 滑块
  Widget _buildAlphaSlider(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('透明度', style: theme.typography.caption),
            Text('$_alpha', style: theme.typography.caption),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onPanStart: (details) => _updateAlpha(
                  details.localPosition.dx,
                  constraints.maxWidth,
                ),
                onPanUpdate: (details) => _updateAlpha(
                  details.localPosition.dx,
                  constraints.maxWidth,
                ),
                child: CustomPaint(
                  painter: _AlphaSliderPainter(
                    color: _hsvToRgb(_hue, _saturation, _value),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: (_alpha / 255) * constraints.maxWidth - 4,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _updateAlpha(double x, double width) {
    setState(() {
      _alpha = ((x / width) * 255).round().clamp(0, 255);
      _hexController.text = _colorToHex(_currentColor);
    });
  }

  /// 颜色预览和 Hex 输入
  Widget _buildColorPreviewAndInput(FluentThemeData theme) {
    final hasAlpha = _alpha < 255;

    return Row(
      children: [
        // 颜色预览
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.resources.dividerStrokeColorDefault,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                if (hasAlpha) CustomPaint(painter: _CheckerPainter()),
                Container(color: Color(_currentColor)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Hex 输入
        Expanded(
          child: TextBox(
            controller: _hexController,
            placeholder: widget.showAlpha ? '#AARRGGBB' : '#RRGGBB',
            onChanged: _onHexChanged,
          ),
        ),
      ],
    );
  }

  void _onHexChanged(String value) {
    String hex = value.trim();
    if (hex.startsWith('#')) {
      hex = hex.substring(1);
    }

    int? parsed;
    if (hex.length == 6) {
      parsed = int.tryParse('FF$hex', radix: 16);
    } else if (hex.length == 8) {
      parsed = int.tryParse(hex, radix: 16);
    }

    if (parsed != null) {
      setState(() {
        _alpha = (parsed! >> 24) & 0xFF;
        final hsv = _rgbToHsv(parsed);
        _hue = hsv.$1;
        _saturation = hsv.$2;
        _value = hsv.$3;
      });
    }
  }

  String _colorToHex(int color) {
    if (widget.showAlpha) {
      return '#${color.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    } else {
      return '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }
  }

  /// RGB 转 HSV
  (double, double, double) _rgbToHsv(int rgb) {
    final r = ((rgb >> 16) & 0xFF) / 255;
    final g = ((rgb >> 8) & 0xFF) / 255;
    final b = (rgb & 0xFF) / 255;

    final maxVal = math.max(r, math.max(g, b));
    final minVal = math.min(r, math.min(g, b));
    final delta = maxVal - minVal;

    double h = 0;
    if (delta != 0) {
      if (maxVal == r) {
        h = 60 * (((g - b) / delta) % 6);
      } else if (maxVal == g) {
        h = 60 * (((b - r) / delta) + 2);
      } else {
        h = 60 * (((r - g) / delta) + 4);
      }
    }
    if (h < 0) {
      h += 360;
    }

    final s = maxVal == 0 ? 0.0 : delta / maxVal;
    final v = maxVal;

    return (h, s, v);
  }

  /// HSV 转 RGB
  int _hsvToRgb(double h, double s, double v) {
    final c = v * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = v - c;

    double r, g, b;
    if (h < 60) {
      r = c;
      g = x;
      b = 0;
    } else if (h < 120) {
      r = x;
      g = c;
      b = 0;
    } else if (h < 180) {
      r = 0;
      g = c;
      b = x;
    } else if (h < 240) {
      r = 0;
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      g = 0;
      b = c;
    } else {
      r = c;
      g = 0;
      b = x;
    }

    final ri = ((r + m) * 255).round();
    final gi = ((g + m) * 255).round();
    final bi = ((b + m) * 255).round();

    return 0xFF000000 | (ri << 16) | (gi << 8) | bi;
  }
}

/// 饱和度-亮度选择区绘制器
class _SaturationValuePainter extends CustomPainter {
  final double hue;

  _SaturationValuePainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    // 底色（纯色相）
    final baseColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();

    // 绘制饱和度渐变（从白色到纯色）
    final saturationGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Colors.white, baseColor],
    );

    // 绘制亮度渐变（从透明到黑色）
    const valueGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x00000000), Color(0xFF000000)],
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    canvas.save();
    canvas.clipRRect(rrect);

    // 先绘制饱和度
    canvas.drawRect(
      rect,
      Paint()..shader = saturationGradient.createShader(rect),
    );
    // 再叠加亮度
    canvas.drawRect(rect, Paint()..shader = valueGradient.createShader(rect));

    canvas.restore();

    // 边框
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x33000000),
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}

/// 色相滑块绘制器
class _HueSliderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    // 色相渐变
    const gradient = LinearGradient(
      colors: [
        Color(0xFFFF0000), // 0°
        Color(0xFFFFFF00), // 60°
        Color(0xFF00FF00), // 120°
        Color(0xFF00FFFF), // 180°
        Color(0xFF0000FF), // 240°
        Color(0xFFFF00FF), // 300°
        Color(0xFFFF0000), // 360°
      ],
    );

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    canvas.restore();

    // 边框
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x33000000),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Alpha 滑块绘制器
class _AlphaSliderPainter extends CustomPainter {
  final int color;

  _AlphaSliderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    canvas.save();
    canvas.clipRRect(rrect);

    // 棋盘格背景
    _drawChecker(canvas, size);

    // Alpha 渐变
    final opaqueColor = Color(color | 0xFF000000);
    final gradient = LinearGradient(
      colors: [opaqueColor.withValues(alpha: 0), opaqueColor],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    canvas.restore();

    // 边框
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x33000000),
    );
  }

  void _drawChecker(Canvas canvas, Size size) {
    const cellSize = 5.0;
    final lightPaint = Paint()..color = const Color(0xFFCCCCCC);
    final darkPaint = Paint()..color = const Color(0xFF999999);

    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final isLight = ((x ~/ cellSize) + (y ~/ cellSize)) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          isLight ? lightPaint : darkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AlphaSliderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// 棋盘格绘制器（用于表示透明色）
class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 6.0;
    final lightPaint = Paint()..color = const Color(0xFFCCCCCC);
    final darkPaint = Paint()..color = const Color(0xFF999999);

    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final isLight = ((x ~/ cellSize) + (y ~/ cellSize)) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          isLight ? lightPaint : darkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show PopupMenuEntry, PopupMenuItem, PopupMenuDivider, showMenu, RelativeRect;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/editor_provider.dart';
import '../utils/coordinate_utils.dart';
import 'grid_painter.dart';

/// 编辑器画布组件
/// 显示图片和网格覆盖层，支持缩放、平移和网格线拖拽
class EditorCanvas extends StatefulWidget {
  const EditorCanvas({super.key});

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  final TransformationController _transformationController =
      TransformationController();
  
  // Focus node for keyboard events
  final FocusNode _focusNode = FocusNode();

  // 拖拽状态
  int? _hoveredHorizontalIndex;
  int? _hoveredVerticalIndex;
  int? _draggingHorizontalIndex;
  int? _draggingVerticalIndex;
  bool _isDragging = false;
  
  // 记录按下时的位置，用于区分点击和拖拽
  Offset? _pointerDownPosition;
  static const double _dragThreshold = 5.0; // 拖拽阈值

  @override
  void dispose() {
    _transformationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 重置缩放
  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  /// 检测鼠标是否悬停在网格线上
  void _checkLineHover(Offset localPosition, Size renderSize, EditorProvider provider) {
    if (provider.imageSize == null || _isDragging) return;

    int? newHoveredH;
    int? newHoveredV;

    // 检测水平线
    for (int i = 0; i < provider.horizontalLines.length; i++) {
      final lineY = renderSize.height * provider.horizontalLines[i];
      if (CoordinateUtils.isNearLine(localPosition, lineY, true, threshold: 8.0)) {
        newHoveredH = i;
        break;
      }
    }

    // 检测垂直线
    for (int i = 0; i < provider.verticalLines.length; i++) {
      final lineX = renderSize.width * provider.verticalLines[i];
      if (CoordinateUtils.isNearLine(localPosition, lineX, false, threshold: 8.0)) {
        newHoveredV = i;
        break;
      }
    }

    if (newHoveredH != _hoveredHorizontalIndex ||
        newHoveredV != _hoveredVerticalIndex) {
      setState(() {
        _hoveredHorizontalIndex = newHoveredH;
        _hoveredVerticalIndex = newHoveredV;
      });
    }
  }

  /// 检测点击位置是否在某条线上，返回线索引和类型
  (int?, bool?) _detectLineAtPosition(Offset localPosition, Size renderSize, EditorProvider provider) {
    // 检测水平线
    for (int i = 0; i < provider.horizontalLines.length; i++) {
      final lineY = renderSize.height * provider.horizontalLines[i];
      if (CoordinateUtils.isNearLine(localPosition, lineY, true, threshold: 8.0)) {
        return (i, true);
      }
    }

    // 检测垂直线
    for (int i = 0; i < provider.verticalLines.length; i++) {
      final lineX = renderSize.width * provider.verticalLines[i];
      if (CoordinateUtils.isNearLine(localPosition, lineX, false, threshold: 8.0)) {
        return (i, false);
      }
    }

    return (null, null);
  }

  /// 处理指针按下
  void _handlePointerDown(PointerDownEvent event, Size renderSize, EditorProvider provider) {
    _pointerDownPosition = event.localPosition;
    
    if (event.buttons == 1) {
      // 左键按下：记录位置，检测是否在线上
      final (lineIndex, isHorizontal) = _detectLineAtPosition(event.localPosition, renderSize, provider);
      if (lineIndex != null && isHorizontal != null) {
        // 在线上按下，准备拖拽
        setState(() {
          if (isHorizontal) {
            _draggingHorizontalIndex = lineIndex;
          } else {
            _draggingVerticalIndex = lineIndex;
          }
        });
      }
    }
  }

  /// 处理指针移动
  void _handlePointerMove(PointerMoveEvent event, Size renderSize, EditorProvider provider) {
    if (_pointerDownPosition == null) return;
    
    final distance = (event.localPosition - _pointerDownPosition!).distance;
    
    // 如果移动距离超过阈值，开始拖拽
    if (!_isDragging && distance > _dragThreshold) {
      if (_draggingHorizontalIndex != null || _draggingVerticalIndex != null) {
        // 拖拽开始时保存历史记录
        provider.beginEdit();
        setState(() {
          _isDragging = true;
        });
      }
    }
    
    // 更新拖拽位置
    if (_isDragging && provider.imageSize != null) {
      if (_draggingHorizontalIndex != null) {
        final newPosition = (event.localPosition.dy / renderSize.height).clamp(0.0, 1.0);
        provider.updateGridLine(_draggingHorizontalIndex!, newPosition, true);
      } else if (_draggingVerticalIndex != null) {
        final newPosition = (event.localPosition.dx / renderSize.width).clamp(0.0, 1.0);
        provider.updateGridLine(_draggingVerticalIndex!, newPosition, false);
      }
    }
  }

  /// 处理指针抬起
  void _handlePointerUp(PointerUpEvent event, Size renderSize, EditorProvider provider) {
    final wasDragging = _isDragging;
    final hadLine = _draggingHorizontalIndex != null || _draggingVerticalIndex != null;
    
    // 如果没有拖拽，当作点击处理
    if (!wasDragging && _pointerDownPosition != null) {
      final distance = (event.localPosition - _pointerDownPosition!).distance;
      if (distance <= _dragThreshold) {
        // 这是一次点击
        _handleClick(event.localPosition, renderSize, provider);
      }
    }
    
    // 拖拽结束，调用 endEdit
    if (wasDragging) {
      provider.endEdit();
    }
    
    // 重置状态
    setState(() {
      _isDragging = false;
      _draggingHorizontalIndex = null;
      _draggingVerticalIndex = null;
      _pointerDownPosition = null;
    });
  }

  /// 处理点击（非拖拽）
  void _handleClick(Offset position, Size renderSize, EditorProvider provider) {
    final (lineIndex, isHorizontal) = _detectLineAtPosition(position, renderSize, provider);
    
    if (lineIndex != null && isHorizontal != null) {
      // 点击在线上，选中该线
      provider.selectLine(lineIndex, isHorizontal);
      _focusNode.requestFocus();
    } else {
      // 点击在空白处，取消选中
      provider.clearSelection();
    }
  }

  /// 显示右键菜单
  void _showContextMenu(BuildContext context, Offset position, Size renderSize, EditorProvider provider) {
    final (lineIndex, isHorizontal) = _detectLineAtPosition(position, renderSize, provider);
    
    // 计算菜单显示位置（转换为全局坐标）
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final globalPosition = renderBox.localToGlobal(position);
    
    // 构建菜单项
    final menuItems = <MenuFlyoutItemBase>[];
    
    if (lineIndex != null && isHorizontal != null) {
      // 在线上右键
      provider.selectLine(lineIndex, isHorizontal);
      final lineType = isHorizontal ? '水平线' : '垂直线';
      final linePos = isHorizontal 
          ? provider.horizontalLines[lineIndex] 
          : provider.verticalLines[lineIndex];
      
      menuItems.addAll([
        MenuFlyoutItem(
          leading: const Icon(FluentIcons.info, size: 14),
          text: Text('$lineType (${(linePos * 100).toStringAsFixed(0)}%)'),
          onPressed: () {},
        ),
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
          leading: const Icon(FluentIcons.delete, size: 14),
          text: const Text('删除此线'),
          onPressed: () {
            provider.deleteSelectedLine();
            displayInfoBar(
              context,
              builder: (ctx, close) => const InfoBar(
                title: Text('已删除网格线'),
                severity: InfoBarSeverity.success,
              ),
              duration: const Duration(seconds: 1),
            );
          },
        ),
      ]);
    } else {
      // 在空白处右键
      final relativePos = Offset(
        position.dx / renderSize.width,
        position.dy / renderSize.height,
      );
      
      menuItems.addAll([
        MenuFlyoutItem(
          leading: const Icon(FluentIcons.remove, size: 14),
          text: const Text('添加水平线'),
          onPressed: () {
            provider.addHorizontalLine(relativePos.dy);
          },
        ),
        MenuFlyoutItem(
          leading: const Icon(FluentIcons.separator, size: 14),
          text: const Text('添加垂直线'),
          onPressed: () {
            provider.addVerticalLine(relativePos.dx);
          },
        ),
      ]);
    }
    
    // 显示菜单
    final theme = FluentTheme.of(context);
    showMenu<String>(
      context: context,
      color: theme.menuColor.withOpacity(1.0),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      elevation: 8,
      items: menuItems.map((item) {
        if (item is MenuFlyoutItem) {
          return PopupMenuItem<String>(
            onTap: item.onPressed,
            child: Row(
              children: [
                if (item.leading != null) ...[item.leading!, const SizedBox(width: 8)],
                DefaultTextStyle(
                  style: TextStyle(color: theme.typography.body?.color),
                  child: item.text,
                ),
              ],
            ),
          );
        } else {
          return const PopupMenuDivider() as PopupMenuEntry<String>;
        }
      }).toList(),
    );
  }

  /// 处理键盘事件
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final provider = context.read<EditorProvider>();
    
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
      
      // Ctrl+Z: 撤销
      if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyZ) {
        if (provider.canUndo) {
          provider.undo();
          displayInfoBar(
            context,
            builder: (ctx, close) => const InfoBar(
              title: Text('已撤销'),
              severity: InfoBarSeverity.info,
            ),
            duration: const Duration(milliseconds: 800),
          );
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }
      
      // Ctrl+Y: 重做
      if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyY) {
        if (provider.canRedo) {
          provider.redo();
          displayInfoBar(
            context,
            builder: (ctx, close) => const InfoBar(
              title: Text('已重做'),
              severity: InfoBarSeverity.info,
            ),
            duration: const Duration(milliseconds: 800),
          );
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }
      
      // 以下操作需要编辑模式且有选中线
      if (!provider.isEditMode || !provider.hasSelectedLine || provider.imageSize == null) {
        return KeyEventResult.ignored;
      }

      final imageSize = provider.imageSize!;
      
      // Delete 键删除选中的线
      if (event.logicalKey == LogicalKeyboardKey.delete ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        provider.deleteSelectedLine();
        return KeyEventResult.handled;
      }

      // 方向键微调（1px）
      double delta = 0;
      final isHorizontal = provider.selectedLineIsHorizontal ?? false;
      final relevantSize = isHorizontal ? imageSize.height : imageSize.width;

      if (event.logicalKey == LogicalKeyboardKey.arrowUp && isHorizontal) {
        delta = -1.0 / relevantSize;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && isHorizontal) {
        delta = 1.0 / relevantSize;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && !isHorizontal) {
        delta = -1.0 / relevantSize;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && !isHorizontal) {
        delta = 1.0 / relevantSize;
      }

      if (delta != 0) {
        // 只在第一次按下时保存历史，按住重复时不保存
        final saveHistory = event is KeyDownEvent;
        provider.nudgeSelectedLine(delta, saveHistory: saveHistory);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();
    final theme = FluentTheme.of(context);

    // 无图片状态 - 显示占位提示
    if (provider.imageFile == null) {
      return _buildPlaceholder(theme);
    }

    // 加载中状态
    if (provider.isLoading) {
      return const Center(child: ProgressRing());
    }

    // 有图片状态
    return Column(
      children: [
        // 工具栏
        _buildToolbar(theme, provider),
        // 图片画布
        Expanded(
          child: GestureDetector(
            onTap: () {
              // 点击画布区域时请求焦点
              if (provider.isEditMode) {
                _focusNode.requestFocus();
              }
            },
            child: Focus(
              focusNode: _focusNode,
              onKeyEvent: _handleKeyEvent,
              // 自动获得焦点
              autofocus: false,
              child: Container(
                color: theme.micaBackgroundColor,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.1,
                  maxScale: 10.0,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  // 编辑模式下禁用画布平移，拖拽网格线时也禁用
                  panEnabled: !provider.isEditMode && !_isDragging,
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 计算图片的实际渲染尺寸（基于 BoxFit.contain）
                        final imageSize = provider.imageSize!;
                        final containerAspect = constraints.maxWidth / constraints.maxHeight;
                        final imageAspect = imageSize.width / imageSize.height;
                        
                        Size renderSize;
                        if (containerAspect > imageAspect) {
                          // 容器更宽，图片按高度缩放
                          renderSize = Size(
                            constraints.maxHeight * imageAspect,
                            constraints.maxHeight,
                          );
                        } else {
                          // 容器更高，图片按宽度缩放
                          renderSize = Size(
                            constraints.maxWidth,
                            constraints.maxWidth / imageAspect,
                          );
                        }

                        return Stack(
                          children: [
                            // 底层图片
                            Image.file(
                              provider.imageFile!,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                            // 网格覆盖层
                            if (provider.imageSize != null)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: GridPainter(
                                    horizontalLines: provider.horizontalLines,
                                    verticalLines: provider.verticalLines,
                                    hoveredHorizontalIndex: _hoveredHorizontalIndex,
                                    hoveredVerticalIndex: _hoveredVerticalIndex,
                                    selectedHorizontalIndex: provider.selectedLineIsHorizontal == true
                                        ? provider.selectedLineIndex
                                        : null,
                                    selectedVerticalIndex: provider.selectedLineIsHorizontal == false
                                        ? provider.selectedLineIndex
                                        : null,
                                    isDragging: _isDragging,
                                  ),
                                ),
                              ),
                            // 交互层：仅在编辑模式下启用
                            if (provider.imageSize != null && provider.isEditMode)
                              Positioned.fill(
                                child: MouseRegion(
                                  cursor: (_hoveredHorizontalIndex != null ||
                                          _hoveredVerticalIndex != null)
                                      ? SystemMouseCursors.move
                                      : SystemMouseCursors.precise,
                                  onHover: (event) =>
                                      _checkLineHover(event.localPosition, renderSize, provider),
                                  onExit: (_) {
                                    setState(() {
                                      _hoveredHorizontalIndex = null;
                                      _hoveredVerticalIndex = null;
                                    });
                                  },
                                  child: Listener(
                                    behavior: HitTestBehavior.translucent,
                                    onPointerDown: (event) {
                                      _handlePointerDown(event, renderSize, provider);
                                    },
                                    onPointerMove: (event) {
                                      _handlePointerMove(event, renderSize, provider);
                                    },
                                    onPointerUp: (event) {
                                      _handlePointerUp(event, renderSize, provider);
                                    },
                                    onPointerCancel: (_) {
                                      setState(() {
                                        _isDragging = false;
                                        _draggingHorizontalIndex = null;
                                        _draggingVerticalIndex = null;
                                        _pointerDownPosition = null;
                                      });
                                    },
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onSecondaryTapUp: (details) {
                                        _showContextMenu(context, details.localPosition, renderSize, provider);
                                      },
                                      child: Container(color: Colors.transparent),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建工具栏
  Widget _buildToolbar(FluentThemeData theme, EditorProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
      ),
      child: Row(
        children: [
          // 图片信息
          if (provider.imageSize != null) ...[
            Icon(FluentIcons.photo2, size: 16, color: theme.accentColor),
            const SizedBox(width: 8),
            Text(
              '${provider.imageSize!.width.toInt()} × ${provider.imageSize!.height.toInt()}',
              style: theme.typography.caption,
            ),
            const SizedBox(width: 16),
          ],
          // 文件名
          if (provider.imageFile != null)
            Expanded(
              child: Text(
                provider.imageFile!.path.split(Platform.pathSeparator).last,
                style: theme.typography.caption,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const Spacer(),
          // 模式切换按钮
          if (provider.imageSize != null) ...[
            Tooltip(
              message: provider.isEditMode ? '切换到查看模式' : '切换到编辑模式',
              child: ToggleButton(
                checked: provider.isEditMode,
                onChanged: (value) => provider.setEditMode(value),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      provider.isEditMode ? FluentIcons.edit : FluentIcons.view,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      provider.isEditMode ? '编辑模式' : '查看模式',
                      style: theme.typography.caption,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // 重置缩放按钮
          Tooltip(
            message: '重置缩放',
            child: IconButton(
              icon: const Icon(FluentIcons.full_screen, size: 16),
              onPressed: _resetZoom,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建占位提示
  Widget _buildPlaceholder(FluentThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.file_image,
            size: 64,
            color: theme.accentColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '拖拽图片到此处',
            style: theme.typography.subtitle,
          ),
          const SizedBox(height: 8),
          Text(
            '或点击右侧面板选择文件',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '支持 PNG、JPG、WEBP 格式',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

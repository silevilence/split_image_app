# SmartGridSlicer - Copilot 开发指南

## 项目概览
SmartGridSlicer 是一款 Windows 桌面工具，用于将贴纸图集按网格切割成独立图片。基于 Flutter + Provider + fluent_ui 构建。

## 架构概要

### 状态管理 (Provider 双核心)
- **`EditorProvider`** - 管理图片、网格线、编辑模式、撤销/重做
- **`PreviewProvider`** - 管理切片预览生成、选择状态、导出进度

两个 Provider 在 `main.dart` 的 `MultiProvider` 中注册，通过 `context.read/watch` 访问。

### 坐标系统（关键概念）
网格线使用**相对位置 (0.0-1.0)** 存储，与图片尺寸解耦：
```dart
// 转换到实际像素: lineY = renderSize.height * horizontalLines[i]
// 屏幕→图片坐标: CoordinateUtils.screenToImage(localPosition, transformMatrix)
```
`editor_canvas.dart` 中的 `InteractiveViewer` 变换需要矩阵逆运算。

### 数据流
```
图片加载 → EditorProvider.loadImage()
         → 智能适配 _applySmartGridFit() 交换行列
         → 生成网格线 _generateGridLines()

预览生成 → PreviewProvider.generatePreview()
         → 内存裁剪 (dart:ui Canvas)
         → 缩略图列表

导出     → ImageProcessor.exportSlices() (Isolate)
         → 使用 image 包裁剪并写入磁盘
```

## 开发规范

### UI 组件
- 使用 `fluent_ui` 组件，**不要混用 material**（除 PopupMenu 外）
- 主题色访问: `FluentTheme.of(context).accentColor`
- InfoBar 通知: `displayInfoBar(context, builder: ...)`

### 编辑历史
`EditorHistory` 实现撤销/重做（最多 50 步）：
```dart
provider.beginEdit();  // 开始拖拽/微调前调用
// ... 修改网格线 ...
provider.endEdit();    // 操作结束
```

### 图片处理
- 预览生成: `dart:ui` Canvas 内存裁剪
- 批量导出: `image` 包 + Isolate（因 dart:ui 不能跨 Isolate）
- 文件格式: PNG/JPG/WEBP

## 关键文件

| 文件 | 职责 |
|------|------|
| `providers/editor_provider.dart` | 核心状态：图片、网格线、选中线、撤销栈 |
| `widgets/editor_canvas.dart` | 画布交互：拖拽、悬停、右键菜单、快捷键 |
| `utils/coordinate_utils.dart` | 坐标转换：屏幕↔图片、线条检测 |
| `utils/image_processor.dart` | Isolate 导出任务 |

## 构建与运行

```powershell
flutter pub get           # 安装依赖
flutter run -d windows    # 调试运行
flutter build windows     # Release 构建
# 产物: build\windows\x64\runner\Release\split_image_app.exe
```

## 常见扩展场景

### 添加新的网格操作
1. 在 `EditorProvider` 添加方法，调用 `_saveToHistory()` 保存状态
2. 更新 `editor_canvas.dart` 的交互逻辑
3. 确保 `notifyListeners()` 触发重绘

### 修改导出格式
修改 `image_processor.dart` 的 `_exportInIsolate()` 方法中的编码逻辑。

### 添加快捷键
在 `editor_canvas.dart` 的 `_handleKeyEvent()` 方法中添加 `LogicalKeyboardKey` 处理。

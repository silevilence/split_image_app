# SmartGridSlicer - Copilot 开发指南

## 项目概览
SmartGridSlicer 是一款 Windows 桌面工具，用于将贴纸图集按网格切割成独立图片。基于 Flutter + Provider + fluent_ui 构建。

## 架构概要

### 状态管理 (Provider 双核心)
- **`EditorProvider`** - 管理图片、网格线、边距、编辑模式、撤销/重做
- **`PreviewProvider`** - 管理切片预览生成、选择状态、导出进度

两个 Provider 在 `main.dart` 的 `MultiProvider` 中注册，通过 `context.read/watch` 访问。

### 配置服务 (Singleton)
- **`ConfigService`** - 管理 TOML 配置文件读写
  - 配置文件路径: 应用根目录下的 `config.toml`
  - 单例访问: `ConfigService.instance`
  - 初始化: `await ConfigService.instance.initialize()` (在 `main()` 中调用)

### 坐标系统（关键概念）
网格线使用**相对位置 (0.0-1.0)** 存储，与图片尺寸解耦：
```dart
// 转换到实际像素: lineY = renderSize.height * horizontalLines[i]
// 屏幕→图片坐标: CoordinateUtils.screenToImage(localPosition, transformMatrix)
```
`editor_canvas.dart` 中的 `InteractiveViewer` 变换需要矩阵逆运算。

### 数据流
```
应用启动 → ConfigService.instance.initialize()
         → 加载 config.toml (不存在则创建默认)

图片加载 → EditorProvider.loadImage()
         → 智能适配 _applySmartGridFit() 交换行列
         → 生成网格线 _generateGridLines()

边距设置 → EditorProvider.setMargins() / setMarginTop/Bottom/Left/Right()
         → 计算 effectiveRect (有效区域)
         → 重新生成网格线 (基于有效区域)

预览生成 → PreviewProvider.generatePreview(margins: ...)
         → 内存裁剪 (dart:ui Canvas)
         → 仅切割有效区域内的图片
         → 缩略图列表

导出     → ImageProcessor.exportSlices() (Isolate)
         → 使用 image 包裁剪并写入磁盘
         → 保存导出目录到配置
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
- 文件格式: PNG/JPG（WebP 编码不支持）

### 配置系统
- 格式: TOML (使用 `toml` 包)
- 路径: 应用可执行文件同目录下的 `config.toml`
- 内容: 导出设置、快捷键绑定、网格默认值
```dart
// 读取配置
final config = ConfigService.instance.config;
final lastDir = ConfigService.instance.lastExportDirectory;

// 修改配置
await ConfigService.instance.setDefaultExportFormat('jpg');
await ConfigService.instance.setToggleModeShortcut('V');
```

## 关键文件

| 文件 | 职责 |
|------|------|
| `providers/editor_provider.dart` | 核心状态：图片、网格线、边距、选中线、撤销栈 |
| `widgets/editor_canvas.dart` | 画布交互：拖拽、悬停、右键菜单、快捷键、边距设置 |
| `models/margins.dart` | 边距数据模型：ImageMargins、effectiveRect 计算 |
| `widgets/margins_input.dart` | 边距输入 UI 组件 |
| `utils/coordinate_utils.dart` | 坐标转换：屏幕↔图片、线条检测 |
| `utils/image_processor.dart` | Isolate 导出任务 |
| `services/config_service.dart` | 配置管理：TOML 读写、快捷键、导出设置 |
| `models/app_config.dart` | 配置数据模型：ExportConfig, ShortcutsConfig, GridConfig |

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
快捷键现在从配置读取，修改步骤：
1. 在 `models/app_config.dart` 的 `ShortcutsConfig` 添加新字段
2. 在 `services/config_service.dart` 添加 setter 方法
3. 在 `editor_canvas.dart` 的 `_handleKeyEvent()` 中使用 `matchesShortcut()` 检查
4. 在 `widgets/settings_dialog.dart` 添加 UI 编辑行

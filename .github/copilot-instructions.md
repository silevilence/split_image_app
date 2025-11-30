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

## 🔄 Development & Documentation Protocol

### 1. 🛡️ Code Verification (Pre-Test)
- **Mandatory Analysis:** 编写完功能代码后，**必须**先执行 `flutter analyze` 确保无静态错误。
- **Zero Errors:** 如果发现错误，必须立即自行修正，直到分析通过为止。

### 2. 🤖 Automated Self-Testing (Patrol)
- **Framework:** 必须使用 **patrol** 包编写集成测试代码。
- **Structure:** 测试代码必须存放在 `test/` 目录下，并按模块进行分类管理（例如：`test/settings/settings_flow_test.dart`, `test/grid/smart_grid_test.dart`）。
- **Preservation:** **严禁删除**过往的测试文件。所有的历史测试必须保留。
- **Execution:**
  - 在当前功能开发阶段，**仅运行**与本次新功能相关的测试文件 (Targeted Testing)，以节省时间。
  - 指令示例: `flutter test integration_test/features/my_new_feature_test.dart`
- **Loop:** 如果 Patrol 测试失败，必须根据日志自动修复代码，直到测试通过为止。**严禁**在自动化测试失败的情况下通知用户。

### 3. 📢 User Verification Notification (Delivery)
仅当 **编译通过 + Patrol 测试通过** 后，向用户发送通知。
**Format:** 保持简短：
- **功能点:** [Name]
- **测试结果:** ✅ Patrol Test Passed ([Test File Name])
- **入口:** [UI Location]
- **简要操作:** [Action]

### 4. 📚 Documentation Sync (Post-User-Verify)
- **Trigger:** 仅当用户人工确认 **"功能测试通过"** 或 **"更新文档"** 后触发。
- **Action:** 必须同时更新以下三个文件（直接修改，不输出内容）：
  1. **`README.md`:** 更新 Features 列表。
  2. **`copilot-instructions.md`:** (重要) 将新引入的 Package、关键架构决策追加到文件末尾，以保持上下文记忆。
  3. **`ROADMAP.md`:** 将对应任务从 **"🚧 开发中"** 移至 **"✅ 已完成"**。

---

## 📖 Architecture Notes (上下文记忆)

### Shortcuts/Actions 系统 (2025-11-29)
- **架构:** 使用 Flutter 标准的 `Shortcuts` + `Actions` 系统
- **文件结构:**
  - `lib/shortcuts/app_intents.dart` - Intent 定义类
  - `lib/shortcuts/shortcut_manager.dart` - `AppShortcutManager` 解析配置、生成映射、冲突检测
  - `lib/shortcuts/shortcut_wrapper.dart` - `ShortcutWrapper` 组件包装、`buildTooltipWithShortcut()` 工具函数
- **集成方式:** 在 `main.dart` 的 `_MainWindow` 中用 `ShortcutWrapper` 包装整个应用
- **方向键微调:** 因需要支持 `KeyRepeatEvent`，保留在 `editor_canvas.dart` 的 `_handleKeyEvent` 中单独处理
- **配置同步:** `AppShortcutManager` 监听 `ConfigService` 变化，自动更新快捷键映射

### Grid Algorithm Strategy Pattern (2025-11-29)
- **架构:** 使用策略模式 (Strategy Pattern) 解耦网格生成算法
- **文件结构:**
  - `lib/models/grid_algorithm_type.dart` - 算法类型枚举 (fixedEvenSplit, projectionProfile, edgeDetection)
  - `lib/models/grid_generator_input.dart` - 标准输入参数模型
  - `lib/models/grid_generator_result.dart` - 标准输出结果模型
  - `lib/strategies/grid_generator_strategy.dart` - 抽象基类
  - `lib/strategies/grid_strategy_factory.dart` - 工厂类
  - `lib/strategies/fixed_even_split_strategy.dart` - 均匀分割策略实现
  - `lib/strategies/projection_profile_strategy.dart` - 投影分析策略实现
- **扩展方式:** 新增算法只需:
  1. 在 `GridAlgorithmType` 添加枚举值
  2. 在 `GridStrategyFactory.create()` 添加 switch case
  3. 创建新的策略实现类
- **配置集成:** `app_config.dart` 的 `GridConfig` 包含 `defaultAlgorithm` 字段
- **Provider 集成:** `EditorProvider._generateGridLines()` 使用策略工厂创建算法实例
- **边距建议:** 算法可通过 `GridGeneratorResult.suggestedMargins` 返回建议边距

### Projection Profile Algorithm (2025-11-29)
- **实现文件:** `lib/strategies/projection_profile_strategy.dart`
- **背景检测:** 自动识别透明/浅色/深色三种背景类型
  - 采样图片四边像素，计算透明度和亮度
  - 透明背景: 使用 Alpha 通道投影
  - 浅色/深色背景: 使用亮度投影，方向相反
- **投影计算:**
  - 水平投影: 每行像素值求和，用于检测水平分割线
  - 垂直投影: 每列像素值求和，用于检测垂直分割线
- **波谷检测:** 寻找投影曲线的局部最小值区域
  - 使用阈值过滤 (低于平均值的 80%)
  - 连续低值区域合并为一个波谷
  - 记录波谷的 start, end, center, depth
- **边缘检测:** 检测首尾 15% 范围内的波谷作为边缘
  - 使用波谷中心位置作为建议边距
  - 通过 `hasUserMargins` 参数控制是否检测边缘
- **手动触发:** 边距修改不再自动触发切割
  - "应用并重新切割" 按钮: 使用当前边距重新生成网格
  - "智能检测边缘" 按钮: 清空边距并重新检测边缘

### TOML 序列化 (2025-11-29)
- **编码方式:** 使用 `TomlDocument.fromMap()` 生成 TOML 内容
- **解码方式:** 使用 `TomlDocument.parse().toMap()` 解析 TOML
- **配置模型:** `AppConfig.toMap()` / `AppConfig.fromMap()` 双向转换

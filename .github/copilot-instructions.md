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
- **Zero Errors:** 如果发现错误，必须立即自行修正，直到分析通过为止。即使只是警告，如果不是由于代码实现所必需的，也应予以修正。

### 2. 🤖 Automated Self-Testing (Patrol)
- **Framework:** 必须使用 **patrol** 包编写集成测试代码。如果需要使用实际图片进行测试时，使用 `refs` 目录下的测试资源。
- **Structure:** 测试代码必须存放在 `test/` 目录下，并按模块进行分类管理（例如：`test/settings/settings_flow_test.dart`, `test/grid/smart_grid_test.dart`）。
- **Preservation:** **严禁删除**过往的测试文件。所有的历史测试必须保留。
- **Execution:**
  - 在当前功能开发阶段，**仅运行**与本次新功能相关的测试文件 (Targeted Testing)，以节省时间。
  - 指令示例: `flutter test integration_test/features/my_new_feature_test.dart`
- **Loop:** 如果 Patrol 测试失败，必须根据日志自动修复代码，直到测试通过为止。**严禁**在自动化测试失败的情况下通知用户。

### 3. 📢 User Verification Notification (Delivery)
仅当 **编译通过 + Patrol 测试通过** 后，使用 `flutter run -d windows` 打开应用，并向用户发送通知。
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

### Edge Detection Algorithm (2025-11-30)
- **实现文件:** `lib/strategies/edge_detection_strategy.dart`
- **算法流程:**
  1. 灰度转换: 将图片转为灰度图，透明像素视为白色背景
  2. 高斯模糊 (可选): 3x3 高斯核减少噪声
  3. Sobel 边缘检测: 使用水平/垂直 Sobel 算子计算梯度幅值
  4. 边缘密度投影: 计算每行/每列的边缘强度总和
  5. 波谷检测: 找到边缘密度最低的区域 (贴纸之间的间隙)
  6. 分割线选择: 根据目标行列数选择最佳分割位置
- **Sobel 算子:**
  ```
  Gx = [-1 0 1]    Gy = [-1 -2 -1]
       [-2 0 2]         [ 0  0  0]
       [-1 0 1]         [ 1  2  1]
  ```
- **与投影分析的区别:**
  - 投影分析: 直接使用像素亮度/Alpha 值投影
  - 边缘检测: 先检测边缘，再对边缘强度进行投影
- **适用场景:** 贴纸之间有明显边界但背景不均匀的情况

### Resizable Split View (2025-11-30)
- **实现文件:** `lib/widgets/resizable_split_view.dart`
- **功能:** 可拖拽调整大小的垂直分割视图
- **配置持久化:**
  - `PanelConfig` 模型存储 `settingsSplitRatio` (0.0-1.0)
  - `ConfigService.setSettingsSplitRatio()` 保存到 TOML
- **约束:**
  - 最小高度常量: `PanelConfig.minSettingsHeight` / `PanelConfig.minPreviewHeight`
  - 拖拽时自动 clamp 到有效范围
- **集成方式:** `PreviewPanel` 使用 `ResizableSplitView` 包装设置区和预览区
- **交互细节:**
  - 分隔条鼠标悬停显示 `resizeRow` 光标
  - 拖拽时分隔条高亮显示
  - 拖拽结束时触发 `onRatioChanged` 回调保存配置

### Enhanced Preview Modal (2025-12-01)
- **实现文件:** `lib/widgets/preview_modal.dart`
- **功能:** 大图预览弹窗，支持导航、编辑后缀、切换导出状态
- **入口方式:**
  - 双击切片缩略图
  - 点击放大按钮 (full_screen 图标)
  - 右键菜单 → "查看大图"
- **快捷键:**
  - `←` `→` 方向键切换图片
  - `Space` 切换是否导出
  - `Esc` 关闭预览
- **高清预览:** 使用 `dart:ui` Canvas 从源图裁剪高清图片，缓存已加载的图片
- **SliceItem 右键菜单:**
  - 使用 `FlyoutController` + `MenuFlyout` 实现
  - 菜单项: 查看大图、选择/取消导出、编辑后缀
- **事件隔离:**
  - 静态变量 `_anyContextMenuOpen` 全局跟踪菜单打开状态
  - 右键菜单打开时阻止 `onPointerDown` 触发选择
  - `onSelectionChanged` 回调区分直接点击 (`startDrag: true`) 和菜单操作 (`startDrag: false`)
  - 避免菜单关闭时的点击事件穿透到其他切片

### Image Processing Pipeline (2025-12-01) 🚧 开发中
- **架构:** 策略模式 (Strategy Pattern) + 责任链 (Chain of Responsibility)
- **文件结构:**
  - `lib/processors/image_processor.dart` - 抽象基类 + ProcessorType 枚举
  - `lib/processors/processor_chain.dart` - 责任链管理器 + SliceOverrides
  - `lib/processors/processor_factory.dart` - 处理器工厂类
  - `lib/processors/processor_io.dart` - ProcessorInput/Output 数据模型
  - `lib/processors/processor_param.dart` - 参数定义 (ProcessorParamDef, ProcessorParams)
  - `lib/providers/pipeline_provider.dart` - Pipeline 状态管理
- **内置处理器 (已实现参数定义，实际处理逻辑待实现):**
  - `BackgroundRemovalProcessor` - 背景去除 (阈值, 替换色)
  - `SmartCropProcessor` - 智能裁剪 (四边边距)
  - `ColorReplaceProcessor` - 颜色替换 (目标色, 新颜色, 阈值)
  - `ResizeProcessor` - 缩放调整 (宽度, 高度, 单位)
- **参数系统:**
  - `ProcessorParamDef` - 参数定义 (名称、类型、默认值、描述、isPerImage)
  - `ProcessorParamType` - 参数类型枚举 (intType, doubleType, color, string, enumType)
  - Global Parameters - 应用于所有图片
  - Per-Image Parameters - 可针对单张图片覆盖
- **UI 组件:**
  - `PipelineSummary` - 流水线概要卡片，显示活跃步骤数和应用按钮
  - `PipelineManagerModal` - 流水线管理弹窗，添加/删除/重排序处理器
  - `ProcessorStepEditor` - 处理器参数编辑器，根据参数类型自动生成输入控件
  - `ColorPickerButton` - HSV 通用颜色选择器
  - `PerImageOverrideEditor` - 单图参数覆盖编辑器 (2025-12-03)
- **HSV 颜色选择器:**
  - 饱和度-亮度 2D 选择区 (CustomPainter)
  - 色相滑块 (彩虹渐变)
  - Alpha 透明度滑块
  - Hex 输入框 (#AARRGGBB 格式)
  - RGB ↔ HSV 双向转换
- **Per-Image Fine-tuning (2025-12-03):**
  - 集成在 Preview Modal 右侧可折叠面板
  - 仅显示 `supportsPerImageOverride = true` 的参数
  - Override 复选框启用/禁用单图覆盖
  - 覆盖参数存储在 `SlicePreview.processorOverrides`
  - "预览处理效果" 按钮实时预览处理结果
- **Pipeline Import/Export (2025-12-03):**
  - JSON 格式导入/导出 Pipeline 配置
  - 仅导出处理器配置，不含单图覆盖参数
  - 导入时支持覆盖/追加模式
  - `_ensureUniqueName()` 自动处理重名 (添加 -2, -3 后缀)
  - 导入时始终生成新的 `instanceId` 避免 GlobalKey 冲突
  - UI 入口: `PipelineManagerModal` 标题栏导入/导出图标按钮

### Processor Implementations (2025-12-03)
- **BackgroundRemovalProcessor:**
  - 算法: 四角采样 + Queue-based Flood Fill
  - 从四角采样背景颜色，使用 RGB 距离计算相似度
  - 参数: `threshold` (0-255), `replaceColor` (ARGB)
- **SmartCropProcessor (边缘裁剪):**
  - 算法: 直接按用户指定的像素值裁剪四边
  - 参数: `marginTop/Bottom/Left/Right` (像素值)
  - 注意: 不做自动内容检测，完全按用户设置裁剪
- **ColorReplaceProcessor:**
  - 算法: RGB 颜色距离匹配
  - 距离公式: `sqrt((r1-r2)² + (g1-g2)² + (b1-b2)²)` / 441.67 * 255
  - 参数: `targetColor`, `newColor`, `threshold`
- **ResizeProcessor:**
  - 算法: 双线性插值 (Bilinear Interpolation)
  - 采样 4 个相邻像素进行加权平均
  - 参数: `width`, `height`, `unit` (pixel/percent)
  - 支持只指定一个维度自动保持宽高比

### Pipeline Preview Modal (2025-12-03)
- **实现文件:** `lib/widgets/pipeline_preview_modal.dart`
- **功能:** 应用按钮点击后弹出，显示所有切片处理后的效果
- **流程:** 读取源图 → 裁剪切片 → 应用 Pipeline → 显示结果
- **信息:** 显示处理前后尺寸变化 (如 100×100 → 80×80)

### Export with Pipeline (2025-12-03)
- **实现位置:** `lib/widgets/preview_panel.dart` `_exportSlices()`
- **流程:**
  1. 检测是否配置了处理器
  2. 如有，先在主线程裁剪并应用 Pipeline 处理
  3. 将处理后的像素数据传给 Isolate 保存
- **ExportSlice 扩展:**
  - `processedPixels`: 处理后的 RGBA 像素数据
  - `processedWidth/Height`: 处理后的尺寸
  - `hasProcessedData`: 是否有处理数据
- **Isolate 处理:** 检测 `hasProcessedData`，有则直接使用处理后数据，无则从原图裁剪

### 待实现功能
- [ ] Pipeline 配置持久化到 TOML (Session 自动保存)

---

## 🐙 Git Version Control Protocol

### 1. 🚦 Explicit Authorization (明确指令)
- **Trigger Required:** 严禁自动执行 Git 操作。必须等待用户发出明确指令（如"提交代码"、"Push"、"打个Tag"）后方可执行。
- **Command Mapping:**
  - 用户说 "提交" / "Commit" -> 执行 `git add .` 和 `git commit`
  - 用户说 "推送" / "Push" -> 执行 `git push`

### 2. 📝 Commit Message Standard (Emoji-First)
- **Language:** 描述部分**必须使用中文**
- **Header Format:** 必须严格遵循格式：`<emoji> <type>: <description>` (Emoji 在最前方，以保持列表对齐)
- **Example:** `✨ feat: 增加右键菜单预览功能`
- **Example:** `🐛 fix: 修复网格分割线偏移问题`
- **Body (Detailed Description):**
  - 当变更不仅仅是简单的修复时，**必须**在 Header 后空一行编写 Body。
  - 解释变更的 **Motivation** (原因) 和 **Implementation** (实现细节)。
  - 使用 `-` 列表项使其易读。
  - **Example:**
    ```
    ✨ feat: 增加智能边缘检测算法

    - Motivation: 现有均匀分割无法处理不规则间距的贴纸图集
    - Implementation:
      - 使用 Sobel 算子进行边缘检测
      - 对边缘强度进行投影分析
      - 自动识别贴纸间隙位置
    ```

### 3. Allowed Types & Emojis
| Emoji | Type | Description |
|-------|------|-------------|
| ✨ | `feat` | New Feature / 新功能 |
| 🐛 | `fix` | Bug Fix / 修复 Bug |
| 📝 | `docs` | Documentation / 文档变更 |
| 💄 | `style` | UI & Formatting / 格式或 UI 调整 |
| ♻️ | `refactor` | Refactor / 代码重构 |
| ✅ | `test` | Tests / 测试相关 |
| 🔧 | `chore` | Tooling & Config / 构建工具或配置修改 |
| 👷 | `ci` | CI/CD / 持续集成流程 |
| 📦 | `build` | Build / 发布版本或打包 |

### 4. 🛡️ Safety Checks
- 在执行 `git commit` 之前，先运行 `git status` 确认变更范围
- 在执行 `git push` 之前，如果本地落后于远程，应提示用户是否需要先 `git pull`

---

## 📦 Release Management Protocol

### 1. 🎯 Trigger
当用户要求 **"发布新版本"**、**"打 Tag"** 或指定版本号（如 "发布 v1.0.0"）时触发此流程。

### 2. 📋 Workflow

#### Step 1: Update Metadata
1. **修改 `pubspec.yaml`** 中的 `version` 字段
2. **更新 `CHANGELOG.md`**
   - **Strict Format:** 必须使用 `## [X.X.X] - YYYY-MM-DD` 格式（为了让 GitHub Actions 正确解析）
   - **内容结构:**
     ```markdown
     ## [1.0.0] - 2025-12-01

     ### ✨ 新功能
     - 功能描述

     ### 🐛 问题修复
     - 修复描述

     ### ⚡ 优化
     - 优化描述
     ```

#### Step 2: Commit Changes
1. 执行 `git add pubspec.yaml CHANGELOG.md`
2. 执行 `git commit -m "🔧 chore: Release vX.X.X"`
   - **Important:** 此步骤必须在运行发布脚本前完成，保证 Git 工作区干净且包含最新版本号

#### Step 3: Run Interactive Script
1. 执行脚本：`./scripts/check_version.ps1 -NewVersion "X.X.X"`
2. **脚本行为说明:**
   - 脚本会验证版本号一致性（pubspec.yaml、CHANGELOG.md、Git Tag）
   - 验证通过后会提示：`是否立即执行这些命令? (y/N)`
3. **Action:** 告知用户输入 `y` 即可自动完成 `git tag` 和 `git push`
4. **⚠️ Important:** **不要**在脚本运行后手动生成 `git tag` 或 `git push` 指令，脚本会全权代理这些操作

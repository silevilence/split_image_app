# SmartGridSlicer - Development Roadmap

> **项目名称:** SmartGridSlicer  
> **目标平台:** Windows Desktop  
> **技术栈:** Flutter + Provider + fluent_ui  
> **创建日期:** 2025-11-28  
> **最后更新:** 2025-11-29

---

## 📋 项目概览

SmartGridSlicer 是一款 Windows 桌面工具，用于将贴纸图集 (Sticker Sheet) 按网格切割成独立图片。核心特性包括：
- 交互式网格线拖拽调整
- 智能行列适配
- 批量预览与选择导出
- 智能网格识别算法 (规划中)

---

# 🗂️ 新功能看板 (Kanban Board)

## 🚧 开发中 (In Progress)

*暂无*

---

## ✅ 已完成 (Completed)

### UI: 🏛️ Resizable Control Panel (可调整控制面板)
**完成日期:** 2025-11-30

#### 📝 Description
解决屏幕空间利用率问题，提供更灵活的面板布局。

#### ✅ Checklist
- [x] 将侧边栏分为 "Settings Area" 和 "Preview/Export Area"
- [x] 中间增加可拖拽的分割线 (Draggable Splitter)
- [x] 各区域独立滚动条 (当内容高度超出区域限制时)
- [x] 记忆用户调整的分割位置 (持久化到配置)
- [x] 每个区域要有最小高度的保证

#### 📁 产出文件
```
lib/
├── models/
│   └── app_config.dart           # 更新: 添加 PanelConfig
├── widgets/
│   ├── resizable_split_view.dart # 新增: 可调整分割视图组件
│   └── preview_panel.dart        # 更新: 集成 ResizableSplitView
└── services/
    └── config_service.dart       # 更新: 添加面板比例持久化
test/
└── widgets/
    ├── panel_config_test.dart    # 新增: 配置模型测试
    └── resizable_split_view_test.dart # 新增: 组件测试
```

---

### Feature: 🔍 边缘检测算法 (Edge Detection)
**完成日期:** 2025-11-30

#### 📝 Description
基于 Sobel 边缘检测算法自动识别贴纸边界，通过检测图片中边缘密度最低的区域作为分割线位置。

#### ✅ Checklist
- [x] 实现 `EdgeDetectionStrategy` 策略类
- [x] 灰度图转换 (考虑 Alpha 通道)
- [x] 高斯模糊预处理 (可选)
- [x] Sobel 算子边缘检测
- [x] 边缘密度投影计算
- [x] 波谷检测 (边缘密度低的区域)
- [x] 边距建议功能
- [x] 更新 `GridAlgorithmType` 枚举
- [x] 更新 `GridStrategyFactory` 工厂类
- [x] 单元测试

#### 📁 产出文件
```
lib/
├── strategies/
│   └── edge_detection_strategy.dart  # 边缘检测算法实现
├── models/
│   └── grid_algorithm_type.dart      # 更新: isImplemented = true
└── strategies/
    └── grid_strategy_factory.dart    # 更新: 添加 edgeDetection case
test/
└── strategies/
    └── edge_detection_strategy_test.dart  # 单元测试
```

---

### Refactor: 🏗️ Grid Algorithm Architecture (策略模式重构)
**完成日期:** 2025-11-29

#### 📝 Description
使用策略模式 (Strategy Pattern) 解耦网格生成算法与 UI 代码，为后续智能算法奠定架构基础。

#### ✅ Checklist
- [x] 定义 `GridGeneratorStrategy` 抽象基类/接口
- [x] 定义标准输入参数: `GridGeneratorInput`
- [x] 定义标准输出: `GridGeneratorResult`
- [x] 创建 `GridAlgorithmType` 枚举 (fixedEvenSplit, projectionProfile, edgeDetection)
- [x] 实现 `GridStrategyFactory` 工厂类
- [x] 迁移现有均匀分割逻辑到 `FixedEvenSplitStrategy`
- [x] 更新 `EditorProvider` 使用策略模式
- [x] 在 `app_config.dart` 添加 `defaultAlgorithm` 配置项
- [x] 在 `config.toml` 添加算法配置
- [x] 在设置页面添加 "Default Algorithm" 下拉菜单

#### 📁 产出文件
```
lib/
├── models/
│   ├── grid_algorithm_type.dart      # 算法类型枚举
│   ├── grid_generator_input.dart     # 输入参数模型
│   └── grid_generator_result.dart    # 输出结果模型
├── strategies/
│   ├── grid_generator_strategy.dart  # 抽象基类
│   ├── grid_strategy_factory.dart    # 工厂类
│   └── fixed_even_split_strategy.dart # 均匀分割实现
├── services/
│   └── config_service.dart           # 更新: 添加算法配置
├── models/
│   └── app_config.dart               # 更新: GridConfig 添加 defaultAlgorithm
├── providers/
│   └── editor_provider.dart          # 更新: 集成策略模式
└── widgets/
    └── settings_dialog.dart          # 更新: 添加算法选择 UI
```

---

### Feature: 🧠 智能网格初始化算法 (Projection Profile)
**完成日期:** 2025-11-29

#### 📝 Description
基于投影分析法 (Projection Profile) 自动识别贴纸缝隙，支持多种背景类型检测，并可自动设置边距。

#### ✅ Checklist
- [x] 实现 Vertical Projection (垂直投影) 计算
- [x] 实现 Horizontal Projection (水平投影) 计算
- [x] 波谷检测算法 (Valley Detection)
- [x] 网格线 Snap 到波谷中心
- [x] 背景类型自动检测 (透明/浅色/深色)
- [x] 边缘波谷自动转换为建议边距
- [x] 手动触发切割按钮 ("应用并重新切割")
- [x] 智能检测边缘按钮
- [x] 算法配置持久化 (TOML)
- [x] 默认行列数从配置读取

#### 📁 产出文件
```
lib/
├── strategies/
│   └── projection_profile_strategy.dart  # 投影分析算法实现
├── models/
│   ├── grid_generator_input.dart         # 更新: 添加 hasUserMargins
│   └── grid_generator_result.dart        # 更新: 添加 SuggestedMargins
├── providers/
│   └── editor_provider.dart              # 更新: detectEdgesAndRegenerate()
└── widgets/
    └── margins_input.dart                # 更新: 添加手动触发按钮
```

---

### Feature: 快捷键与模式切换增强 (Shortcuts & Mode Switching)
**完成日期:** 2025-11-29

#### 📝 Description
引入 Flutter 标准的 Shortcuts/Actions 系统，提供更灵活的快捷键配置和模式切换。

#### ✅ Checklist
- [x] 迁移至 Flutter `Shortcuts` / `Actions` 系统
- [x] View Mode 快捷键切换 (预览/拖拽画布)
- [x] Edit Mode 快捷键切换 (调整切割线)
- [x] 快捷键与配置系统集成 (从 config.toml 读取)
- [x] 快捷键冲突检测
- [x] 快捷键提示 (Tooltip 显示快捷键)

#### 📁 产出文件
```
lib/
├── shortcuts/
│   ├── app_intents.dart          # Intent 定义
│   ├── shortcut_manager.dart     # 快捷键解析与管理
│   └── shortcut_wrapper.dart     # Shortcuts/Actions 包装组件
├── main.dart                     # 更新: 集成 ShortcutWrapper
├── widgets/
│   ├── editor_canvas.dart        # 更新: 简化键盘处理
│   ├── preview_panel.dart        # 更新: Tooltip 显示快捷键
│   └── settings_dialog.dart      # 更新: 冲突检测 UI
```

---

### Feature: 图片边缘留白控制 (Margins / Effective Area)
**完成日期:** 2025-11-29

#### 📝 Description
允许用户指定图片四周的留白区域，排除不参与网格计算的边缘白边。

#### ✅ Checklist
- [x] Margins 数据模型 (Top, Bottom, Left, Right)
- [x] 侧边栏 "Margins" 输入框 UI
- [x] `Effective Rect` 计算逻辑
- [x] 网格线生成限制在 Effective Rect 范围内
- [x] 切片预览/导出仅包含有效区域
- [x] 画布上可视化显示 Margins 边界 (半透明遮罩)
- [x] 右键菜单快速设置边距（点击位置直接作为边距值）

#### 📁 产出文件
```
lib/
├── models/
│   └── margins.dart
├── widgets/
│   └── margins_input.dart
├── providers/
│   └── editor_provider.dart (更新)
└── widgets/
    ├── grid_painter.dart (更新)
    └── editor_canvas.dart (更新)
```

---

### Feature: 设置系统与数据持久化 (Settings & Persistence)
**完成日期:** 2025-11-28

#### ✅ Checklist
- [x] 引入 `toml` 包处理配置文件格式
- [x] 使用 `path_provider` 定位配置文件存储路径
- [x] 创建 `ConfigService` 管理配置读写
- [x] 实现默认配置自动生成 (首次启动)
- [x] 自定义快捷键绑定 (Key Bindings) 数据结构
- [x] Export History: 记忆上次导出路径 (Last Export Directory)
- [x] 导出对话框默认使用上次路径
- [x] 设置界面 UI

#### 📁 产出文件
```
lib/
├── services/
│   └── config_service.dart
├── models/
│   └── app_config.dart
└── widgets/
    └── settings_dialog.dart
```

---

## 📅 计划开发 (Planned)

### Workflow: 🔍 Enhanced Preview Modal (增强型预览/右键菜单)

#### 📝 Description
在 Grid 预览区提供右键菜单和大图预览功能，支持快速编辑和导航。

#### ✅ Checklist
- [ ] 预览区图片右键菜单 (Context Menu)
- [ ] "Zoom/Inspect" 菜单项打开大图预览
- [ ] 预览 Modal/Dialog 显示当前图片大图
- [ ] Previous/Next 导航切换查看其他图片
- [ ] Edit Custom Suffix 输入框 (自定义导出文件名后缀)
- [ ] Toggle Export 复选框 (决定是否导出该图)
- [ ] 键盘快捷键支持 (左右方向键切换图片)

#### 📁 预计产出文件
```
lib/
├── widgets/
│   ├── preview_modal.dart        # 大图预览弹窗
│   ├── slice_item.dart           # 更新: 添加右键菜单
│   └── preview_gallery.dart      # 更新: 集成预览功能
└── models/
    └── slice_preview.dart        # 更新: 添加 customSuffix 字段
```

---

### DevOps: 🚀 GitHub Actions & Release Protocol (自动化发布)

#### 📝 Description
建立自动化构建和发布流程，支持版本控制和安装包生成。

#### ✅ Checklist
- [ ] 创建 `.github/workflows/release.yml`
- [ ] 配置 Tag 触发条件 (仅 `v*` 格式，如 `v1.0.0`)
- [ ] Flutter Windows 构建步骤
- [ ] Inno Setup 打包生成安装程序
- [ ] 自动创建 GitHub Release 并上传 Artifacts
- [ ] 版本号检查机制 (比对 `pubspec.yaml` 版本)
- [ ] 版本回退/重复警告 (要求二次确认)

#### 📁 预计产出文件
```
.github/
└── workflows/
    └── release.yml               # CI/CD 配置
scripts/
├── check_version.ps1             # 版本检查脚本
└── installer.iss                 # Inno Setup 安装脚本
```

---

## 🎯 新功能里程碑概览

| Feature | 优先级 | 预计工时 | 依赖 | 状态 |
|---------|--------|---------|------|------|
| 设置系统与数据持久化 | 🔴 高 | 3-4h | - | ✅ 已完成 |
| 图片边缘留白控制 | 🟡 中 | 2-3h | - | ✅ 已完成 |
| 快捷键与模式切换增强 | 🟡 中 | 2-3h | - | ✅ 已完成 |
| Grid Algorithm Architecture | 🔴 高 | 2-3h | - | ✅ 已完成 |
| 智能网格初始化算法 | 🔴 高 | 4-6h | Architecture | ✅ 已完成 |
| 边缘检测算法 | 🟡 中 | 2-3h | Architecture | ✅ 已完成 |
| Resizable Control Panel | 🟡 中 | 2-3h | - | 📅 计划中 |
| Enhanced Preview Modal | 🟡 中 | 3-4h | - | 📅 计划中 |
| GitHub Actions & Release | 🟢 低 | 2-3h | - | 📅 计划中 |

---

# ✅ 已完成阶段 (Completed Phases)

## 🚀 开发阶段

### Phase 1: 基础 UI 与图片加载
**目标:** 搭建应用骨架，实现图片导入功能

#### ✅ Checklist
- [x] 项目初始化与依赖配置 (`pubspec.yaml`)
- [x] 配置 fluent_ui 主题与窗口设置
- [x] 创建 Split View 布局 (70% 编辑器 / 30% 预览面板)
- [x] 实现文件选择器 (点击按钮选择图片)
- [x] 实现拖拽文件进窗口打开图片 (`DropTarget`)
- [x] 图片显示与基础缩放 (`InteractiveViewer`)
- [x] 行数/列数输入框 UI

#### 🔧 Technical Considerations
- **依赖包:** `fluent_ui`, `file_picker`, `desktop_drop`, `window_manager`
- **状态管理:** 创建 `ImageEditorProvider` 管理图片数据和网格参数
- **文件类型限制:** 仅允许 PNG/JPG/WEBP
- **内存管理:** 大图加载时使用 `dart:ui` 的 `Image` 获取尺寸，避免重复解码

#### 📁 产出文件
```
lib/
├── main.dart
├── providers/
│   └── editor_provider.dart
├── screens/
│   └── home_screen.dart
├── widgets/
│   └── editor_canvas.dart (基础版)
└── models/
    └── grid_config.dart
```

---

### Phase 2: 网格系统与智能适配
**目标:** 实现网格线绘制、智能行列交换、基础拖拽

#### ✅ Checklist
- [x] `CustomPainter` 绘制网格线 (水平线 + 垂直线)
- [x] 智能网格适配逻辑 (图片宽高比 vs 行列比)
- [x] 自动交换行列并显示 Snackbar 提示
- [x] 网格线数据模型 (`List<double>` 存储位置)
- [x] 基础拖拽功能 - 检测鼠标悬停在线上
- [x] 拖拽移动网格线 (处理 `InteractiveViewer` 坐标转换)

#### 🔧 Technical Considerations
- **坐标转换关键点:**
  ```dart
  // 将屏幕坐标转换为图片坐标
  final Matrix4 inverseMatrix = Matrix4.inverted(transformationController.value);
  final Offset imagePosition = MatrixUtils.transformPoint(inverseMatrix, screenPosition);
  ```
- **线条检测:** 鼠标距离线 < 8px 时高亮并允许拖拽
- **约束拖拽范围:** 线不能拖出图片边界，相邻线不能交叉
- **性能:** `CustomPainter` 设置 `shouldRepaint` 优化重绘

#### 📁 产出文件
```
lib/
├── models/
│   └── grid_line.dart
├── widgets/
│   ├── grid_painter.dart
│   └── editor_canvas.dart (完整版)
└── utils/
    └── coordinate_utils.dart
```

---

### Phase 3: 高级交互 - 右键菜单与键盘微调
**目标:** 完善编辑器交互体验

#### ✅ Checklist
- [x] 右键上下文菜单 (fluent_ui `Flyout`)
  - [x] 画布空白处右键: "Add Horizontal Line" / "Add Vertical Line"
  - [x] 线上右键: "Delete This Line"
- [x] 线选中状态高亮 (点击选中，点击空白取消)
- [x] 键盘方向键微调 (选中线后，↑↓←→ 移动 1px)
- [x] 快捷键支持 (Delete 删除选中线)
- [x] 撤销/重做系统 (Ctrl+Z / Ctrl+Y)

#### 🔧 Technical Considerations
- **Focus 管理:** 使用 `FocusNode` 确保画布能接收键盘事件
- **右键菜单:** fluent_ui 的 `FlyoutController` + `GestureDetector.onSecondaryTapDown`
- **撤销/重做:** 使用 `EditorHistory` 管理状态快照栈（最多保存 50 步）
- **状态设计:**
  ```dart
  class EditorState {
    int? selectedLineIndex;
    LineType? selectedLineType; // horizontal or vertical
  }
  ```
- **边界检查:** 微调时确保线位置在 0 ~ imageWidth/Height 范围内

#### 📁 产出文件
```
lib/
├── models/
│   └── editor_history.dart
├── widgets/
│   ├── context_menu.dart
│   └── editor_canvas.dart (更新)
└── providers/
    └── editor_provider.dart (更新)
```

---

### Phase 4: 预览系统与选择逻辑
**目标:** 实现切片预览、多选功能

#### ✅ Checklist
- [x] "Generate Preview" 按钮触发切片计算
- [x] 内存中切片 (使用 `dart:ui` Canvas 裁剪，不写入磁盘)
- [x] `GridView` 显示切片缩略图
- [x] 每个切片项: Checkbox + 缩略图 + 尺寸信息
- [x] 全选 / 全不选 / 反选 按钮
- [x] 按住鼠标滑过连续勾选

#### 🔧 Technical Considerations
- **预览数据模型:**
  ```dart
  class SlicePreview {
    final int row, col;
    final Rect region; // 在原图中的区域
    final Uint8List thumbnailBytes;
    bool isSelected;
    String customSuffix;
  }
  ```
- **框选实现:** 
  - 使用 `Stack` 叠加一个半透明选区矩形
  - `onPanStart/Update/End` 计算选区范围
  - 碰撞检测判断哪些切片在选区内
- **性能:** 预览图生成使用 `compute` 避免卡顿

#### 📁 产出文件
```
lib/
├── models/
│   └── slice_preview.dart
├── widgets/
│   ├── preview_gallery.dart
│   ├── slice_item.dart
│   └── rubber_band_selector.dart
└── providers/
    └── preview_provider.dart
```

---

### Phase 5: 导出工作流与打磨
**目标:** 完成导出功能，优化用户体验

#### ✅ Checklist
- [x] 导出设置面板 (输出目录、文件前缀)
- [x] 目录选择器 (`file_picker` folder mode)
- [x] 进度对话框 (显示 "Saving 3/20...")
- [x] 使用 `compute` (Isolate) 执行批量裁剪保存
- [x] 导出完成后 Snackbar 提示 + 打开文件夹按钮
- [x] 错误处理与用户反馈
- [x] 窗口标题显示当前文件名
- [x] 应用图标与 Metadata

#### 🔧 Technical Considerations
- **Isolate 通信:**
  ```dart
  // 主线程 -> Isolate: 发送裁剪任务列表
  // Isolate -> 主线程: 通过 SendPort 回传进度
  // 注意: Isolate 中不能使用 Flutter UI 相关 API
  ```
- **image 包使用:**
  ```dart
  import 'package:image/image.dart' as img;
  // 裁剪: img.copyCrop(image, x, y, width, height)
  // 保存: File(path).writeAsBytesSync(img.encodePng(cropped))
  ```
- **导出路径生成:** `{outputDir}/{prefix}_{row}_{col}.png`

#### 📁 产出文件
```
lib/
├── utils/
│   └── image_processor.dart
├── widgets/
│   ├── export_dialog.dart
│   └── progress_dialog.dart
└── screens/
    └── home_screen.dart (更新)
```

---

## 📦 依赖清单 (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  fluent_ui: ^4.9.0          # Windows 风格 UI
  provider: ^6.1.0           # 状态管理
  file_picker: ^8.0.0        # 文件/文件夹选择
  desktop_drop: ^0.4.4       # 拖拽文件进窗口
  path_provider: ^2.1.0      # 获取系统路径
  image: ^4.2.0              # 图片裁剪处理
  window_manager: ^0.3.9     # 窗口控制
  path: ^1.9.0               # 路径处理
  toml: ^0.15.0              # TOML 配置文件解析 (新增)
```

---

## 🎯 里程碑时间线 (预估)

| Phase | 名称 | 预计工时 | 状态 |
|-------|------|---------|------|
| 1 | 基础 UI 与图片加载 | 2-3h | ✅ 已完成 |
| 2 | 网格系统与智能适配 | 3-4h | ✅ 已完成 |
| 3 | 高级交互 | 2-3h | ✅ 已完成 |
| 4 | 预览系统与选择逻辑 | 3-4h | ✅ 已完成 |
| 5 | 导出工作流与打磨 | 2-3h | ✅ 已完成 |

---

## 📝 开发笔记

> 此区域用于记录开发过程中的问题、解决方案和变更决策。

### 变更记录
- **2025-11-28:** 创建 ROADMAP.md
- **2025-11-28:** Phase 1 完成 - 基础 UI 与图片加载功能
- **2025-11-28:** Phase 2 完成 - 网格系统与拖拽交互功能，添加查看/编辑模式切换
- **2025-11-28:** Phase 3 完成 - 线条选中、右键菜单、键盘微调、撤销/重做功能
- **2025-11-28:** Phase 4 完成 - 预览系统、切片生成、选择功能（全选/全不选/反选）
- **2025-11-28:** Phase 5 完成 - 导出功能、进度对话框、Isolate 批量处理
- **2025-11-28:** 重构 ROADMAP 为看板模式，添加新功能规划 (Settings, Smart Grid, Margins, Shortcuts)
- **2025-11-29:** 添加 Grid Algorithm Architecture 重构任务，作为智能算法的前置架构

---

## ⚠️ 已知风险与待决事项

1. **大图性能:** 10000x10000+ 像素图片的渲染和裁剪性能需要测试
2. **内存占用:** 多个大切片同时在内存中可能导致内存压力
3. **Isolate 限制:** `dart:ui` 的 `Image` 对象不能跨 Isolate 传递，需使用 `image` 包
4. **投影算法精度:** 智能网格检测对低对比度图片可能效果不佳
5. **TOML 解析:** 需验证 `toml` 包对复杂配置的支持程度

---

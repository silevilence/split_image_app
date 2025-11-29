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

### Refactor: 🏗️ Grid Algorithm Architecture (策略模式重构)
**优先级:** 🔴 高  
**预计工时:** 2-3h  
**依赖:** 无  
**被依赖:** 智能网格初始化算法 (Smart Grid Algorithm)

#### 📝 Description
在实现具体算法之前，先搭建可扩展的算法架构。使用策略模式 (Strategy Pattern) 解耦算法逻辑与 UI 代码，使未来新增算法的工作量最小化。

#### 🎯 Design Goals
- **解耦:** 算法逻辑与 UI 完全分离
- **可扩展:** 新增算法仅需 "1 Enum + 1 Switch Case + 1 Class File"
- **可配置:** 用户可在设置中选择默认算法

#### ✅ Checklist
- [ ] 定义 `GridGeneratorStrategy` 抽象基类/接口
- [ ] 定义标准输入参数: `GridGeneratorInput`
  - [ ] `Rect effectiveRect` - 有效区域
  - [ ] `int targetRows` - 目标行数
  - [ ] `int targetCols` - 目标列数
  - [ ] `Uint8List? pixelData` - 像素数据 (可选，供智能算法使用)
  - [ ] `int imageWidth`, `int imageHeight` - 图片尺寸
- [ ] 定义标准输出: `GridGeneratorResult`
  - [ ] `List<double> horizontalLines` - 水平线相对位置
  - [ ] `List<double> verticalLines` - 垂直线相对位置
- [ ] 创建 `GridAlgorithmType` 枚举
  - [ ] `fixedEvenSplit` - 均匀分割 (当前默认)
  - [ ] `projectionProfile` - 投影分析法 (预留)
  - [ ] `edgeDetection` - 边缘检测 (预留)
- [ ] 实现 `GridStrategyFactory` 工厂类
- [ ] 迁移现有均匀分割逻辑到 `FixedEvenSplitStrategy`
- [ ] 更新 `EditorProvider` 使用策略模式
- [ ] 在 `app_config.dart` 添加 `defaultAlgorithm` 配置项
- [ ] 在 `config.toml` 添加 `[grid]` 或 `[algorithm]` 配置节
- [ ] 在设置页面添加 "Default Algorithm" 下拉菜单

#### 🔧 Technical Considerations

**Strategy Pattern 结构:**
```dart
/// 算法类型枚举
enum GridAlgorithmType {
  fixedEvenSplit,      // 均匀分割
  projectionProfile,   // 投影分析
  edgeDetection,       // 边缘检测 (未来)
}

/// 算法输入参数
class GridGeneratorInput {
  final Rect effectiveRect;
  final int targetRows;
  final int targetCols;
  final int imageWidth;
  final int imageHeight;
  final Uint8List? pixelData; // 仅智能算法需要
}

/// 算法输出结果
class GridGeneratorResult {
  final List<double> horizontalLines;
  final List<double> verticalLines;
  final String? message; // 可选的提示信息
}

/// 策略抽象基类
abstract class GridGeneratorStrategy {
  GridAlgorithmType get type;
  String get displayName;
  String get description;
  
  /// 是否需要像素数据 (智能算法需要，均匀分割不需要)
  bool get requiresPixelData => false;
  
  /// 生成网格线 (可在 Isolate 中运行)
  Future<GridGeneratorResult> generate(GridGeneratorInput input);
}

/// 工厂类
class GridStrategyFactory {
  static GridGeneratorStrategy create(GridAlgorithmType type) {
    switch (type) {
      case GridAlgorithmType.fixedEvenSplit:
        return FixedEvenSplitStrategy();
      case GridAlgorithmType.projectionProfile:
        return ProjectionProfileStrategy(); // 后续实现
      case GridAlgorithmType.edgeDetection:
        throw UnimplementedError('Edge detection not yet implemented');
    }
  }
  
  static List<GridGeneratorStrategy> getAllStrategies() {
    return GridAlgorithmType.values
        .where((t) => t != GridAlgorithmType.edgeDetection) // 排除未实现的
        .map((t) => create(t))
        .toList();
  }
}
```

**config.toml 配置结构:**
```toml
[algorithm]
default = "fixedEvenSplit"  # fixedEvenSplit | projectionProfile

# 投影算法参数 (可选)
[algorithm.projectionProfile]
threshold = 0.3
minValleyWidth = 5
```

**EditorProvider 集成:**
```dart
class EditorProvider {
  GridAlgorithmType _algorithmType = GridAlgorithmType.fixedEvenSplit;
  
  Future<void> regenerateGrid() async {
    final strategy = GridStrategyFactory.create(_algorithmType);
    final input = GridGeneratorInput(...);
    final result = await strategy.generate(input);
    _horizontalLines = result.horizontalLines;
    _verticalLines = result.verticalLines;
    notifyListeners();
  }
}
```

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
│   └── app_config.dart               # 更新: 添加 AlgorithmConfig
└── widgets/
    └── settings_dialog.dart          # 更新: 添加算法选择 UI
```

---

### Feature: 🧠 智能网格初始化算法 (Smart Grid Algorithm)
**优先级:** 🔴 高  
**预计工时:** 4-6h  
**前置依赖:** Grid Algorithm Architecture (策略模式重构) ⬆️

#### 📝 Description
基于投影分析法 (Projection Profile) 自动识别贴纸缝隙，减少人工调整网格线的工作量。

#### ✅ Checklist
- [ ] 实现 Vertical Projection (垂直投影) 计算
- [ ] 实现 Horizontal Projection (水平投影) 计算
- [ ] 波谷检测算法 (Valley Detection)
- [ ] 网格线 Snap 到波谷中心
- [ ] 在 Isolate 中运行分析任务
- [ ] "Smart Detect" 按钮触发分析
- [ ] 分析进度指示器
- [ ] 阈值参数可调 (可选)

#### 🔧 Technical Considerations
- **Implementation:** 必须在 `compute` (Isolate) 中运行，避免阻塞 UI
- **Algorithm Steps:**
  ```dart
  // Step A: 计算投影
  List<int> verticalProjection = [];  // 每列的灰度/Alpha值求和
  List<int> horizontalProjection = []; // 每行的灰度/Alpha值求和
  
  // Step B: 寻找波谷 (低于平均值的区域)
  List<int> valleys = findValleys(projection, threshold);
  
  // Step C: 将网格线对齐到波谷中心
  List<double> gridLines = valleys.map((v) => v / imageSize).toList();
  ```
- **投影计算:** 
  - 对于 Alpha 通道: 透明区域 Alpha=0，贴纸区域 Alpha=255
  - 缝隙区域投影值低，贴纸区域投影值高
- **波谷检测:** 使用滑动窗口寻找局部最小值
- **边界处理:** 排除图片边缘的假波谷

#### 📁 产出文件
```
lib/
├── utils/
│   └── smart_grid_detector.dart
└── widgets/
    └── smart_detect_button.dart (可选)
```

---

### Feature: 快捷键与模式切换增强 (Shortcuts & Mode Switching)
**优先级:** 🟡 中  
**预计工时:** 2-3h

#### 📝 Description
引入 Flutter 标准的 Shortcuts/Actions 系统，提供更灵活的快捷键配置和模式切换。

#### ✅ Checklist
- [ ] 迁移至 Flutter `Shortcuts` / `Actions` 系统
- [ ] View Mode 快捷键切换 (预览/拖拽画布)
- [ ] Edit Mode 快捷键切换 (调整切割线)
- [ ] 快捷键与配置系统集成 (从 config.toml 读取)
- [ ] 快捷键冲突检测
- [ ] 快捷键提示 (Tooltip 显示快捷键)

#### 🔧 Technical Considerations
- **Shortcuts Widget 结构:**
  ```dart
  Shortcuts(
    shortcuts: {
      LogicalKeySet(LogicalKeyboardKey.keyV): ToggleModeIntent(),
      LogicalKeySet(LogicalKeyboardKey.delete): DeleteLineIntent(),
      // ...从配置文件读取
    },
    child: Actions(
      actions: {
        ToggleModeIntent: CallbackAction<ToggleModeIntent>(...),
        DeleteLineIntent: CallbackAction<DeleteLineIntent>(...),
      },
      child: ...,
    ),
  )
  ```
- **Intent 类定义:** 为每个操作创建对应的 Intent 类
- **配置同步:** 快捷键修改后实时更新 Shortcuts 映射

#### 📁 产出文件
```
lib/
├── shortcuts/
│   ├── app_intents.dart
│   └── shortcut_manager.dart
└── widgets/
    └── shortcut_wrapper.dart
```

---

## 🎯 新功能里程碑概览

| Feature | 优先级 | 预计工时 | 依赖 | 状态 |
|---------|--------|---------|------|------|
| 设置系统与数据持久化 | 🔴 高 | 3-4h | - | ✅ 已完成 |
| 图片边缘留白控制 | 🟡 中 | 2-3h | - | ✅ 已完成 |
| Grid Algorithm Architecture | 🔴 高 | 2-3h | - | 📅 计划中 |
| 智能网格初始化算法 | 🔴 高 | 4-6h | Architecture | 📅 计划中 |
| 快捷键与模式切换增强 | 🟡 中 | 2-3h | - | 📅 计划中 |

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

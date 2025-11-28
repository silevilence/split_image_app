# SmartGridSlicer - Development Roadmap

> **项目名称:** SmartGridSlicer  
> **目标平台:** Windows Desktop  
> **技术栈:** Flutter + Provider + fluent_ui  
> **创建日期:** 2025-11-28

---

## 📋 项目概览

SmartGridSlicer 是一款 Windows 桌面工具，用于将贴纸图集 (Sticker Sheet) 按网格切割成独立图片。核心特性包括：
- 交互式网格线拖拽调整
- 智能行列适配
- 批量预览与选择导出

---

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
- [ ] 导出设置面板 (输出目录、文件前缀)
- [ ] 目录选择器 (`file_picker` folder mode)
- [ ] 进度对话框 (显示 "Saving 3/20...")
- [ ] 使用 `compute` (Isolate) 执行批量裁剪保存
- [ ] 导出完成后 Snackbar 提示 + 打开文件夹按钮
- [ ] 错误处理与用户反馈
- [ ] 窗口标题显示当前文件名
- [ ] 应用图标与 Metadata

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
```

---

## 🎯 里程碑时间线 (预估)

| Phase | 名称 | 预计工时 | 状态 |
|-------|------|---------|------|
| 1 | 基础 UI 与图片加载 | 2-3h | ✅ 已完成 |
| 2 | 网格系统与智能适配 | 3-4h | ✅ 已完成 |
| 3 | 高级交互 | 2-3h | ✅ 已完成 |
| 4 | 预览系统与选择逻辑 | 3-4h | ✅ 已完成 |
| 5 | 导出工作流与打磨 | 2-3h | ⬜ 未开始 |

---

## 📝 开发笔记

> 此区域用于记录开发过程中的问题、解决方案和变更决策。

### 变更记录
- **2025-11-28:** 创建 ROADMAP.md
- **2025-11-28:** Phase 1 完成 - 基础 UI 与图片加载功能
- **2025-11-28:** Phase 2 完成 - 网格系统与拖拽交互功能，添加查看/编辑模式切换
- **2025-11-28:** Phase 3 完成 - 线条选中、右键菜单、键盘微调、撤销/重做功能
- **2025-11-28:** Phase 4 完成 - 预览系统、切片生成、选择功能（全选/全不选/反选）

---

## ⚠️ 已知风险与待决事项

1. **大图性能:** 10000x10000+ 像素图片的渲染和裁剪性能需要测试
2. **内存占用:** 多个大切片同时在内存中可能导致内存压力
3. **Isolate 限制:** `dart:ui` 的 `Image` 对象不能跨 Isolate 传递，需使用 `image` 包

---

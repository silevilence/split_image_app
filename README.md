# SmartGridSlicer

<p align="center">
  <img src="windows/runner/resources/app_icon.ico" width="128" height="128" alt="SmartGridSlicer Icon">
</p>

**SmartGridSlicer** 是一款 Windows 桌面工具，用于将贴纸图集 (Sticker Sheet) 按网格切割成独立图片。

## ✨ 功能特性

- 🖼️ **图片导入** - 支持拖拽或点击选择 PNG/JPG/WEBP 图片
- 📐 **智能网格** - 自动根据图片方向适配行列设置
- 🧠 **投影分析法** - 自动检测贴纸缝隙，智能识别边缘并设置边距
- 🔍 **边缘检测算法** - 基于 Sobel 算子识别贴纸边界，寻找低边缘密度区域
- 🎯 **可视化编辑** - 拖拽调整网格线位置，支持键盘微调
- 📏 **边距控制** - 排除图片四周留白，支持智能检测和手动设置
- 🧩 **可扩展算法** - 策略模式架构，支持多种网格生成算法
- ↩️ **撤销/重做** - 完整的编辑历史记录（最多 50 步）
- 👁️ **实时预览** - 生成切片缩略图，支持批量选择
- 🔎 **大图预览** - 双击/右键查看切片大图，支持左右键导航
- 📝 **自定义命名** - 可编辑每个切片的导出文件名
- 💾 **批量导出** - 后台处理，支持 PNG/JPG 格式，显示进度
- ⚙️ **设置系统** - TOML 配置文件，可自定义快捷键、默认参数
- ⌨️ **快捷键系统** - 基于 Flutter Shortcuts/Actions，支持自定义配置和冲突检测
- 📁 **路径记忆** - 自动记住上次导出目录
- 🏛️ **可调整面板** - 设置区与预览区可拖拽调整大小，自动记忆布局比例

## 📸 截图

<!-- 如有截图可在此添加 -->

## 🚀 快速开始

### 系统要求

- Windows 10/11
- 无需安装其他运行时

### 下载

从 [Releases](https://github.com/silevilence/split_image_app/releases) 页面下载最新版本。

### 从源码构建

```powershell
# 克隆仓库
git clone https://github.com/silevilence/split_image_app.git
cd split_image_app

# 安装依赖
flutter pub get

# 构建 Release 版本
flutter build windows

# 可执行文件位于
# build\windows\x64\runner\Release\split_image_app.exe
```

## 📖 使用说明

1. **导入图片** - 拖拽图片到窗口，或点击「选择图片」按钮
2. **设置边距**（可选）- 右键图片边缘位置，选择「设为左/右/上/下边距」排除留白区域
3. **设置网格** - 输入行数和列数，网格线会自动均分
4. **调整网格线** - 切换到「编辑」模式，拖拽网格线微调位置
5. **生成预览** - 点击「生成预览」查看切片效果
6. **选择切片** - 勾选需要导出的切片，支持拖拽批量选择
7. **导出** - 点击「导出选中」，选择输出目录和文件前缀

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `V` | 切换查看/编辑模式 |
| `Ctrl+Z` | 撤销 |
| `Ctrl+Y` | 重做 |
| `方向键` | 微调选中的网格线 |
| `Delete` | 删除选中的网格线 |
| `右键` | 上下文菜单（添加/删除网格线、设置边距） |

> 💡 快捷键可在设置中自定义

## 🛠️ 技术栈

- **框架**: Flutter 3.x (Windows Desktop)
- **UI 库**: fluent_ui (Windows 11 风格)
- **状态管理**: Provider
- **图片处理**: image 包 + Isolate 后台处理

## 📁 项目结构

```
lib/
├── main.dart              # 应用入口
├── models/                # 数据模型
│   ├── app_config.dart    # 配置数据模型
│   ├── grid_config.dart
│   ├── grid_line.dart
│   ├── editor_history.dart
│   ├── margins.dart       # 边距数据模型
│   └── slice_preview.dart
├── providers/             # 状态管理
│   ├── editor_provider.dart
│   └── preview_provider.dart
├── services/              # 服务层
│   └── config_service.dart # 配置读写服务
├── screens/
│   └── home_screen.dart   # 主页面
├── widgets/               # UI 组件
│   ├── editor_canvas.dart
│   ├── grid_painter.dart
│   ├── margins_input.dart # 边距输入组件
│   ├── preview_panel.dart
│   ├── preview_gallery.dart
│   ├── preview_modal.dart # 大图预览弹窗
│   ├── resizable_split_view.dart # 可调整分割视图
│   ├── slice_item.dart
│   ├── export_dialog.dart
│   ├── progress_dialog.dart
│   └── settings_dialog.dart # 设置对话框
└── utils/
    ├── coordinate_utils.dart
    └── image_processor.dart
```

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！


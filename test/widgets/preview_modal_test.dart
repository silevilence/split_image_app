import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:split_image_app/models/slice_preview.dart';
import 'package:split_image_app/widgets/preview_modal.dart';
import 'package:split_image_app/widgets/slice_item.dart';
import 'package:fluent_ui/fluent_ui.dart';

// 创建测试用的 1x1 像素 PNG 图片
Uint8List createTestPngBytes() {
  // 最小的有效 PNG 文件 (1x1 透明像素)
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT chunk
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND chunk
    0x42, 0x60, 0x82,
  ]);
}

SlicePreview createTestSlice({
  int row = 0,
  int col = 0,
  bool isSelected = true,
  String? customSuffix,
}) {
  return SlicePreview(
    row: row,
    col: col,
    region: const ui.Rect.fromLTWH(0, 0, 100, 100),
    thumbnailBytes: createTestPngBytes(),
    isSelected: isSelected,
    customSuffix: customSuffix,
  );
}

void main() {
  group('SlicePreview Model Tests', () {
    test('should create with default suffix', () {
      final slice = createTestSlice(row: 2, col: 3);
      expect(slice.customSuffix, equals('3_4')); // row+1, col+1
      expect(slice.defaultSuffix, equals('3_4'));
    });

    test('should create with custom suffix', () {
      final slice = createTestSlice(row: 0, col: 0, customSuffix: 'custom_name');
      expect(slice.customSuffix, equals('custom_name'));
      expect(slice.defaultSuffix, equals('1_1'));
    });

    test('should reset suffix to default', () {
      final slice = createTestSlice(row: 1, col: 2, customSuffix: 'modified');
      expect(slice.customSuffix, equals('modified'));
      slice.resetSuffix();
      expect(slice.customSuffix, equals('2_3'));
    });

    test('copyWith should preserve values', () {
      final original = createTestSlice(row: 1, col: 2, isSelected: true, customSuffix: 'test');
      final copied = original.copyWith(isSelected: false);
      
      expect(copied.row, equals(1));
      expect(copied.col, equals(2));
      expect(copied.isSelected, equals(false));
      expect(copied.customSuffix, equals('test'));
    });

    test('copyWith should update suffix', () {
      final original = createTestSlice(customSuffix: 'old');
      final copied = original.copyWith(customSuffix: 'new');
      
      expect(copied.customSuffix, equals('new'));
      expect(original.customSuffix, equals('old')); // Original unchanged
    });
  });

  group('SliceItem Widget Tests', () {
    testWidgets('should display slice information', (tester) async {
      final slice = createTestSlice(row: 0, col: 0, customSuffix: 'test_suffix');

      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Center(
              child: SizedBox(
                width: 300,
                child: SliceItem(
                  slice: slice,
                  isSelected: true,
                ),
              ),
            ),
          ),
        ),
      );

      // 检查后缀名显示
      expect(find.text('test_suffix'), findsOneWidget);
      // 检查尺寸信息
      expect(find.text('100 × 100 px'), findsOneWidget);
    });

    testWidgets('should trigger selection toggle on checkbox area click', (tester) async {
      final slice = createTestSlice(isSelected: true);
      bool? toggledValue;

      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Center(
              child: SizedBox(
                width: 300,
                child: SliceItem(
                  slice: slice,
                  isSelected: true,
                  onSelectionToggle: (value) => toggledValue = value,
                ),
              ),
            ),
          ),
        ),
      );

      // 点击勾选框区域（Checkbox 被包裹在 Listener 中）
      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);
      
      // 由于 Checkbox 被 IgnorePointer 包裹，我们需要点击其父组件
      // 这里我们通过点击图片来触发选择
      await tester.tap(find.byType(Image).first);
      await tester.pump();

      expect(toggledValue, equals(false)); // 从 true 切换到 false
    });

    testWidgets('should have preview button', (tester) async {
      final slice = createTestSlice();

      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Center(
              child: SizedBox(
                width: 350,
                child: SliceItem(
                  slice: slice,
                  isSelected: true,
                  onPreviewRequested: () {},
                ),
              ),
            ),
          ),
        ),
      );

      // 查找预览按钮（full_screen 图标）
      final fullScreenIcon = find.byIcon(FluentIcons.full_screen);
      expect(fullScreenIcon, findsOneWidget);

      // 验证图标在 IconButton 中
      final iconButton = find.ancestor(
        of: fullScreenIcon,
        matching: find.byType(IconButton),
      );
      expect(iconButton, findsOneWidget);
    });

    testWidgets('should show context menu items on right click', (tester) async {
      final slice = createTestSlice();

      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Center(
              child: SizedBox(
                width: 300,
                child: SliceItem(
                  slice: slice,
                  isSelected: true,
                ),
              ),
            ),
          ),
        ),
      );

      // 右键点击
      final sliceWidget = find.byType(SliceItem);
      await tester.tap(sliceWidget, buttons: 2); // 右键
      await tester.pumpAndSettle();

      // 检查菜单项
      expect(find.text('查看大图'), findsOneWidget);
      expect(find.text('取消导出'), findsOneWidget); // 因为 isSelected = true
      expect(find.text('编辑后缀'), findsOneWidget);
    });
  });

  group('PreviewModal Widget Tests', () {
    testWidgets('should display slice preview', (tester) async {
      // 设置更大的测试窗口尺寸
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final slices = [
        createTestSlice(row: 0, col: 0, customSuffix: 'first'),
        createTestSlice(row: 0, col: 1, customSuffix: 'second'),
        createTestSlice(row: 1, col: 0, customSuffix: 'third'),
      ];

      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Builder(
              builder: (context) => Button(
                child: const Text('Open Modal'),
                onPressed: () => PreviewModal.show(
                  context: context,
                  slices: slices,
                  initialIndex: 0,
                ),
              ),
            ),
          ),
        ),
      );

      // 打开模态框
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // 检查标题
      expect(find.text('切片预览 (1/3)'), findsOneWidget);
      // 检查尺寸信息
      expect(find.text('100 × 100 px'), findsOneWidget);
    });

    testWidgets('should navigate between slices', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final slices = [
        createTestSlice(row: 0, col: 0, customSuffix: 'first'),
        createTestSlice(row: 0, col: 1, customSuffix: 'second'),
      ];

      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Builder(
              builder: (context) => Button(
                child: const Text('Open Modal'),
                onPressed: () => PreviewModal.show(
                  context: context,
                  slices: slices,
                  initialIndex: 0,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // 初始状态
      expect(find.text('切片预览 (1/2)'), findsOneWidget);

      // 点击下一张按钮
      final nextButton = find.byIcon(FluentIcons.chevron_right);
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // 验证导航成功
      expect(find.text('切片预览 (2/2)'), findsOneWidget);
    });

    testWidgets('should toggle export selection', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final slices = [
        createTestSlice(isSelected: true),
      ];
      bool? selectionChanged;
      int? changedIndex;

      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Builder(
              builder: (context) => Button(
                child: const Text('Open Modal'),
                onPressed: () => PreviewModal.show(
                  context: context,
                  slices: slices,
                  initialIndex: 0,
                  onSelectionChanged: (index, isSelected) {
                    changedIndex = index;
                    selectionChanged = isSelected;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // 找到并点击导出复选框
      final checkbox = find.widgetWithText(Checkbox, '导出此切片');
      expect(checkbox, findsOneWidget);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      expect(changedIndex, equals(0));
      expect(selectionChanged, equals(false)); // 从 true 切换到 false
    });

    testWidgets('should update suffix', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final slices = [
        createTestSlice(customSuffix: 'original'),
      ];
      String? newSuffix;
      int? changedIndex;

      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Builder(
              builder: (context) => Button(
                child: const Text('Open Modal'),
                onPressed: () => PreviewModal.show(
                  context: context,
                  slices: slices,
                  initialIndex: 0,
                  onSuffixChanged: (index, suffix) {
                    changedIndex = index;
                    newSuffix = suffix;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // 找到后缀输入框并修改
      final textBox = find.byType(TextBox).last;
      await tester.enterText(textBox, 'modified');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(changedIndex, equals(0));
      expect(newSuffix, equals('modified'));
    });

    testWidgets('should close on escape key', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final slices = [createTestSlice()];

      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Builder(
              builder: (context) => Button(
                child: const Text('Open Modal'),
                onPressed: () => PreviewModal.show(
                  context: context,
                  slices: slices,
                  initialIndex: 0,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // 验证模态框打开
      expect(find.text('切片预览 (1/1)'), findsOneWidget);

      // 按 Escape 关闭
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // 验证模态框关闭
      expect(find.text('切片预览 (1/1)'), findsNothing);
    });
  });
}

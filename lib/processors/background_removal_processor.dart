import 'dart:collection';
import 'dart:typed_data';

import 'processor_io.dart';
import 'processor_param.dart';
import 'image_processor.dart';

/// 背景移除处理器
///
/// 使用魔棒算法（Flood Fill）从图片四角开始检测并移除背景色。
/// 支持自定义阈值和替换色。
class BackgroundRemovalProcessor extends ImageProcessor {
  @override
  final ProcessorType type = ProcessorType.backgroundRemoval;

  BackgroundRemovalProcessor({
    required super.instanceId,
    super.customName,
    super.globalParams,
  });

  @override
  List<ProcessorParamDef> get paramDefinitions => [
    // Global: 阈值
    const ProcessorParamDef(
      id: 'threshold',
      displayName: '阈值',
      description: '背景检测的颜色容差值，越大越宽松',
      type: ParamType.integer,
      defaultValue: 30,
      minValue: 0,
      maxValue: 255,
      supportsPerImageOverride: false,
    ),
    // Global: 替换色/透明
    const ProcessorParamDef(
      id: 'replaceColor',
      displayName: '替换色',
      description: '背景移除后的填充色，透明=0x00000000',
      type: ParamType.color,
      defaultValue: 0x00000000, // 透明
      supportsPerImageOverride: false,
    ),
  ];

  @override
  Future<ProcessorOutput> process(
    ProcessorInput input,
    ProcessorParams params,
  ) async {
    final stopwatch = Stopwatch()..start();

    final threshold = getParam<int>(params, 'threshold');
    final replaceColor = getParam<int>(params, 'replaceColor');

    // 复制像素数据（不修改原数据）
    final pixels = Uint8List.fromList(input.pixels);
    final width = input.width;
    final height = input.height;

    // 提取替换色的 RGBA 分量
    final replaceA = (replaceColor >> 24) & 0xFF;
    final replaceR = (replaceColor >> 16) & 0xFF;
    final replaceG = (replaceColor >> 8) & 0xFF;
    final replaceB = replaceColor & 0xFF;

    // 已访问标记
    final visited = List<bool>.filled(width * height, false);

    // 从四个角落开始 flood fill
    final corners = [
      (0, 0), // 左上
      (width - 1, 0), // 右上
      (0, height - 1), // 左下
      (width - 1, height - 1), // 右下
    ];

    int changedPixels = 0;

    for (final corner in corners) {
      final startX = corner.$1;
      final startY = corner.$2;
      final startIdx = startY * width + startX;

      // 如果该角落已访问过，跳过
      if (visited[startIdx]) continue;

      // 获取起始点颜色作为背景色
      final offset = startIdx * 4;
      final bgR = pixels[offset];
      final bgG = pixels[offset + 1];
      final bgB = pixels[offset + 2];
      final bgA = pixels[offset + 3];

      // BFS Flood Fill
      final queue = Queue<int>();
      queue.add(startIdx);
      visited[startIdx] = true;

      while (queue.isNotEmpty) {
        final idx = queue.removeFirst();
        final x = idx % width;
        final y = idx ~/ width;
        final pixelOffset = idx * 4;

        // 获取当前像素颜色
        final r = pixels[pixelOffset];
        final g = pixels[pixelOffset + 1];
        final b = pixels[pixelOffset + 2];
        final a = pixels[pixelOffset + 3];

        // 检查是否与背景色相似
        if (_isColorSimilar(r, g, b, a, bgR, bgG, bgB, bgA, threshold)) {
          // 替换为目标颜色
          pixels[pixelOffset] = replaceR;
          pixels[pixelOffset + 1] = replaceG;
          pixels[pixelOffset + 2] = replaceB;
          pixels[pixelOffset + 3] = replaceA;
          changedPixels++;

          // 将相邻的 4 个像素加入队列
          final neighbors = [
            (x - 1, y), // 左
            (x + 1, y), // 右
            (x, y - 1), // 上
            (x, y + 1), // 下
          ];

          for (final neighbor in neighbors) {
            final nx = neighbor.$1;
            final ny = neighbor.$2;

            if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
              final nIdx = ny * width + nx;
              if (!visited[nIdx]) {
                visited[nIdx] = true;
                queue.add(nIdx);
              }
            }
          }
        }
      }
    }

    stopwatch.stop();

    // 如果没有变更，返回未修改的输出
    if (changedPixels == 0) {
      return ProcessorOutput.unchanged(input, processorId: instanceId);
    }

    return ProcessorOutput(
      pixels: pixels,
      width: width,
      height: height,
      hasChanges: true,
      processingTimeMs: stopwatch.elapsedMilliseconds,
      processorId: instanceId,
      metadata: {...input.metadata, 'changedPixels': changedPixels},
    );
  }

  /// 检查两个颜色是否相似（在阈值范围内）
  bool _isColorSimilar(
    int r1,
    int g1,
    int b1,
    int a1,
    int r2,
    int g2,
    int b2,
    int a2,
    int threshold,
  ) {
    // 计算颜色差异（使用欧氏距离的简化版本）
    final dr = (r1 - r2).abs();
    final dg = (g1 - g2).abs();
    final db = (b1 - b2).abs();
    final da = (a1 - a2).abs();

    // 如果任一通道差异超过阈值，认为颜色不同
    return dr <= threshold &&
        dg <= threshold &&
        db <= threshold &&
        da <= threshold;
  }
}

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/grid_algorithm_type.dart';
import '../models/grid_generator_input.dart';
import '../models/grid_generator_result.dart';
import 'grid_generator_strategy.dart';

/// 投影分析策略
///
/// 基于投影分析法 (Projection Profile) 自动识别贴纸缝隙。
/// 通过计算水平/垂直方向的像素投影值，找到波谷（低值区域）作为分割线位置。
class ProjectionProfileStrategy extends GridGeneratorStrategy {
  /// 波谷检测阈值 (相对于平均值的比例)
  /// 值越小，越容易检测到波谷
  final double valleyThreshold;

  /// 最小波谷宽度（像素）
  /// 用于过滤噪声产生的假波谷
  final int minValleyWidth;

  /// 波谷合并距离（像素）
  /// 相邻波谷距离小于此值时合并为一个
  final int mergeDistance;

  ProjectionProfileStrategy({
    this.valleyThreshold = 0.3,
    this.minValleyWidth = 3,
    this.mergeDistance = 10,
  });

  @override
  GridAlgorithmType get type => GridAlgorithmType.projectionProfile;

  @override
  bool get requiresPixelData => true;

  @override
  Future<GridGeneratorResult> generate(GridGeneratorInput input) async {
    debugPrint('[ProjectionProfile] generate() called');
    debugPrint('[ProjectionProfile] hasPixelData: ${input.hasPixelData}');
    debugPrint(
      '[ProjectionProfile] imageSize: ${input.imageWidth}x${input.imageHeight}',
    );
    debugPrint('[ProjectionProfile] effectiveRect: ${input.effectiveRect}');
    debugPrint(
      '[ProjectionProfile] target: ${input.targetRows} rows x ${input.targetCols} cols',
    );

    if (!input.hasPixelData) {
      debugPrint('[ProjectionProfile] ERROR: No pixel data!');
      return GridGeneratorResult.failure('投影分析算法需要像素数据');
    }

    debugPrint(
      '[ProjectionProfile] pixelData length: ${input.pixelData!.length}',
    );

    // 在 Isolate 中运行计算密集型任务
    final result = await compute(
      _computeProjectionProfile,
      _ProjectionInput(
        pixelData: input.pixelData!,
        imageWidth: input.imageWidth,
        imageHeight: input.imageHeight,
        effectiveLeft: input.effectiveRect.left.toInt(),
        effectiveTop: input.effectiveRect.top.toInt(),
        effectiveWidth: input.effectiveRect.width.toInt(),
        effectiveHeight: input.effectiveRect.height.toInt(),
        targetRows: input.targetRows,
        targetCols: input.targetCols,
        valleyThreshold: valleyThreshold,
        minValleyWidth: minValleyWidth,
        mergeDistance: mergeDistance,
        hasUserMargins: input.hasUserMargins,
      ),
    );

    return result;
  }
}

/// Isolate 计算输入参数
class _ProjectionInput {
  final Uint8List pixelData;
  final int imageWidth;
  final int imageHeight;
  final int effectiveLeft;
  final int effectiveTop;
  final int effectiveWidth;
  final int effectiveHeight;
  final int targetRows;
  final int targetCols;
  final double valleyThreshold;
  final int minValleyWidth;
  final int mergeDistance;
  final bool hasUserMargins;

  _ProjectionInput({
    required this.pixelData,
    required this.imageWidth,
    required this.imageHeight,
    required this.effectiveLeft,
    required this.effectiveTop,
    required this.effectiveWidth,
    required this.effectiveHeight,
    required this.targetRows,
    required this.targetCols,
    required this.valleyThreshold,
    required this.minValleyWidth,
    required this.mergeDistance,
    required this.hasUserMargins,
  });
}

/// 在 Isolate 中执行投影分析计算
GridGeneratorResult _computeProjectionProfile(_ProjectionInput input) {
  try {
    // 检测背景类型（透明背景 vs 浅色背景）
    final backgroundType = _detectBackgroundType(
      input.pixelData,
      input.imageWidth,
      input.imageHeight,
      input.effectiveLeft,
      input.effectiveTop,
      input.effectiveWidth,
      input.effectiveHeight,
    );

    // 计算水平投影（用于检测水平分割线）
    final horizontalProjection = _computeHorizontalProjection(
      input.pixelData,
      input.imageWidth,
      input.imageHeight,
      input.effectiveLeft,
      input.effectiveTop,
      input.effectiveWidth,
      input.effectiveHeight,
      backgroundType,
    );

    // 计算垂直投影（用于检测垂直分割线）
    final verticalProjection = _computeVerticalProjection(
      input.pixelData,
      input.imageWidth,
      input.imageHeight,
      input.effectiveLeft,
      input.effectiveTop,
      input.effectiveWidth,
      input.effectiveHeight,
      backgroundType,
    );

    // 检测水平方向的波谷（对应水平分割线）
    final horizontalValleys = _detectValleys(
      horizontalProjection,
      input.valleyThreshold,
      input.minValleyWidth,
      input.mergeDistance,
    );

    // 检测垂直方向的波谷（对应垂直分割线）
    final verticalValleys = _detectValleys(
      verticalProjection,
      input.valleyThreshold,
      input.minValleyWidth,
      input.mergeDistance,
    );

    // 只有在用户没有手动设置边距时，才检测边缘波谷
    SuggestedMargins suggestedMargins;
    List<_Valley> workingHorizontalValleys;
    List<_Valley> workingVerticalValleys;
    int innerHeight;
    int innerWidth;
    int marginTop;
    int marginLeft;

    if (!input.hasUserMargins) {
      // 用户没有设置边距，检测边缘波谷并建议 margin
      suggestedMargins = _detectEdgeMargins(
        horizontalValleys,
        verticalValleys,
        input.effectiveWidth,
        input.effectiveHeight,
        input.effectiveLeft,
        input.effectiveTop,
      );

      // 过滤掉边缘波谷
      workingHorizontalValleys = _filterEdgeValleys(
        horizontalValleys,
        input.effectiveHeight,
        suggestedMargins.top,
        suggestedMargins.bottom,
      );
      workingVerticalValleys = _filterEdgeValleys(
        verticalValleys,
        input.effectiveWidth,
        suggestedMargins.left,
        suggestedMargins.right,
      );

      // 计算内部有效区域（去掉边缘后）
      innerHeight =
          input.effectiveHeight -
          suggestedMargins.top -
          suggestedMargins.bottom;
      innerWidth =
          input.effectiveWidth - suggestedMargins.left - suggestedMargins.right;
      marginTop = suggestedMargins.top;
      marginLeft = suggestedMargins.left;

      // 调整波谷位置（相对于内部区域）
      workingHorizontalValleys = workingHorizontalValleys
          .map((v) {
            return _Valley(
              center: v.center - marginTop,
              start: v.start - marginTop,
              end: v.end - marginTop,
              depth: v.depth,
            );
          })
          .where((v) => v.center > 0 && v.center < innerHeight)
          .toList();

      workingVerticalValleys = workingVerticalValleys
          .map((v) {
            return _Valley(
              center: v.center - marginLeft,
              start: v.start - marginLeft,
              end: v.end - marginLeft,
              depth: v.depth,
            );
          })
          .where((v) => v.center > 0 && v.center < innerWidth)
          .toList();
    } else {
      // 用户已设置边距，直接在有效区域内工作，不检测边缘
      suggestedMargins = const SuggestedMargins();
      workingHorizontalValleys = horizontalValleys;
      workingVerticalValleys = verticalValleys;
      innerHeight = input.effectiveHeight;
      innerWidth = input.effectiveWidth;
      marginTop = 0;
      marginLeft = 0;
    }

    // 选择最佳的分割线位置（基于内部区域）
    final horizontalLines = _selectBestLines(
      workingHorizontalValleys,
      input.targetRows - 1,
      innerHeight,
    );

    final verticalLines = _selectBestLines(
      workingVerticalValleys,
      input.targetCols - 1,
      innerWidth,
    );

    // 将内部区域的位置转换为整个图片的相对位置
    final normalizedHorizontalLines = horizontalLines.map((pos) {
      final actualY = input.effectiveTop + marginTop + pos;
      return actualY / input.imageHeight;
    }).toList();

    final normalizedVerticalLines = verticalLines.map((pos) {
      final actualX = input.effectiveLeft + marginLeft + pos;
      return actualX / input.imageWidth;
    }).toList();

    // 排序
    normalizedHorizontalLines.sort();
    normalizedVerticalLines.sort();

    final message =
        '检测到 ${horizontalValleys.length} 个水平波谷, '
        '${verticalValleys.length} 个垂直波谷 (背景类型: ${backgroundType.name})'
        '${suggestedMargins.hasMargins ? ', 建议边距: $suggestedMargins' : ''}';

    return GridGeneratorResult.success(
      horizontalLines: normalizedHorizontalLines,
      verticalLines: normalizedVerticalLines,
      message: message,
      suggestedMargins: suggestedMargins,
    );
  } catch (e) {
    return GridGeneratorResult.failure('投影分析失败: $e');
  }
}

/// 检测边缘波谷，转换为建议的 margin
///
/// 使用波谷的中心位置作为边距，而不是结束位置，避免切入内容
SuggestedMargins _detectEdgeMargins(
  List<_Valley> horizontalValleys,
  List<_Valley> verticalValleys,
  int effectiveWidth,
  int effectiveHeight,
  int effectiveLeft,
  int effectiveTop,
) {
  // 边缘检测范围（首尾 12% 范围内的波谷视为边缘）
  final hEdgeRange = (effectiveHeight * 0.12).toInt();
  final vEdgeRange = (effectiveWidth * 0.12).toInt();

  int topMargin = 0;
  int bottomMargin = 0;
  int leftMargin = 0;
  int rightMargin = 0;

  // 检测顶部边缘波谷
  for (final valley in horizontalValleys) {
    if (valley.center < hEdgeRange) {
      // 使用波谷的中心位置作为边距（更保守，避免切入内容）
      topMargin = math.max(topMargin, valley.center);
    }
  }

  // 检测底部边缘波谷
  for (final valley in horizontalValleys) {
    if (valley.center > effectiveHeight - hEdgeRange) {
      // 使用从波谷中心到底部的距离作为边距
      bottomMargin = math.max(bottomMargin, effectiveHeight - valley.center);
    }
  }

  // 检测左侧边缘波谷
  for (final valley in verticalValleys) {
    if (valley.center < vEdgeRange) {
      leftMargin = math.max(leftMargin, valley.center);
    }
  }

  // 检测右侧边缘波谷
  for (final valley in verticalValleys) {
    if (valley.center > effectiveWidth - vEdgeRange) {
      rightMargin = math.max(rightMargin, effectiveWidth - valley.center);
    }
  }

  return SuggestedMargins(
    top: topMargin,
    bottom: bottomMargin,
    left: leftMargin,
    right: rightMargin,
  );
}

/// 过滤掉边缘波谷
List<_Valley> _filterEdgeValleys(
  List<_Valley> valleys,
  int totalSize,
  int startMargin,
  int endMargin,
) {
  return valleys.where((v) {
    return v.center >= startMargin && v.center <= totalSize - endMargin;
  }).toList();
}

/// 背景类型枚举
enum _BackgroundType {
  /// 透明背景（Alpha 通道有变化）
  transparent,

  /// 浅色背景（高亮度区域为背景）
  light,

  /// 深色背景（低亮度区域为背景）
  dark,
}

/// 检测背景类型
_BackgroundType _detectBackgroundType(
  Uint8List pixelData,
  int imageWidth,
  int imageHeight,
  int effectiveLeft,
  int effectiveTop,
  int effectiveWidth,
  int effectiveHeight,
) {
  // 采样边缘像素来判断背景类型
  int transparentCount = 0;
  int totalSamples = 0;
  double totalBrightness = 0;

  // 采样四个边缘
  // 上边缘
  for (int x = effectiveLeft; x < effectiveLeft + effectiveWidth; x += 10) {
    final idx = (effectiveTop * imageWidth + x) * 4;
    if (idx + 3 < pixelData.length) {
      final alpha = pixelData[idx + 3];
      if (alpha < 128) transparentCount++;
      final r = pixelData[idx];
      final g = pixelData[idx + 1];
      final b = pixelData[idx + 2];
      totalBrightness += (r + g + b) / 3;
      totalSamples++;
    }
  }

  // 下边缘
  final bottomY = effectiveTop + effectiveHeight - 1;
  for (int x = effectiveLeft; x < effectiveLeft + effectiveWidth; x += 10) {
    final idx = (bottomY * imageWidth + x) * 4;
    if (idx + 3 < pixelData.length) {
      final alpha = pixelData[idx + 3];
      if (alpha < 128) transparentCount++;
      final r = pixelData[idx];
      final g = pixelData[idx + 1];
      final b = pixelData[idx + 2];
      totalBrightness += (r + g + b) / 3;
      totalSamples++;
    }
  }

  // 左边缘
  for (int y = effectiveTop; y < effectiveTop + effectiveHeight; y += 10) {
    final idx = (y * imageWidth + effectiveLeft) * 4;
    if (idx + 3 < pixelData.length) {
      final alpha = pixelData[idx + 3];
      if (alpha < 128) transparentCount++;
      final r = pixelData[idx];
      final g = pixelData[idx + 1];
      final b = pixelData[idx + 2];
      totalBrightness += (r + g + b) / 3;
      totalSamples++;
    }
  }

  // 右边缘
  final rightX = effectiveLeft + effectiveWidth - 1;
  for (int y = effectiveTop; y < effectiveTop + effectiveHeight; y += 10) {
    final idx = (y * imageWidth + rightX) * 4;
    if (idx + 3 < pixelData.length) {
      final alpha = pixelData[idx + 3];
      if (alpha < 128) transparentCount++;
      final r = pixelData[idx];
      final g = pixelData[idx + 1];
      final b = pixelData[idx + 2];
      totalBrightness += (r + g + b) / 3;
      totalSamples++;
    }
  }

  // 判断背景类型
  if (totalSamples == 0) return _BackgroundType.light;

  final transparentRatio = transparentCount / totalSamples;
  final avgBrightness = totalBrightness / totalSamples;

  // 如果超过 30% 的边缘像素是透明的，认为是透明背景
  if (transparentRatio > 0.3) {
    return _BackgroundType.transparent;
  }

  // 根据平均亮度判断是浅色还是深色背景
  if (avgBrightness > 180) {
    return _BackgroundType.light;
  } else if (avgBrightness < 75) {
    return _BackgroundType.dark;
  }

  // 默认按浅色背景处理（大多数贴纸图集都是白色背景）
  return _BackgroundType.light;
}

/// 计算水平投影（每行的像素值总和）
/// 对于透明背景：使用 Alpha 通道（透明区域值低）
/// 对于浅色背景：使用反转亮度（浅色区域值低，代表背景/缝隙）
/// 对于深色背景：使用亮度（深色区域值低，代表背景/缝隙）
List<double> _computeHorizontalProjection(
  Uint8List pixelData,
  int imageWidth,
  int imageHeight,
  int effectiveLeft,
  int effectiveTop,
  int effectiveWidth,
  int effectiveHeight,
  _BackgroundType backgroundType,
) {
  final projection = List<double>.filled(effectiveHeight, 0);

  for (int y = 0; y < effectiveHeight; y++) {
    double sum = 0;
    final imageY = effectiveTop + y;

    for (int x = 0; x < effectiveWidth; x++) {
      final imageX = effectiveLeft + x;
      final pixelIndex = (imageY * imageWidth + imageX) * 4;

      if (pixelIndex + 3 < pixelData.length) {
        final r = pixelData[pixelIndex];
        final g = pixelData[pixelIndex + 1];
        final b = pixelData[pixelIndex + 2];
        final alpha = pixelData[pixelIndex + 3];

        switch (backgroundType) {
          case _BackgroundType.transparent:
            // 透明背景：使用 Alpha 通道
            sum += alpha;
            break;
          case _BackgroundType.light:
            // 浅色背景：使用反转亮度（贴纸区域颜色深，值大）
            // 背景区域（白色）亮度高 → 反转后值小
            final brightness = (r + g + b) / 3;
            sum += (255 - brightness);
            break;
          case _BackgroundType.dark:
            // 深色背景：使用亮度（贴纸区域颜色浅，值大）
            final brightness = (r + g + b) / 3;
            sum += brightness;
            break;
        }
      }
    }

    // 归一化到 0-1 范围
    projection[y] = sum / (effectiveWidth * 255);
  }

  return projection;
}

/// 计算垂直投影（每列的像素值总和）
List<double> _computeVerticalProjection(
  Uint8List pixelData,
  int imageWidth,
  int imageHeight,
  int effectiveLeft,
  int effectiveTop,
  int effectiveWidth,
  int effectiveHeight,
  _BackgroundType backgroundType,
) {
  final projection = List<double>.filled(effectiveWidth, 0);

  for (int x = 0; x < effectiveWidth; x++) {
    double sum = 0;
    final imageX = effectiveLeft + x;

    for (int y = 0; y < effectiveHeight; y++) {
      final imageY = effectiveTop + y;
      final pixelIndex = (imageY * imageWidth + imageX) * 4;

      if (pixelIndex + 3 < pixelData.length) {
        final r = pixelData[pixelIndex];
        final g = pixelData[pixelIndex + 1];
        final b = pixelData[pixelIndex + 2];
        final alpha = pixelData[pixelIndex + 3];

        switch (backgroundType) {
          case _BackgroundType.transparent:
            sum += alpha;
            break;
          case _BackgroundType.light:
            final brightness = (r + g + b) / 3;
            sum += (255 - brightness);
            break;
          case _BackgroundType.dark:
            final brightness = (r + g + b) / 3;
            sum += brightness;
            break;
        }
      }
    }

    projection[x] = sum / (effectiveHeight * 255);
  }

  return projection;
}

/// 检测波谷（投影值较低的区域）
List<_Valley> _detectValleys(
  List<double> projection,
  double threshold,
  int minWidth,
  int mergeDistance,
) {
  if (projection.isEmpty) return [];

  // 计算平均值和阈值
  final mean = projection.reduce((a, b) => a + b) / projection.length;
  final valleyThreshold = mean * threshold;

  // 寻找低于阈值的区域
  final valleys = <_Valley>[];
  int? valleyStart;

  for (int i = 0; i < projection.length; i++) {
    final isLow = projection[i] < valleyThreshold;

    if (isLow && valleyStart == null) {
      valleyStart = i;
    } else if (!isLow && valleyStart != null) {
      final width = i - valleyStart;
      if (width >= minWidth) {
        // 找到波谷中心（最小值位置）
        int minIndex = valleyStart;
        double minValue = projection[valleyStart];
        for (int j = valleyStart; j < i; j++) {
          if (projection[j] < minValue) {
            minValue = projection[j];
            minIndex = j;
          }
        }
        valleys.add(
          _Valley(
            center: minIndex,
            start: valleyStart,
            end: i,
            depth: mean - minValue,
          ),
        );
      }
      valleyStart = null;
    }
  }

  // 处理结尾的波谷
  if (valleyStart != null) {
    final width = projection.length - valleyStart;
    if (width >= minWidth) {
      int minIndex = valleyStart;
      double minValue = projection[valleyStart];
      for (int j = valleyStart; j < projection.length; j++) {
        if (projection[j] < minValue) {
          minValue = projection[j];
          minIndex = j;
        }
      }
      valleys.add(
        _Valley(
          center: minIndex,
          start: valleyStart,
          end: projection.length,
          depth: mean - minValue,
        ),
      );
    }
  }

  // 合并相邻的波谷
  if (valleys.length > 1 && mergeDistance > 0) {
    final merged = <_Valley>[];
    var current = valleys[0];

    for (int i = 1; i < valleys.length; i++) {
      if (valleys[i].start - current.end <= mergeDistance) {
        // 合并波谷
        final newCenter = (current.center + valleys[i].center) ~/ 2;
        current = _Valley(
          center: newCenter,
          start: current.start,
          end: valleys[i].end,
          depth: math.max(current.depth, valleys[i].depth),
        );
      } else {
        merged.add(current);
        current = valleys[i];
      }
    }
    merged.add(current);
    return merged;
  }

  return valleys;
}

/// 从检测到的波谷中选择最佳的分割线位置
///
/// 选择算法：优先选择深度大且位置均匀分布的波谷
List<double> _selectBestLines(
  List<_Valley> valleys,
  int targetCount,
  int totalSize,
) {
  if (targetCount <= 0) {
    return [];
  }

  if (valleys.isEmpty) {
    // 没有检测到波谷，回退到均匀分割
    return List.generate(targetCount, (i) {
      return (i + 1) * totalSize / (targetCount + 1);
    });
  }

  if (valleys.length <= targetCount) {
    // 波谷数量不够，直接使用所有波谷，剩余的均匀填充
    final result = valleys.map((v) => v.center.toDouble()).toList();
    result.sort();

    // 如果波谷数量不足，在空隙中均匀填充
    while (result.length < targetCount) {
      // 找到最大的空隙
      double maxGap = 0;
      int maxGapIndex = 0;

      // 检查开头到第一条线
      if (result.isNotEmpty && result[0] > maxGap) {
        maxGap = result[0];
        maxGapIndex = -1; // -1 表示在开头插入
      }

      // 检查相邻线之间的空隙
      for (int i = 0; i < result.length - 1; i++) {
        final gap = result[i + 1] - result[i];
        if (gap > maxGap) {
          maxGap = gap;
          maxGapIndex = i;
        }
      }

      // 检查最后一条线到末尾
      if (result.isNotEmpty) {
        final endGap = totalSize - result.last;
        if (endGap > maxGap) {
          maxGap = endGap;
          maxGapIndex = result.length - 1; // 在末尾插入
        }
      }

      // 在最大空隙中间插入一条线
      if (maxGapIndex == -1) {
        result.insert(0, result[0] / 2);
      } else if (maxGapIndex == result.length - 1) {
        result.add((result.last + totalSize) / 2);
      } else {
        result.insert(
          maxGapIndex + 1,
          (result[maxGapIndex] + result[maxGapIndex + 1]) / 2,
        );
      }
    }

    return result;
  }

  // 波谷数量足够，使用改进的选择算法
  // 思路：将区域均匀分成 targetCount+1 段，每段选择一个最深的波谷
  final segmentSize = totalSize / (targetCount + 1);
  final selectedLines = <double>[];

  for (int i = 1; i <= targetCount; i++) {
    final idealPosition = i * segmentSize;
    final searchRangeStart = idealPosition - segmentSize * 0.6;
    final searchRangeEnd = idealPosition + segmentSize * 0.6;

    // 在搜索范围内找到最深的波谷
    _Valley? bestValley;
    for (final valley in valleys) {
      if (valley.center >= searchRangeStart &&
          valley.center <= searchRangeEnd) {
        if (bestValley == null || valley.depth > bestValley.depth) {
          bestValley = valley;
        }
      }
    }

    if (bestValley != null) {
      selectedLines.add(bestValley.center.toDouble());
    } else {
      // 该区域没有波谷，使用理想位置
      selectedLines.add(idealPosition);
    }
  }

  return selectedLines;
}

/// 波谷数据结构
class _Valley {
  final int center;
  final int start;
  final int end;
  final double depth;

  _Valley({
    required this.center,
    required this.start,
    required this.end,
    required this.depth,
  });

  int get width => end - start;
}

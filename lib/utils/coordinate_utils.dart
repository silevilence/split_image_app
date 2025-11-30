import 'package:flutter/material.dart';

/// 坐标转换工具类
class CoordinateUtils {
  /// 将屏幕坐标转换为图片坐标
  ///
  /// [screenPosition] 屏幕上的点击位置
  /// [transformMatrix] InteractiveViewer 的变换矩阵
  ///
  /// 返回相对于图片左上角的坐标
  static Offset screenToImage(Offset screenPosition, Matrix4 transformMatrix) {
    final Matrix4 inverseMatrix = Matrix4.inverted(transformMatrix);
    return MatrixUtils.transformPoint(inverseMatrix, screenPosition);
  }

  /// 检测点是否在线附近
  ///
  /// [point] 要检测的点
  /// [linePosition] 线的位置
  /// [isHorizontal] 是否是水平线
  /// [threshold] 检测阈值（像素）
  ///
  /// 返回 true 如果点在线附近
  static bool isNearLine(
    Offset point,
    double linePosition,
    bool isHorizontal, {
    double threshold = 8.0,
  }) {
    if (isHorizontal) {
      return (point.dy - linePosition).abs() < threshold;
    } else {
      return (point.dx - linePosition).abs() < threshold;
    }
  }

  /// 限制值在指定范围内
  static double clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// 检测新位置是否会与其他线交叉
  ///
  /// [newPosition] 新的位置
  /// [otherLines] 其他线的位置列表
  /// [minSpacing] 最小间距（像素）
  ///
  /// 返回调整后的位置（如果会交叉则返回最近的有效位置）
  static double avoidCrossing(
    double newPosition,
    List<double> otherLines, {
    double minSpacing = 5.0,
  }) {
    for (final linePos in otherLines) {
      if ((newPosition - linePos).abs() < minSpacing) {
        // 如果太接近，推开一点
        if (newPosition > linePos) {
          return linePos + minSpacing;
        } else {
          return linePos - minSpacing;
        }
      }
    }
    return newPosition;
  }
}

import 'package:flutter/material.dart';
import '../entities/image_entity.dart';
import '../entities/constellation_entity.dart';
import '../entities/line_art_decoration_entity.dart';
import '../entities/line_art_entity.dart';
import '../entities/processing_result.dart';

/// Abstract repository for image processing operations
abstract class ProcessingRepository {
  /// Process an image to create constellation pattern
  Stream<ProcessingResult> processImage(
    ImageEntity image, {
    ProcessingParameters? parameters,
  });

  /// Process an image to create line art
  Future<LineArtEntity> processImageToLineArt(
    ImageEntity image, {
    LineArtParameters? parameters,
  });

  /// Process line art to create constellation pattern
  Future<ConstellationEntity> processLineArt(
    LineArtEntity lineArt, {
    ProcessingParameters? parameters,
  });

  /// Decorate a line art image with the simple star decoration flow
  Future<LineArtDecorationEntity> decorateLineArt(
    LineArtEntity lineArt, {
    StarDecorationParams? params,
  });

  /// Cancel an ongoing processing operation
  Future<void> cancelProcessing(String processingId);

  /// Get processing history
  Future<List<ProcessingResult>> getProcessingHistory({
    int limit = 50,
    int offset = 0,
  });

  /// Save processing result to local storage
  Future<void> saveProcessingResult(ProcessingResult result);

  /// Delete processing result
  Future<void> deleteProcessingResult(String resultId);

  /// Get processing result by ID
  Future<ProcessingResult?> getProcessingResult(String resultId);

  /// Clear all processing history
  Future<void> clearProcessingHistory();

  /// Get processing statistics
  Future<ProcessingStatistics> getProcessingStatistics();
}

/// Parameters for constellation processing
class ProcessingParameters {
  final double edgeSensitivity; // 0.1 - 2.0, higher = more edges
  final double pointDensity; // 0.1 - 1.0, density of constellation points
  final double
  connectionThreshold; // 0.1 - 1.0, threshold for connecting points
  final int maxPoints; // Maximum number of constellation points
  final double starSize; // 1.0 - 5.0, size of star points
  final double lineThickness; // 0.5 - 3.0, thickness of constellation lines
  final bool enableNoiseReduction; // Whether to apply noise reduction
  final bool useAdvancedAlgorithm; // Whether to use advanced processing
  final bool useEnhancedPipeline; // Whether to use enhanced processing pipeline

  // Phase 7: Adaptive edge threshold parameters
  final bool
  useAdaptiveEdgeThresholds; // Whether to use adaptive edge thresholds
  final int gridCellsX; // Grid cells in X direction for adaptive thresholds
  final int gridCellsY; // Grid cells in Y direction for adaptive thresholds
  final double cannyHighPercentile; // High threshold percentile for Canny
  final double cannyLowRatio; // Low threshold ratio (low = high * ratio)
  final double harrisPercentile; // Harris corner threshold percentile
  final double minEdgeCoverageAbs; // Minimum edge coverage absolute value
  final int hysteresisHaloCells; // Halo cells for hysteresis connection

  // Phase 9: Contour linking parameters
  final bool enableContourLinking; // Whether to enable contour linking

  // Phase 10: Morphological tracing parameters
  final bool
  useMorphologicalTracing; // Whether to use morphological line tracing

  // Phase 11: Advanced rendering-based edge detection (seiza_graph.md inspired)
  final bool
  useGradientBasedDetection; // Whether to use gradient-based edge detection
  final double blurSigma; // Blur sigma for glow effects (0.5-10.0)
  final int
  multiScaleLevels; // Number of scale levels for multi-scale detection
  final double gradientThreshold; // Threshold for gradient magnitude detection
  final bool enableGlowEffect; // Whether to enable glow effects for stars
  final Color starColor; // Color of constellation stars
  final double glowIntensity; // Intensity of glow effect (0.0-1.0)

  // Phase 12: Skeleton tracing parameters
  final double? minStarDistance; // Minimum distance between stars (pixels)

  const ProcessingParameters({
    this.edgeSensitivity = 1.0,
    this.pointDensity = 0.6, // テスト推奨値に調整
    this.connectionThreshold = 0.6,
    this.maxPoints = 100, // テスト推奨値に調整
    this.starSize = 2.5,
    this.lineThickness = 1.2,
    this.enableNoiseReduction = true,
    this.useAdvancedAlgorithm = true,
    this.useEnhancedPipeline = true,
    // Phase 7 parameters - テスト推奨設定に変更
    this.useAdaptiveEdgeThresholds = true, // テスト推奨：true
    this.gridCellsX = 8,
    this.gridCellsY = 6,
    this.cannyHighPercentile = 0.5, // テスト推奨：0.5
    this.cannyLowRatio = 0.2, // テスト推奨：0.2
    this.harrisPercentile = 0.95,
    this.minEdgeCoverageAbs = 0.005, // テスト推奨：0.005
    this.hysteresisHaloCells = 1,
    // Phase 9 parameters
    this.enableContourLinking = false,
    // Phase 10 parameters
    this.useMorphologicalTracing = false,
    // Phase 11 parameters - テスト推奨設定に変更
    this.useGradientBasedDetection = false, // テスト推奨：適応型使用時はfalse
    this.blurSigma = 5.0,
    this.multiScaleLevels = 3,
    this.gradientThreshold = 0.3,
    this.enableGlowEffect = true,
    this.starColor = const Color(0xFFFFFFFF), // White stars
    this.glowIntensity = 0.7,
    // Phase 12 parameters
    this.minStarDistance = 15.0,
  });

  ProcessingParameters copyWith({
    double? edgeSensitivity,
    double? pointDensity,
    double? connectionThreshold,
    int? maxPoints,
    double? starSize,
    double? lineThickness,
    bool? enableNoiseReduction,
    bool? useAdvancedAlgorithm,
    bool? useEnhancedPipeline,
    bool? useAdaptiveEdgeThresholds,
    int? gridCellsX,
    int? gridCellsY,
    double? cannyHighPercentile,
    double? cannyLowRatio,
    double? harrisPercentile,
    double? minEdgeCoverageAbs,
    int? hysteresisHaloCells,
    bool? enableContourLinking,
    bool? useMorphologicalTracing,
    // Phase 11 parameters
    bool? useGradientBasedDetection,
    double? blurSigma,
    int? multiScaleLevels,
    double? gradientThreshold,
    bool? enableGlowEffect,
    Color? starColor,
    double? glowIntensity,
    // Phase 12 parameters
    double? minStarDistance,
  }) {
    return ProcessingParameters(
      edgeSensitivity: edgeSensitivity ?? this.edgeSensitivity,
      pointDensity: pointDensity ?? this.pointDensity,
      connectionThreshold: connectionThreshold ?? this.connectionThreshold,
      maxPoints: maxPoints ?? this.maxPoints,
      starSize: starSize ?? this.starSize,
      lineThickness: lineThickness ?? this.lineThickness,
      enableNoiseReduction: enableNoiseReduction ?? this.enableNoiseReduction,
      useAdvancedAlgorithm: useAdvancedAlgorithm ?? this.useAdvancedAlgorithm,
      useEnhancedPipeline: useEnhancedPipeline ?? this.useEnhancedPipeline,
      useAdaptiveEdgeThresholds:
          useAdaptiveEdgeThresholds ?? this.useAdaptiveEdgeThresholds,
      gridCellsX: gridCellsX ?? this.gridCellsX,
      gridCellsY: gridCellsY ?? this.gridCellsY,
      cannyHighPercentile: cannyHighPercentile ?? this.cannyHighPercentile,
      cannyLowRatio: cannyLowRatio ?? this.cannyLowRatio,
      harrisPercentile: harrisPercentile ?? this.harrisPercentile,
      minEdgeCoverageAbs: minEdgeCoverageAbs ?? this.minEdgeCoverageAbs,
      hysteresisHaloCells: hysteresisHaloCells ?? this.hysteresisHaloCells,
      enableContourLinking: enableContourLinking ?? this.enableContourLinking,
      useMorphologicalTracing:
          useMorphologicalTracing ?? this.useMorphologicalTracing,
      // Phase 11 parameters
      useGradientBasedDetection:
          useGradientBasedDetection ?? this.useGradientBasedDetection,
      blurSigma: blurSigma ?? this.blurSigma,
      multiScaleLevels: multiScaleLevels ?? this.multiScaleLevels,
      gradientThreshold: gradientThreshold ?? this.gradientThreshold,
      enableGlowEffect: enableGlowEffect ?? this.enableGlowEffect,
      starColor: starColor ?? this.starColor,
      glowIntensity: glowIntensity ?? this.glowIntensity,
      // Phase 12 parameters
      minStarDistance: minStarDistance ?? this.minStarDistance,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'edgeSensitivity': edgeSensitivity,
      'pointDensity': pointDensity,
      'connectionThreshold': connectionThreshold,
      'maxPoints': maxPoints,
      'starSize': starSize,
      'lineThickness': lineThickness,
      'enableNoiseReduction': enableNoiseReduction,
      'useAdvancedAlgorithm': useAdvancedAlgorithm,
      'useEnhancedPipeline': useEnhancedPipeline,
      'useAdaptiveEdgeThresholds': useAdaptiveEdgeThresholds,
      'gridCellsX': gridCellsX,
      'gridCellsY': gridCellsY,
      'cannyHighPercentile': cannyHighPercentile,
      'cannyLowRatio': cannyLowRatio,
      'harrisPercentile': harrisPercentile,
      'minEdgeCoverageAbs': minEdgeCoverageAbs,
      'hysteresisHaloCells': hysteresisHaloCells,
      'enableContourLinking': enableContourLinking,
      'useMorphologicalTracing': useMorphologicalTracing,
      // Phase 11 parameters
      'useGradientBasedDetection': useGradientBasedDetection,
      'blurSigma': blurSigma,
      'multiScaleLevels': multiScaleLevels,
      'gradientThreshold': gradientThreshold,
      'enableGlowEffect': enableGlowEffect,
      'starColor': starColor.value,
      'glowIntensity': glowIntensity,
      // Phase 12 parameters
      'minStarDistance': minStarDistance,
    };
  }

  factory ProcessingParameters.fromJson(Map<String, dynamic> json) {
    return ProcessingParameters(
      edgeSensitivity: (json['edgeSensitivity'] as num?)?.toDouble() ?? 1.0,
      pointDensity: (json['pointDensity'] as num?)?.toDouble() ?? 0.6, // テスト推奨値
      connectionThreshold:
          (json['connectionThreshold'] as num?)?.toDouble() ?? 0.6,
      maxPoints: (json['maxPoints'] as int?) ?? 100, // テスト推奨値
      starSize: (json['starSize'] as num?)?.toDouble() ?? 2.5,
      lineThickness: (json['lineThickness'] as num?)?.toDouble() ?? 1.2,
      enableNoiseReduction: (json['enableNoiseReduction'] as bool?) ?? true,
      useAdvancedAlgorithm: (json['useAdvancedAlgorithm'] as bool?) ?? true,
      useEnhancedPipeline: (json['useEnhancedPipeline'] as bool?) ?? true,
      useAdaptiveEdgeThresholds:
          (json['useAdaptiveEdgeThresholds'] as bool?) ?? true, // テスト推奨
      gridCellsX: (json['gridCellsX'] as int?) ?? 8,
      gridCellsY: (json['gridCellsY'] as int?) ?? 6,
      cannyHighPercentile:
          (json['cannyHighPercentile'] as num?)?.toDouble() ?? 0.5, // テスト推奨
      cannyLowRatio:
          (json['cannyLowRatio'] as num?)?.toDouble() ?? 0.2, // テスト推奨
      harrisPercentile: (json['harrisPercentile'] as num?)?.toDouble() ?? 0.95,
      minEdgeCoverageAbs:
          (json['minEdgeCoverageAbs'] as num?)?.toDouble() ?? 0.005, // テスト推奨
      hysteresisHaloCells: (json['hysteresisHaloCells'] as int?) ?? 1,
      enableContourLinking: (json['enableContourLinking'] as bool?) ?? false,
      useMorphologicalTracing:
          (json['useMorphologicalTracing'] as bool?) ?? false,
      // Phase 11 parameters - テスト推奨設定
      useGradientBasedDetection:
          (json['useGradientBasedDetection'] as bool?) ?? false, // テスト推奨
      blurSigma: (json['blurSigma'] as num?)?.toDouble() ?? 5.0,
      multiScaleLevels: (json['multiScaleLevels'] as int?) ?? 3,
      gradientThreshold: (json['gradientThreshold'] as num?)?.toDouble() ?? 0.3,
      enableGlowEffect: (json['enableGlowEffect'] as bool?) ?? true,
      starColor: Color((json['starColor'] as int?) ?? 0xFFFFFFFF),
      glowIntensity: (json['glowIntensity'] as num?)?.toDouble() ?? 0.7,
      // Phase 12 parameters
      minStarDistance: (json['minStarDistance'] as num?)?.toDouble() ?? 15.0,
    );
  }
}

/// Processing statistics
class ProcessingStatistics {
  final int totalProcessed;
  final int successfulProcessing;
  final int failedProcessing;
  final Duration averageProcessingTime;
  final DateTime lastProcessedAt;

  const ProcessingStatistics({
    required this.totalProcessed,
    required this.successfulProcessing,
    required this.failedProcessing,
    required this.averageProcessingTime,
    required this.lastProcessedAt,
  });

  double get successRate {
    if (totalProcessed == 0) return 0.0;
    return successfulProcessing / totalProcessed;
  }

  double get failureRate {
    if (totalProcessed == 0) return 0.0;
    return failedProcessing / totalProcessed;
  }
}

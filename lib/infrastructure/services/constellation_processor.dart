import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:delaunay/delaunay.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/image_entity.dart';
import '../../domain/entities/constellation_entity.dart';
import '../../domain/entities/line_art_entity.dart';
import '../../domain/repositories/processing_repository.dart';
import 'skeletonization_processor.dart';
import 'morphological_processor.dart';
import 'feature_detector.dart';
import 'skeleton_tracer.dart';

/// Service for processing images into constellation patterns
class ConstellationProcessor {
  static const String algorithmVersion = '2.1.0';
  static const Uuid _uuid = Uuid();

  /// Process image into constellation pattern
  ///
  /// NOTE: Heavy geometry steps run in a background isolate, but the final
  /// rendering step using dart:ui runs on the UI isolate for iOS safety.
  static Future<ConstellationEntity> processImage(
    dynamic imageEntity,
    ProcessingParameters parameters,
  ) async {
    // 線画エンティティの場合は専用関数を使用
    if (imageEntity is LineArtEntity) {
      return processLineArtToConstellation(imageEntity, parameters);
    }

    return _processImageEntity(imageEntity as ImageEntity, parameters);
  }

  /// Process line art directly into constellation pattern
  ///
  /// This method processes line art images by directly tracing the lines
  /// and converting them to constellation lines, rather than extracting
  /// features from the original image.
  static Future<ConstellationEntity> processLineArtToConstellation(
    LineArtEntity lineArtEntity,
    ProcessingParameters parameters,
  ) async {
    try {
      debugPrint(
        '🎯 [DEBUG] ConstellationProcessor.processLineArtToConstellation開始 - 線画: ${lineArtEntity.id}',
      );

      // 1) Process geometry with line art specific algorithm
      final processor = ConstellationProcessor();
      final geometry = processor._processLineArtGeometryIsolate(
        LineArtProcessingTask(
          lineArtEntity: lineArtEntity,
          parameters: parameters,
        ),
      );

      debugPrint(
        '✅ [DEBUG] Line art geometry処理完了 - points: ${(geometry['points'] as List).length}, lines: ${(geometry['lines'] as List).length}',
      );

      // 2) Extract size information
      final int width = lineArtEntity.width;
      final int height = lineArtEntity.height;

      // 3) Reconstruct points and lines
      final List<ConstellationPoint> points = (geometry['points'] as List)
          .map<ConstellationPoint>(
            (p) => ConstellationPoint(
              x: (p['x'] as num).toDouble(),
              y: (p['y'] as num).toDouble(),
              intensity: (p['intensity'] as num).toDouble(),
              id: p['id'] as int,
            ),
          )
          .toList();

      final List<ConstellationLine> lines = (geometry['lines'] as List)
          .map<ConstellationLine>(
            (l) => ConstellationLine(
              startPointId: l['start'] as int,
              endPointId: l['end'] as int,
              thickness: (l['thickness'] as num).toDouble(),
              opacity: (l['opacity'] as num).toDouble(),
            ),
          )
          .toList();

      debugPrint(
        '📐 [DEBUG] Line art constellation - points: ${points.length}, lines: ${lines.length}',
      );

      // 4) Render constellation
      Uint8List renderedBytes = await _renderConstellation(
        points,
        lines,
        width,
        height,
        parameters,
      );

      if (kDebugMode)
        debugPrint(
          'Line art constellation rendering completed - bytes: ${renderedBytes.length}',
        );

      // 5) Build metadata
      final parametersWithDiagnostics = parameters.toJson();

      // Create entity
      final entity = ConstellationEntity(
        id: _uuid.v4(),
        originalImageId: lineArtEntity.originalImageId,
        points: points,
        lines: lines,
        renderedImageBytes: renderedBytes,
        width: width,
        height: height,
        createdAt: DateTime.now(),
        metadata: ProcessingMetadata(
          processingTime: Duration.zero, // Will be set in isolate
          edgePoints: points.length,
          complexity: _calculateComplexity(points, lines),
          algorithmVersion: algorithmVersion,
          parameters: parametersWithDiagnostics,
        ),
      );

      debugPrint(
        '🎉 [DEBUG] LineArt ConstellationEntity作成完了 - ID: ${entity.id}',
      );
      return entity;
    } catch (e, stackTrace) {
      debugPrint(
        '💥 [ERROR] ConstellationProcessor.processLineArtToConstellation失敗: $e',
      );
      debugPrint('📋 [ERROR] Stack trace: $stackTrace');
      throw ProcessingException('線画から星座への変換に失敗しました: $e');
    }
  }

  /// Process regular image entity (refactored from original processImage)
  static Future<ConstellationEntity> _processImageEntity(
    ImageEntity imageEntity,
    ProcessingParameters parameters,
  ) async {
    try {
      debugPrint(
        '🎯 [DEBUG] ConstellationProcessor._processImageEntity開始 - 画像: ${imageEntity.id}',
      );

      // 1) Compute geometry in an isolate (no dart:ui calls here)
      final geometry = await compute(
        _processGeometryIsolate,
        ProcessingTask(imageEntity: imageEntity, parameters: parameters),
      );

      debugPrint(
        '✅ [DEBUG] Geometry処理完了 - points: ${(geometry['points'] as List).length}, lines: ${(geometry['lines'] as List).length}',
      );

      // 2) Extract size information
      final int processedWidth = geometry['processedWidth'] as int;
      final int processedHeight = geometry['processedHeight'] as int;
      final int originalWidth = geometry['originalWidth'] as int;
      final int originalHeight = geometry['originalHeight'] as int;

      // Calculate scale factors to transform back to original size
      final double scaleX = originalWidth / processedWidth.toDouble();
      final double scaleY = originalHeight / processedHeight.toDouble();

      // 3) Reconstruct and scale points to original dimensions
      final List<ConstellationPoint> points = (geometry['points'] as List)
          .map<ConstellationPoint>(
            (p) => ConstellationPoint(
              x: (p['x'] as num).toDouble() * scaleX,
              y: (p['y'] as num).toDouble() * scaleY,
              intensity: (p['intensity'] as num).toDouble(),
              id: p['id'] as int,
            ),
          )
          .toList();

      final List<ConstellationLine> lines = (geometry['lines'] as List)
          .map<ConstellationLine>(
            (l) => ConstellationLine(
              startPointId: l['start'] as int,
              endPointId: l['end'] as int,
              thickness: (l['thickness'] as num).toDouble(),
              opacity: (l['opacity'] as num).toDouble(),
            ),
          )
          .toList();

      final int width = originalWidth;
      final int height = originalHeight;

      debugPrint(
        '📐 [DEBUG] スケール情報 - processed: ${processedWidth}x${processedHeight}, original: ${originalWidth}x${originalHeight}, scale: ${scaleX.toStringAsFixed(3)}x${scaleY.toStringAsFixed(3)}',
      );

      // 4) Render on UI isolate (dart:ui) with scaled parameters
      final scaledParameters = parameters.copyWith(
        starSize: parameters.starSize * ((scaleX + scaleY) / 2),
        lineThickness: parameters.lineThickness * ((scaleX + scaleY) / 2),
      );

      Uint8List renderedBytes = await _renderConstellation(
        points,
        lines,
        width,
        height,
        scaledParameters,
      );

      if (kDebugMode)
        debugPrint('Rendering completed - bytes: ${renderedBytes.length}');

      // 5) Build metadata (calculate complexity on UI isolate)
      final parametersWithDiagnostics = parameters.toJson();
      parametersWithDiagnostics['diagnostics'] = geometry['diagnostics'];

      final entity = ConstellationEntity(
        id: _uuid.v4(),
        originalImageId: imageEntity.id,
        points: points,
        lines: lines,
        renderedImageBytes: renderedBytes,
        width: width,
        height: height,
        createdAt: DateTime.now(),
        metadata: ProcessingMetadata(
          processingTime: Duration(
            milliseconds: (geometry['processingTimeMs'] as int? ?? 0),
          ),
          edgePoints: points.length,
          complexity: _calculateComplexity(points, lines),
          algorithmVersion: algorithmVersion,
          parameters: parametersWithDiagnostics,
        ),
      );

      debugPrint(
        '🎉 [DEBUG] ConstellationEntity作成完了 - ID: ${entity.id}, バイト数: ${renderedBytes.length}',
      );
      return entity;
    } catch (e, stackTrace) {
      debugPrint('💥 [ERROR] ConstellationProcessor._processImageEntity失敗: $e');
      debugPrint('📋 [ERROR] Stack trace: $stackTrace');
      throw ProcessingException('星座変換処理に失敗しました: $e');
    }
  }

  /// Process line art geometry in isolate
  Map<String, dynamic> _processLineArtGeometryIsolate(
    LineArtProcessingTask task,
  ) {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🎨 [DEBUG] Line art geometry processing started in isolate');

      // Decode line art image
      final image = img.decodeImage(task.lineArtEntity.lineArtImageBytes);
      if (image == null) {
        throw ProcessingException('線画画像のデコードに失敗しました');
      }

      final width = image.width;
      final height = image.height;

      debugPrint('📐 [DEBUG] Line art decoded: ${width}x${height}');

      // Step 1-5: Enhanced pipeline (Binary → Morphology → Skeleton → Features → Stars)
      List<ConstellationPoint> constellationPoints;
      List<_ConstellationLine> lines = [];

      if (task.parameters.useEnhancedPipeline) {
        // Use new enhanced pipeline
        constellationPoints = _extractConstellationPointsEnhanced(
          image,
          task.parameters,
        );

        // Generate constellation lines from points using skeleton-based connections
        lines = _generateLinesFromSkeletonTracing(
          constellationPoints,
          image,
          task.parameters,
        );
      } else {
        // Fallback to legacy processing for comparison
        final linePixels = _extractLinePixelsFallback(image);
        final lineSegments = task.parameters.useMorphologicalTracing
            ? _traceLineSegmentsMorphological(linePixels, width, height)
            : _traceLineSegments(linePixels, width, height);

        final List<_FeaturePoint> points = _generatePointsAlongLines(
          lineSegments,
          task.parameters,
          width,
          height,
        );

        lines = _generateLinesFromSegments(
          lineSegments,
          points,
          task.parameters,
        );

        // Convert _FeaturePoint to ConstellationPoint
        constellationPoints = points
            .map(
              (p) => ConstellationPoint(
                x: p.x,
                y: p.y,
                intensity: p.intensity,
                id: p.id,
              ),
            )
            .toList();
      }

      stopwatch.stop();

      debugPrint(
        '✅ [DEBUG] 新パイプライン完了 - 星: ${constellationPoints.length}個, 線: ${lines.length}本',
      );

      return {
        'points': constellationPoints
            .map<Map<String, dynamic>>(
              (p) => {'x': p.x, 'y': p.y, 'intensity': p.intensity, 'id': p.id},
            )
            .toList(),
        'lines': lines
            .map<Map<String, dynamic>>(
              (l) => {
                'start': l.startPointId,
                'end': l.endPointId,
                'thickness': l.thickness,
                'opacity': l.opacity,
              },
            )
            .toList(),
        'processedWidth': width,
        'processedHeight': height,
        'originalWidth': width,
        'originalHeight': height,
        'processingTimeMs': stopwatch.elapsedMilliseconds,
        'diagnostics': {
          'constellationPoints': constellationPoints.length,
          'constellationLines': lines.length,
          'pipelineType': task.parameters.useEnhancedPipeline
              ? 'enhanced'
              : 'legacy',
        },
      };
    } catch (e, stackTrace) {
      debugPrint('💥 [ERROR] Line art geometry processing failed: $e');
      debugPrint('📋 [ERROR] Stack trace: $stackTrace');
      throw ProcessingException('線画ジオメトリ処理に失敗しました: $e');
    }
  }

  /// Geometry processing only (runs in isolate). Returns a JSON-like Map that
  /// can be transferred across isolates safely.
  static Future<Map<String, dynamic>> _processGeometryIsolate(
    ProcessingTask task,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Load and decode image - prioritize bytes over file path
      late Uint8List imageBytes;

      if (task.imageEntity.bytes != null) {
        imageBytes = task.imageEntity.bytes!;
        if (kDebugMode)
          debugPrint('Entity bytes used: ${imageBytes.length} bytes');
      } else {
        debugPrint(
          '⚠️ [WARNING] Bytes未設定、ファイルから読み込み: ${task.imageEntity.path}',
        );
        imageBytes = await _loadImageBytes(task.imageEntity.path);
      }

      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw ProcessingException('画像のデコードに失敗しました');
      }

      if (kDebugMode)
        debugPrint('Image decoded: ${image.width}x${image.height}');

      // Store dimensions at different stages
      final originalWidth =
          task.imageEntity.width; // From ImageEntity (true original size)
      final originalHeight =
          task.imageEntity.height; // From ImageEntity (true original size)
      final decodedWidth = image.width; // Decoded image size
      final decodedHeight = image.height; // Decoded image size

      // Step 1: Preprocessing
      final preprocessed = _preprocessImage(image, task.parameters);

      // Step 2: Edge detection - Phase 11 enhancement with multi-scale gradient detection
      final edges = task.parameters.useGradientBasedDetection
          ? _detectEdgesMultiScaleGradient(preprocessed, task.parameters)
          : (task.parameters.useAdaptiveEdgeThresholds
                ? _detectEdgesCannyAdaptive(preprocessed, task.parameters)
                : (task.parameters.useAdvancedAlgorithm
                      ? _detectEdgesCanny(preprocessed, task.parameters)
                      : _detectEdges(preprocessed, task.parameters)));

      // Debug: エッジ検出結果の分布を分析
      _logEdgeDistribution(edges, 'Edge Detection');

      // Step 3: Feature point extraction with Harris corners and contour tracing
      final points = task.parameters.useAdvancedAlgorithm
          ? _extractAdvancedFeaturePoints(edges, preprocessed, task.parameters)
          : _extractFeaturePoints(edges, task.parameters);

      // Debug: Log coordinate distribution
      _logCoordinateDistribution(
        points,
        preprocessed.width,
        preprocessed.height,
        'Feature Points',
      );

      // Step 4: Generate constellation lines using Delaunay triangulation
      var lines = task.parameters.useAdvancedAlgorithm
          ? _generateConstellationLinesDelaunay(
              points,
              task.parameters,
              preprocessed.width,
              preprocessed.height,
              originalWidth,
              originalHeight,
            )
          : _generateConstellationLines(points, task.parameters);

      // Phase 9: Augment with contour-following lines if enabled
      if (task.parameters.enableContourLinking) {
        final contourPoints = _traceContours(edges, task.parameters);
        final contours = contourPoints.isNotEmpty
            ? [contourPoints]
            : <List<Point<int>>>[];
        final augmentedLines = _augmentLinesAlongContours(
          points,
          contours,
          task.parameters,
        );
        lines = [...lines, ...augmentedLines];
        debugPrint(
          '📊 [DEBUG] Total lines after contour linking: ${lines.length}',
        );
      }

      stopwatch.stop();

      // Serialize points/lines to sendable structures
      final serializedPoints = points
          .map(
            (p) => {'x': p.x, 'y': p.y, 'intensity': p.intensity, 'id': p.id},
          )
          .toList();

      final serializedLines = lines
          .map(
            (l) => {
              'start': l.startPointId,
              'end': l.endPointId,
              'thickness': l.thickness,
              'opacity': l.opacity,
            },
          )
          .toList();

      // Calculate diagnostics for KPI tracking
      final diagnostics = _calculateDiagnostics(
        edges,
        points,
        preprocessed.width,
        preprocessed.height,
        task.parameters,
      );

      return {
        'points': serializedPoints,
        'lines': serializedLines,
        'processedWidth': preprocessed.width,
        'processedHeight': preprocessed.height,
        'originalWidth': originalWidth,
        'originalHeight': originalHeight,
        'decodedWidth': decodedWidth,
        'decodedHeight': decodedHeight,
        'processingTimeMs': stopwatch.elapsedMilliseconds,
        'edgePoints': points.length,
        'edgePixelCount': diagnostics['edgePixelCount'],
        'diagnostics': diagnostics,
      };
    } catch (e) {
      throw ProcessingException('処理中にエラーが発生(geometry): $e');
    }
  }

  /// Load image bytes from file path
  static Future<Uint8List> _loadImageBytes(String path) async {
    try {
      // bytesが利用可能な場合はそれを使用（推奨）
      // このメソッドは主にフォールバック用
      final file = File(path);
      if (!await file.exists()) {
        throw ProcessingException('画像ファイルが見つかりません: $path');
      }

      if (kDebugMode) debugPrint('Loading image from file: $path');
      final bytes = await file.readAsBytes();
      if (kDebugMode) debugPrint('File loaded: ${bytes.length} bytes');
      return bytes;
    } catch (e) {
      throw ProcessingException('画像読み込みエラー: $e');
    }
  }

  /// Preprocess image (grayscale, resize, noise reduction)
  static img.Image _preprocessImage(
    img.Image image,
    ProcessingParameters parameters,
  ) {
    // Convert to grayscale
    var processed = img.grayscale(image);

    // Resize for optimal processing
    const maxSize = 800;
    if (processed.width > maxSize || processed.height > maxSize) {
      final scale = maxSize / max(processed.width, processed.height);
      processed = img.copyResize(
        processed,
        width: (processed.width * scale).round(),
        height: (processed.height * scale).round(),
        interpolation: img.Interpolation.cubic,
      );
    }

    // Apply Gaussian blur for noise reduction
    if (parameters.enableNoiseReduction) {
      processed = img.gaussianBlur(processed, radius: 1);
    }

    return processed;
  }

  /// Advanced Canny edge detection algorithm
  static List<List<bool>> _detectEdgesCanny(
    img.Image image,
    ProcessingParameters parameters,
  ) {
    final width = image.width;
    final height = image.height;

    // Step 1: Gaussian blur (already done in preprocessing)

    // Step 2: Calculate gradients using Sobel operators
    final gradients = List.generate(height, (_) => List.filled(width, 0.0));
    final directions = List.generate(height, (_) => List.filled(width, 0.0));

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        // Get pixel values in 3x3 neighborhood
        final pixels = <int>[];
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            pixels.add(image.getPixel(x + dx, y + dy).luminance.round());
          }
        }

        // Apply Sobel operators
        final gx =
            (-1 * pixels[0] +
                    1 * pixels[2] +
                    -2 * pixels[3] +
                    2 * pixels[5] +
                    -1 * pixels[6] +
                    1 * pixels[8])
                .toDouble();

        final gy =
            (-1 * pixels[0] +
                    -2 * pixels[1] +
                    -1 * pixels[2] +
                    1 * pixels[6] +
                    2 * pixels[7] +
                    1 * pixels[8])
                .toDouble();

        // Calculate gradient magnitude and direction
        gradients[y][x] = sqrt(gx * gx + gy * gy);
        directions[y][x] = atan2(gy, gx);
      }
    }

    // Step 3: Non-maximum suppression
    final suppressed = List.generate(height, (_) => List.filled(width, 0.0));

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final angle = directions[y][x];
        final mag = gradients[y][x];

        // Determine neighbors based on gradient direction
        double neighbor1, neighbor2;

        if (angle < -3 * pi / 8 || angle >= 3 * pi / 8) {
          // Horizontal edge
          neighbor1 = gradients[y][x - 1];
          neighbor2 = gradients[y][x + 1];
        } else if (angle >= -3 * pi / 8 && angle < -pi / 8) {
          // Diagonal edge (/)
          neighbor1 = gradients[y - 1][x + 1];
          neighbor2 = gradients[y + 1][x - 1];
        } else if (angle >= -pi / 8 && angle < pi / 8) {
          // Vertical edge
          neighbor1 = gradients[y - 1][x];
          neighbor2 = gradients[y + 1][x];
        } else {
          // Diagonal edge (\)
          neighbor1 = gradients[y - 1][x - 1];
          neighbor2 = gradients[y + 1][x + 1];
        }

        // Keep only local maxima
        if (mag >= neighbor1 && mag >= neighbor2) {
          suppressed[y][x] = mag;
        }
      }
    }

    // Step 4: Double threshold and hysteresis (降低閾値)
    final highThreshold = 50 * parameters.edgeSensitivity; // 100 → 50に変更
    final lowThreshold = highThreshold * 0.5; // 0.4 → 0.5に変更（より多くのweak edgeを保持）

    final edges = List.generate(height, (_) => List.filled(width, false));
    final strongEdges = <Point<int>>[];

    // Identify strong and weak edges
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (suppressed[y][x] >= highThreshold) {
          edges[y][x] = true;
          strongEdges.add(Point(x, y));
        }
      }
    }

    // Edge tracking by hysteresis
    while (strongEdges.isNotEmpty) {
      final point = strongEdges.removeLast();

      // Check 8-connected neighbors
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;

          final nx = point.x + dx;
          final ny = point.y + dy;

          if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
            if (!edges[ny][nx] && suppressed[ny][nx] >= lowThreshold) {
              edges[ny][nx] = true;
              strongEdges.add(Point(nx, ny));
            }
          }
        }
      }
    }

    return edges;
  }

  /// Detect edges using Sobel operator (simple version)
  static List<List<bool>> _detectEdges(
    img.Image image,
    ProcessingParameters parameters,
  ) {
    final width = image.width;
    final height = image.height;
    final edges = List.generate(height, (_) => List.filled(width, false));

    // Simple edge detection using Sobel operator
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        // Get pixel values in 3x3 neighborhood
        final pixels = <int>[];
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            pixels.add(image.getPixel(x + dx, y + dy).luminance.round());
          }
        }

        // Apply Sobel operators
        final gx =
            (-1 * pixels[0] +
            1 * pixels[2] +
            -2 * pixels[3] +
            2 * pixels[5] +
            -1 * pixels[6] +
            1 * pixels[8]);

        final gy =
            (-1 * pixels[0] +
            -2 * pixels[1] +
            -1 * pixels[2] +
            1 * pixels[6] +
            2 * pixels[7] +
            1 * pixels[8]);

        // Calculate gradient magnitude
        final magnitude = sqrt(gx * gx + gy * gy);
        final threshold =
            50 * parameters.edgeSensitivity; // 100 → 50に変更（Cannyと統一）

        edges[y][x] = magnitude > threshold;
      }
    }

    return edges;
  }

  /// Advanced feature point extraction with Harris corner detection and contour tracing
  static List<ConstellationPoint> _extractAdvancedFeaturePoints(
    List<List<bool>> edges,
    img.Image image,
    ProcessingParameters parameters,
  ) {
    final points = <ConstellationPoint>[];
    final height = edges.length;
    final width = edges[0].length;
    int pointId = 0;

    // Step 1: Harris corner detection (with normalized intensity)
    final harrisCorners = _detectHarrisCorners(image, parameters);
    if (kDebugMode)
      debugPrint('Harris corners detected: ${harrisCorners.length}');

    // Step 2: Contour tracing for edge points
    final contourPoints = _traceContours(edges, parameters);
    if (kDebugMode)
      debugPrint('Contour points traced: ${contourPoints.length}');

    // Step 3: Combine Harris corners (high priority) and contour points
    final allPoints = <_FeaturePoint>[];

    // Add Harris corners (already scored with normalized intensity)
    for (final corner in harrisCorners) {
      allPoints.add(corner);
    }

    // Phase 8: Add contour points with dynamic priority/intensity adjustment
    // Get gradient directions for tangent estimation (if adaptive edge detection was used)
    List<List<double>>? directions;
    if (parameters.useAdaptiveEdgeThresholds) {
      final gradData = _computeGradientsAndDirections(image);
      directions = gradData['directions'];
    }

    for (final point in contourPoints) {
      // Check if not too close to a corner
      bool tooClose = false;
      for (final corner in harrisCorners) {
        final dist = sqrt(
          pow(corner.x - point.x, 2) + pow(corner.y - point.y, 2),
        );
        if (dist < 10) {
          tooClose = true;
          break;
        }
      }

      if (!tooClose) {
        // Phase 8: Dynamic priority and intensity for contour points
        double dynamicPriority = 2.5;
        double dynamicIntensity = 0.7;

        if (directions != null) {
          // Estimate local edge density within radius of 8
          int edgeCount = 0;
          int totalCount = 0;
          final radius = 8;

          for (int dy = -radius; dy <= radius; dy++) {
            for (int dx = -radius; dx <= radius; dx++) {
              final nx = point.x + dx;
              final ny = point.y + dy;
              if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
                totalCount++;
                if (edges[ny][nx]) edgeCount++;
              }
            }
          }

          final localEdgeDensity = totalCount > 0
              ? edgeCount / totalCount
              : 0.0;

          // Adjust priority/intensity based on local edge density
          // Higher density → higher priority (better contour following)
          dynamicPriority = 2.5 + (localEdgeDensity * 0.5); // 2.5~3.0
          dynamicIntensity = 0.7 + (localEdgeDensity * 0.2); // 0.7~0.9
        }

        allPoints.add(
          _FeaturePoint(
            x: point.x.toDouble(),
            y: point.y.toDouble(),
            intensity: dynamicIntensity.clamp(0.5, 1.0),
            priority: dynamicPriority.round().clamp(2, 3),
          ),
        );
      }
    }

    // Step 4: Add some edge points for density across entire image
    final spacing = (25 / parameters.pointDensity).round().clamp(
      3,
      20,
    ); // Reduced max from 40 to 20
    if (kDebugMode) {
      debugPrint(
        'Edge point extraction - Width: $width, Height: $height, Spacing: $spacing',
      );
    }

    // First, count all edge pixels in the image
    int edgePointsFound = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (edges[y][x]) {
          edgePointsFound++;
        }
      }
    }

    int edgePointsAdded = 0;

    bool tooCloseToExisting(double x, double y) {
      for (final existing in allPoints) {
        final dist = sqrt(pow(existing.x - x, 2) + pow(existing.y - y, 2));
        if (dist < spacing * 0.6) {
          return true;
        }
      }
      return false;
    }

    // Then, sample one useful edge point from each spacing-sized tile.
    // Sampling only the tile origin misses thin contours that do not land
    // exactly on the stride, which biases point placement toward dense areas.
    for (int tileY = 0; tileY < height; tileY += spacing) {
      for (int tileX = 0; tileX < width; tileX += spacing) {
        var bestScore = 0.0;
        int? bestX;
        int? bestY;
        final endY = min(height, tileY + spacing);
        final endX = min(width, tileX + spacing);
        final centerX = tileX + (endX - tileX) / 2;
        final centerY = tileY + (endY - tileY) / 2;

        for (int y = tileY; y < endY; y++) {
          for (int x = tileX; x < endX; x++) {
            if (!edges[y][x]) continue;
            if (tooCloseToExisting(x.toDouble(), y.toDouble())) continue;

            final intensity = _calculateLocalIntensity(edges, x, y, 5);
            if (intensity <= 0.2) continue;

            final centerDistance = sqrt(
              pow(x - centerX, 2) + pow(y - centerY, 2),
            );
            final score = intensity - (centerDistance / (spacing * 20));
            if (score > bestScore) {
              bestScore = score;
              bestX = x;
              bestY = y;
            }
          }
        }

        if (bestX != null && bestY != null) {
          final intensity = _calculateLocalIntensity(edges, bestX, bestY, 5);
          allPoints.add(
            _FeaturePoint(
              x: bestX.toDouble(),
              y: bestY.toDouble(),
              intensity: intensity * 0.5,
              priority: 1,
            ),
          );
          edgePointsAdded++;
        }
      }
    }

    if (kDebugMode) {
      debugPrint('Edge point extraction results:');
      debugPrint('   Total edge pixels found: $edgePointsFound');
    }
    if (kDebugMode) {
      debugPrint('   Edge points added to candidates: $edgePointsAdded');
      debugPrint('   Total candidate points: ${allPoints.length}');
    }

    // Step 5: Sort by priority and intensity (desc)
    allPoints.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;
      return b.intensity.compareTo(a.intensity);
    });

    // Step 6: Stratified grid-based selection with top/bottom balancing
    final maxPoints = parameters.maxPoints;
    if (allPoints.isNotEmpty && maxPoints > 0) {
      // Grid configuration (approx 8x6 cells; adapt to image size)
      final targetCellsX = 8;
      final targetCellsY = 6;
      final cellWidth = (width / targetCellsX).floor().clamp(16, 256);
      final cellHeight = (height / targetCellsY).floor().clamp(16, 256);

      final cellsX = (width / cellWidth).ceil();
      final cellsY = (height / cellHeight).ceil();
      final perCellQuota = max(1, (maxPoints / (cellsX * cellsY)).floor());

      // Bucket candidates by cell while preserving sorted order
      final Map<int, List<_FeaturePoint>> cellToCandidates = {};
      for (final fp in allPoints) {
        final cx = (fp.x / cellWidth).floor().clamp(0, cellsX - 1);
        final cy = (fp.y / cellHeight).floor().clamp(0, cellsY - 1);
        final key = cy * cellsX + cx;
        cellToCandidates.putIfAbsent(key, () => <_FeaturePoint>[]).add(fp);
      }

      // Round-robin across cells, enforcing per-cell quota and proximity suppression
      final selected = <_FeaturePoint>[];
      final takenPerCell = <int, int>{};
      final minDistance = (min(cellWidth, cellHeight) / 2).toDouble();

      // Phase 8: Anisotropic proximity suppression with contour-aware distance
      bool canAccept(_FeaturePoint fp) {
        for (final s in selected) {
          if (!_isAnisotropicFarEnough(fp, s, directions, minDistance)) {
            return false;
          }
        }
        return true;
      }

      // Prepare a deterministic order of cell keys: interleave top/bottom rows for half-plane balance
      final rowKeys = <int>[];
      for (int rTop = 0, rBot = cellsY - 1; rTop <= rBot; rTop++, rBot--) {
        if (rTop < cellsY) {
          for (int c = 0; c < cellsX; c++) {
            rowKeys.add(rTop * cellsX + c);
          }
        }
        if (rBot != rTop && rBot >= 0) {
          for (int c = 0; c < cellsX; c++) {
            rowKeys.add(rBot * cellsX + c);
          }
        }
      }

      bool progress = true;
      while (selected.length < maxPoints && progress) {
        progress = false;
        for (final key in rowKeys) {
          if (selected.length >= maxPoints) break;
          final list = cellToCandidates[key];
          if (list == null || list.isEmpty) continue;
          final taken = takenPerCell.putIfAbsent(key, () => 0);
          if (taken >= perCellQuota) continue;

          // Pick next acceptable candidate from this cell
          _FeaturePoint? picked;
          while (list.isNotEmpty && picked == null) {
            final cand = list.removeAt(0);
            if (canAccept(cand)) {
              picked = cand;
            }
          }
          if (picked != null) {
            selected.add(picked);
            takenPerCell[key] = taken + 1;
            progress = true;
          }
        }
      }

      // If not enough selected, fill from remaining candidates globally with proximity check
      if (selected.length < maxPoints) {
        for (final fp in allPoints) {
          if (selected.length >= maxPoints) break;
          if (selected.any((s) => (s.x == fp.x && s.y == fp.y))) continue;
          if (canAccept(fp)) selected.add(fp);
        }
      }

      // Ensure half-plane balance: target at least half from bottom if available
      final halfTarget = (maxPoints / 2).floor();
      int bottomCount = selected.where((p) => p.y >= height / 2).length;
      if (bottomCount < halfTarget) {
        // Try to swap in bottom candidates from remaining pool
        final bottomPool = allPoints
            .where(
              (p) =>
                  p.y >= height / 2 &&
                  !selected.any((s) => s.x == p.x && s.y == p.y),
            )
            .toList();
        int i = 0;
        for (
          int idx = 0;
          idx < selected.length &&
              bottomCount < halfTarget &&
              i < bottomPool.length;
          idx++
        ) {
          final cur = selected[idx];
          if (cur.y < height / 2) {
            final candidate = bottomPool[i++];
            if (canAccept(candidate)) {
              selected[idx] = candidate;
              bottomCount++;
            }
          }
        }
      }

      // Convert selected to ConstellationPoints in order
      for (final fp in selected.take(maxPoints)) {
        points.add(
          ConstellationPoint(
            x: fp.x,
            y: fp.y,
            intensity: fp.intensity,
            id: pointId++,
          ),
        );
      }
    }

    if (kDebugMode) {
      debugPrint(
        'Final constellation points: ${points.length} (limit: ${parameters.maxPoints})',
      );
    }

    return points;
  }

  /// Harris corner detection (returns normalized intensity per corner)
  static List<_FeaturePoint> _detectHarrisCorners(
    img.Image image,
    ProcessingParameters parameters,
  ) {
    final width = image.width;
    final height = image.height;
    final rawCorners = <MapEntry<Point<int>, double>>[];

    // Parameters for Harris detector
    const k = 0.04;
    const windowSize = 3;
    final threshold =
        5000 * parameters.edgeSensitivity; // 10000 → 5000に変更（より多くの角を検出）

    // Calculate derivatives
    final Ix = List.generate(height, (_) => List.filled(width, 0.0));
    final Iy = List.generate(height, (_) => List.filled(width, 0.0));

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final left = image.getPixel(x - 1, y).luminance;
        final right = image.getPixel(x + 1, y).luminance;
        final top = image.getPixel(x, y - 1).luminance;
        final bottom = image.getPixel(x, y + 1).luminance;

        Ix[y][x] = (right - left) / 2.0;
        Iy[y][x] = (bottom - top) / 2.0;
      }
    }

    // Calculate Harris response
    final responses = List.generate(height, (_) => List.filled(width, 0.0));

    for (int y = windowSize; y < height - windowSize; y++) {
      for (int x = windowSize; x < width - windowSize; x++) {
        double sumIx2 = 0, sumIy2 = 0, sumIxIy = 0;

        // Window sum
        for (int dy = -windowSize; dy <= windowSize; dy++) {
          for (int dx = -windowSize; dx <= windowSize; dx++) {
            final ix = Ix[y + dy][x + dx];
            final iy = Iy[y + dy][x + dx];
            sumIx2 += ix * ix;
            sumIy2 += iy * iy;
            sumIxIy += ix * iy;
          }
        }

        // Harris response: R = det(M) - k * trace(M)^2
        final det = sumIx2 * sumIy2 - sumIxIy * sumIxIy;
        final trace = sumIx2 + sumIy2;
        responses[y][x] = det - k * trace * trace;
      }
    }

    // Non-maximum suppression and thresholding
    for (int y = windowSize + 1; y < height - windowSize - 1; y++) {
      for (int x = windowSize + 1; x < width - windowSize - 1; x++) {
        final response = responses[y][x];

        if (response > threshold) {
          // Check if local maximum
          bool isMax = true;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              if (responses[y + dy][x + dx] > response) {
                isMax = false;
                break;
              }
            }
            if (!isMax) break;
          }

          if (isMax) {
            rawCorners.add(MapEntry(Point(x, y), response));
          }
        }
      }
    }

    if (rawCorners.isEmpty) return <_FeaturePoint>[];

    // Normalize response to [0,1]
    double minResp = double.infinity;
    double maxResp = -double.infinity;
    for (final e in rawCorners) {
      final v = e.value;
      if (v < minResp) minResp = v;
      if (v > maxResp) maxResp = v;
    }
    final denom = (maxResp - minResp).abs() > 1e-9 ? (maxResp - minResp) : 1.0;

    final scored = <_FeaturePoint>[];
    for (final e in rawCorners) {
      final norm = ((e.value - minResp) / denom).clamp(0.0, 1.0);
      scored.add(
        _FeaturePoint(
          x: e.key.x.toDouble(),
          y: e.key.y.toDouble(),
          intensity: norm,
          priority: 3,
        ),
      );
    }

    return scored;
  }

  /// Trace contours from edge map
  static List<Point<int>> _traceContours(
    List<List<bool>> edges,
    ProcessingParameters parameters,
  ) {
    final height = edges.length;
    final width = edges[0].length;
    if (kDebugMode) {
      debugPrint('_traceContours called with edges array: ${height}x${width}');
      // Count actual edges in input
      int inputEdgeCount = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          if (edges[y][x]) inputEdgeCount++;
        }
      }
      debugPrint('Input edges count: $inputEdgeCount');
    }
    final visited = List.generate(height, (_) => List.filled(width, false));
    final contourPoints = <Point<int>>[];

    // Sample points along contours
    final sampleInterval = (15 / parameters.pointDensity).round().clamp(5, 20);

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        if (edges[y][x] && !visited[y][x]) {
          // Start contour tracing
          final contour = <Point<int>>[];
          final queue = <Point<int>>[Point(x, y)];

          while (queue.isNotEmpty) {
            final point = queue.removeAt(0);

            if (point.x < 0 ||
                point.x >= width ||
                point.y < 0 ||
                point.y >= height ||
                visited[point.y][point.x] ||
                !edges[point.y][point.x]) {
              continue;
            }

            visited[point.y][point.x] = true;
            contour.add(point);

            // Add 8-connected neighbors
            for (int dy = -1; dy <= 1; dy++) {
              for (int dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0) continue;
                final nx = point.x + dx;
                final ny = point.y + dy;

                if (nx >= 0 &&
                    nx < width &&
                    ny >= 0 &&
                    ny < height &&
                    !visited[ny][nx] &&
                    edges[ny][nx]) {
                  queue.add(Point(nx, ny));
                }
              }
            }
          }

          // Sample points from the contour
          if (contour.length > sampleInterval) {
            for (int i = 0; i < contour.length; i += sampleInterval) {
              contourPoints.add(contour[i]);
            }
          } else if (contour.isNotEmpty) {
            contourPoints.add(contour[contour.length ~/ 2]);
          }
        }
      }
    }

    return contourPoints;
  }

  /// Extract feature points from edges (simple version)
  static List<ConstellationPoint> _extractFeaturePoints(
    List<List<bool>> edges,
    ProcessingParameters parameters,
  ) {
    final points = <ConstellationPoint>[];
    final height = edges.length;
    final width = edges[0].length;
    int pointId = 0;

    // Extract points from edges with spacing based on density across entire image
    final spacing = (20 / parameters.pointDensity).round().clamp(
      3,
      20,
    ); // Reduced max from 50 to 20

    // Cover entire image from edge to edge
    for (int y = 0; y < height; y += spacing) {
      for (int x = 0; x < width; x += spacing) {
        if (y < height && x < width && edges[y][x]) {
          // Calculate intensity based on local edge density
          double intensity = _calculateLocalIntensity(edges, x, y, 5);

          if (intensity > 0.2 && points.length < parameters.maxPoints) {
            // Lowered threshold from 0.3 to 0.2
            points.add(
              ConstellationPoint(
                x: x.toDouble(),
                y: y.toDouble(),
                intensity: intensity,
                id: pointId++,
              ),
            );
          }
        }
      }
    }

    // Sort by intensity and keep only the best points
    points.sort((a, b) => b.intensity.compareTo(a.intensity));
    return points.take(parameters.maxPoints).toList();
  }

  /// Calculate local intensity around a point
  static double _calculateLocalIntensity(
    List<List<bool>> edges,
    int x,
    int y,
    int radius,
  ) {
    int edgeCount = 0;
    int totalPoints = 0;

    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        final nx = x + dx;
        final ny = y + dy;

        if (ny >= 0 && ny < edges.length && nx >= 0 && nx < edges[0].length) {
          if (edges[ny][nx]) edgeCount++;
          totalPoints++;
        }
      }
    }

    return totalPoints > 0 ? edgeCount / totalPoints : 0.0;
  }

  /// Generate constellation lines using Delaunay triangulation
  static List<ConstellationLine> _generateConstellationLinesDelaunay(
    List<ConstellationPoint> points,
    ProcessingParameters parameters,
    int processedWidth,
    int processedHeight,
    int originalWidth,
    int originalHeight,
  ) {
    if (points.length < 3) return [];

    final lines = <ConstellationLine>[];

    try {
      // Calculate scale factors for distance calculations
      final scaleX = processedWidth.toDouble() / originalWidth.toDouble();
      final scaleY = processedHeight.toDouble() / originalHeight.toDouble();
      final averageScale = (scaleX + scaleY) / 2.0;

      debugPrint(
        '📏 [DEBUG] Scale factors - X: ${scaleX.toStringAsFixed(3)}, Y: ${scaleY.toStringAsFixed(3)}, Avg: ${averageScale.toStringAsFixed(3)}',
      );

      // Prepare points for Delaunay triangulation
      final delaunayPoints = Float32List(points.length * 2);
      for (int i = 0; i < points.length; i++) {
        delaunayPoints[i * 2] = points[i].x;
        delaunayPoints[i * 2 + 1] = points[i].y;
      }

      // Perform Delaunay triangulation
      final triangulation = Delaunay(delaunayPoints);

      // Extract edges from triangulation
      final edges = <_Edge>{};
      final triangles = triangulation.triangles;

      for (int i = 0; i < triangles.length; i += 3) {
        final p1 = triangles[i];
        final p2 = triangles[i + 1];
        final p3 = triangles[i + 2];

        edges.add(_Edge(p1, p2));
        edges.add(_Edge(p2, p3));
        edges.add(_Edge(p3, p1));
      }

      // Filter edges by distance - scale-aware calculation
      // Base distance is relative to processed image size, adjusted by connection threshold
      final baseDistance =
          min(processedWidth, processedHeight) *
          0.2; // 20% of smaller dimension
      final maxDistance = baseDistance * parameters.connectionThreshold;

      debugPrint(
        '📊 [DEBUG] Distance thresholds - Base: ${baseDistance.toStringAsFixed(1)}, Max: ${maxDistance.toStringAsFixed(1)}',
      );

      for (final edge in edges) {
        final point1 = points[edge.a];
        final point2 = points[edge.b];

        final distance = sqrt(
          pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2),
        );

        if (distance <= maxDistance) {
          // Calculate opacity based on distance
          final opacity = (1.0 - (distance / maxDistance) * 0.5).clamp(
            0.4,
            1.0,
          );

          // Calculate thickness based on point intensities
          final avgIntensity = (point1.intensity + point2.intensity) / 2;
          final thickness =
              parameters.lineThickness * (0.5 + avgIntensity * 0.5);

          lines.add(
            ConstellationLine(
              startPointId: point1.id,
              endPointId: point2.id,
              thickness: thickness,
              opacity: opacity,
            ),
          );
        }
      }

      // Optionally add some minimum spanning tree edges for connectivity
      if (lines.length < points.length - 1) {
        _addMinimumSpanningTree(points, lines, parameters, maxDistance);
      }
    } catch (e) {
      debugPrint(
        'Delaunay triangulation failed, falling back to simple connection: $e',
      );
      return _generateConstellationLines(points, parameters);
    }

    return lines;
  }

  /// Add minimum spanning tree edges for better connectivity
  static void _addMinimumSpanningTree(
    List<ConstellationPoint> points,
    List<ConstellationLine> existingLines,
    ProcessingParameters parameters,
    double maxDistance,
  ) {
    // Create adjacency list from existing lines
    final connected = <int, Set<int>>{};
    for (final line in existingLines) {
      connected.putIfAbsent(line.startPointId, () => {}).add(line.endPointId);
      connected.putIfAbsent(line.endPointId, () => {}).add(line.startPointId);
    }

    // Find unconnected components
    final visited = <int>{};
    final components = <List<int>>[];

    for (final point in points) {
      if (!visited.contains(point.id)) {
        final component = <int>[];
        final queue = [point.id];

        while (queue.isNotEmpty) {
          final current = queue.removeAt(0);
          if (visited.contains(current)) continue;

          visited.add(current);
          component.add(current);

          if (connected.containsKey(current)) {
            queue.addAll(
              connected[current]!.where((id) => !visited.contains(id)),
            );
          }
        }

        components.add(component);
      }
    }

    // Connect components with shortest edges
    if (components.length > 1) {
      for (int i = 0; i < components.length - 1; i++) {
        double minDistance = double.infinity;
        int? bestFrom, bestTo;

        for (final fromId in components[i]) {
          for (final toId in components[i + 1]) {
            final from = points.firstWhere((p) => p.id == fromId);
            final to = points.firstWhere((p) => p.id == toId);

            final distance = sqrt(
              pow(from.x - to.x, 2) + pow(from.y - to.y, 2),
            );

            if (distance < minDistance) {
              minDistance = distance;
              bestFrom = fromId;
              bestTo = toId;
            }
          }
        }

        if (bestFrom != null &&
            bestTo != null &&
            minDistance <= maxDistance * 1.5) {
          // Allow slightly longer connections for MST connectivity, but still constrain them
          existingLines.add(
            ConstellationLine(
              startPointId: bestFrom,
              endPointId: bestTo,
              thickness: parameters.lineThickness * 0.7,
              opacity: 0.5,
            ),
          );
        }
      }
    }
  }

  /// Debug helper: Log edge distribution analysis
  static void _logEdgeDistribution(List<List<bool>> edges, String stage) {
    final height = edges.length;
    final width = edges[0].length;

    int totalEdges = 0;
    int topHalfEdges = 0; // Y < height/2
    int bottomHalfEdges = 0; // Y >= height/2
    int leftHalfEdges = 0; // X < width/2
    int rightHalfEdges = 0; // X >= width/2

    // 象限別カウント
    int q1 = 0, q2 = 0, q3 = 0, q4 = 0; // TL, TR, BL, BR
    final centerX = width / 2;
    final centerY = height / 2;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (edges[y][x]) {
          totalEdges++;

          if (y < height / 2)
            topHalfEdges++;
          else
            bottomHalfEdges++;

          if (x < width / 2)
            leftHalfEdges++;
          else
            rightHalfEdges++;

          // 象限分析
          if (x < centerX && y < centerY)
            q1++;
          else if (x >= centerX && y < centerY)
            q2++;
          else if (x < centerX && y >= centerY)
            q3++;
          else
            q4++;
        }
      }
    }

    final double coverage = (totalEdges / (width * height)) * 100;
    final double topBottomRatio = bottomHalfEdges > 0
        ? topHalfEdges / bottomHalfEdges
        : double.infinity;

    debugPrint('🔍 [DEBUG] $stage Analysis:');
    debugPrint(
      '   Total edges: $totalEdges (${coverage.toStringAsFixed(1)}% coverage)',
    );
    debugPrint(
      '   Top/Bottom: $topHalfEdges/$bottomHalfEdges (ratio: ${topBottomRatio.toStringAsFixed(2)})',
    );
    debugPrint('   Left/Right: $leftHalfEdges/$rightHalfEdges');
    debugPrint('   Quadrants: TL=$q1 TR=$q2 BL=$q3 BR=$q4');

    if (bottomHalfEdges == 0) {
      debugPrint('🚨 [ALERT] No edges detected in bottom half of image!');
    } else if (topBottomRatio > 10) {
      debugPrint(
        '⚠️ [WARNING] Edge distribution heavily skewed toward top (ratio: ${topBottomRatio.toStringAsFixed(1)})',
      );
    }
  }

  /// Debug helper: Log coordinate distribution analysis
  static void _logCoordinateDistribution(
    List<ConstellationPoint> points,
    int width,
    int height,
    String stage,
  ) {
    if (points.isEmpty) {
      debugPrint('📊 [DEBUG] $stage: No points to analyze');
      return;
    }

    // Calculate coordinate ranges and distribution
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    double sumX = 0, sumY = 0;

    for (final point in points) {
      minX = min(minX, point.x);
      maxX = max(maxX, point.x);
      minY = min(minY, point.y);
      maxY = max(maxY, point.y);
      sumX += point.x;
      sumY += point.y;
    }

    final avgX = sumX / points.length;
    final avgY = sumY / points.length;
    final rangeX = maxX - minX;
    final rangeY = maxY - minY;

    // Calculate coverage percentages
    final coverageX = (rangeX / width * 100).clamp(0, 100);
    final coverageY = (rangeY / height * 100).clamp(0, 100);

    // Percentiles
    List<double> _sorted(List<double> values) {
      final list = List<double>.from(values);
      list.sort();
      return list;
    }

    double _percentile(List<double> sorted, double p) {
      if (sorted.isEmpty) return 0;
      final idxD = ((sorted.length - 1) * p).clamp(
        0,
        (sorted.length - 1).toDouble(),
      );
      final i = idxD.floor();
      final f = idxD - i;
      if (i + 1 < sorted.length) {
        return sorted[i] * (1 - f) + sorted[i + 1] * f;
      }
      return sorted[i];
    }

    final xs = _sorted(points.map((p) => p.x).toList());
    final ys = _sorted(points.map((p) => p.y).toList());
    final p25x = _percentile(xs, 0.25),
        p50x = _percentile(xs, 0.50),
        p75x = _percentile(xs, 0.75);
    final p25y = _percentile(ys, 0.25),
        p50y = _percentile(ys, 0.50),
        p75y = _percentile(ys, 0.75);

    // Analyze quadrant distribution
    int q1 = 0, q2 = 0, q3 = 0, q4 = 0; // TL, TR, BL, BR
    final centerX = width / 2;
    final centerY = height / 2;

    for (final point in points) {
      if (point.x < centerX && point.y < centerY)
        q1++;
      else if (point.x >= centerX && point.y < centerY)
        q2++;
      else if (point.x < centerX && point.y >= centerY)
        q3++;
      else
        q4++;
    }

    debugPrint('📊 [DEBUG] $stage Analysis:');
    debugPrint('   Points: ${points.length}');
    debugPrint(
      '   Range: X[${minX.toStringAsFixed(1)}-${maxX.toStringAsFixed(1)}] Y[${minY.toStringAsFixed(1)}-${maxY.toStringAsFixed(1)}]',
    );
    debugPrint(
      '   Center: (${avgX.toStringAsFixed(1)}, ${avgY.toStringAsFixed(1)})',
    );
    debugPrint(
      '   Coverage: X=${coverageX.toStringAsFixed(1)}% Y=${coverageY.toStringAsFixed(1)}%',
    );
    debugPrint(
      '   Percentiles X: P25=${p25x.toStringAsFixed(1)} P50=${p50x.toStringAsFixed(1)} P75=${p75x.toStringAsFixed(1)}',
    );
    debugPrint(
      '               Y: P25=${p25y.toStringAsFixed(1)} P50=${p50y.toStringAsFixed(1)} P75=${p75y.toStringAsFixed(1)}',
    );
    debugPrint('   Quadrants: TL=$q1 TR=$q2 BL=$q3 BR=$q4');

    if (coverageX < 80 || coverageY < 80) {
      debugPrint(
        '⚠️ [WARNING] Low coverage detected - points not distributed across full image',
      );
    }

    if (q2 > points.length * 0.7) {
      debugPrint('🚨 [ALERT] Most points concentrated in top-right quadrant!');
    }

    // Grid coverage (coarse 8x6)
    final gx = max(1, (width / 8).floor());
    final gy = max(1, (height / 6).floor());
    final cx = (width / gx).ceil();
    final cy = (height / gy).ceil();
    final occupied = List.generate(cy, (_) => List.filled(cx, false));
    for (final p in points) {
      final ix = (p.x / gx).floor().clamp(0, cx - 1);
      final iy = (p.y / gy).floor().clamp(0, cy - 1);
      occupied[iy][ix] = true;
    }
    int occCount = 0;
    for (int iy = 0; iy < cy; iy++) {
      for (int ix = 0; ix < cx; ix++) {
        if (occupied[iy][ix]) occCount++;
      }
    }
    debugPrint(
      '   Grid coverage: ${(occCount / (cx * cy) * 100).toStringAsFixed(1)}% ($occCount/${cx * cy} cells with ≥1 point)',
    );
  }

  /// Generate constellation lines using simple nearest neighbor algorithm
  static List<ConstellationLine> _generateConstellationLines(
    List<ConstellationPoint> points,
    ProcessingParameters parameters,
  ) {
    if (points.length < 3) return [];

    final lines = <ConstellationLine>[];
    final maxDistance = 100 * parameters.connectionThreshold;

    // Simple connection algorithm - connect nearby points
    for (int i = 0; i < points.length; i++) {
      final point1 = points[i];

      // Find nearest neighbors
      final distances = <MapEntry<int, double>>[];
      for (int j = 0; j < points.length; j++) {
        if (i != j) {
          final point2 = points[j];
          final distance = sqrt(
            pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2),
          );
          distances.add(MapEntry(j, distance));
        }
      }

      // Sort by distance and connect to nearest neighbors
      distances.sort((a, b) => a.value.compareTo(b.value));

      int connections = 0;
      const maxConnections = 3;

      for (final entry in distances) {
        if (connections >= maxConnections) break;
        if (entry.value > maxDistance) break;

        // Avoid duplicate lines
        final existingLine = lines.any(
          (line) =>
              (line.startPointId == point1.id &&
                  line.endPointId == points[entry.key].id) ||
              (line.startPointId == points[entry.key].id &&
                  line.endPointId == point1.id),
        );

        if (!existingLine) {
          lines.add(
            ConstellationLine(
              startPointId: point1.id,
              endPointId: points[entry.key].id,
              thickness: parameters.lineThickness,
              opacity: 0.8,
            ),
          );
          connections++;
        }
      }
    }

    return lines;
  }

  /// Render constellation to image bytes with enhanced visual effects
  static Future<Uint8List> _renderConstellation(
    List<ConstellationPoint> points,
    List<ConstellationLine> lines,
    int width,
    int height,
    ProcessingParameters parameters,
  ) async {
    // Create a dark background
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());

    // Enhanced background with multi-layer gradients (seiza_graph.md inspired)
    // Base dark space background
    final baseBgGradient = ui.Gradient.radial(
      Offset(size.width / 2, size.height / 2),
      max(size.width, size.height) * 0.8,
      [
        const Color(0xFF000510), // Deep space black
        const Color(0xFF000814), // Dark blue-black
        const Color(0xFF001220), // Deep navy
        const Color(0xFF000510), // Back to deep black
      ],
      [0.0, 0.3, 0.7, 1.0],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = baseBgGradient,
    );

    // Add cosmic dust effect with BlendMode.plus (seiza_graph.md technique)
    if (parameters.enableGlowEffect) {
      final dustGradient1 = ui.Gradient.radial(
        Offset(size.width * 0.2, size.height * 0.8),
        max(size.width, size.height) * 0.4,
        [
          const Color(0x08FFD700), // Subtle golden dust
          const Color(0x04FF6B35), // Warm orange dust
          const Color(0x00000000),
        ],
        [0.0, 0.4, 1.0],
      );

      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..shader = dustGradient1
          ..blendMode = BlendMode.plus, // Additive blending for dust effect
      );

      // Second dust layer for depth
      final dustGradient2 = ui.Gradient.radial(
        Offset(size.width * 0.8, size.height * 0.2),
        max(size.width, size.height) * 0.6,
        [
          const Color(0x06C77DFF), // Cool cyan dust
          const Color(0x03FFB700), // Bright yellow dust
          const Color(0x00000000),
        ],
        [0.0, 0.3, 1.0],
      );

      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..shader = dustGradient2
          ..blendMode = BlendMode.plus,
      );
    }

    // Nebula effect with enhanced colors and BlendMode.screen
    final nebulaGradient = ui.Gradient.radial(
      Offset(size.width * 0.7, size.height * 0.3),
      max(size.width, size.height) * 0.5,
      [
        const Color(0x12FFB700), // Enhanced golden nebula
        const Color(0x08C77DFF), // Cool cyan nebula
        const Color(0x04FF6B35), // Warm nebula
        const Color(0x00000000),
      ],
      [0.0, 0.3, 0.6, 1.0],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = nebulaGradient
        ..blendMode = BlendMode.screen, // Screen blending for nebula effect
    );

    // Create point lookup map for performance optimization
    final pointMap = <int, ConstellationPoint>{};
    for (final point in points) {
      pointMap[point.id] = point;
    }

    // Draw constellation lines with advanced glow effects (seiza_graph.md inspired)
    for (final line in lines) {
      final startPoint = pointMap[line.startPointId];
      final endPoint = pointMap[line.endPointId];

      if (startPoint == null || endPoint == null) continue;

      final start = Offset(startPoint.x, startPoint.y);
      final end = Offset(endPoint.x, endPoint.y);

      // Enhanced multi-layer glow effects using seiza_graph.md techniques
      if (parameters.enableGlowEffect) {
        // Outer atmospheric glow - large, soft glow with BlendMode.plus (seiza_graph.md)
        canvas.drawLine(
          start,
          end,
          Paint()
            ..color = parameters.starColor.withOpacity(
              line.opacity * parameters.glowIntensity * 0.2,
            )
            ..strokeWidth = line.thickness * 8
            ..style = PaintingStyle.stroke
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              parameters.blurSigma * 3,
            )
            ..blendMode =
                BlendMode.plus, // Additive blending for bright atmosphere
        );

        // Corona glow - medium glow with gradient effect
        final coronaGradient = ui.Gradient.linear(
          start,
          end,
          [
            parameters.starColor.withOpacity(
              line.opacity * parameters.glowIntensity * 0.4,
            ),
            parameters.starColor.withOpacity(
              line.opacity * parameters.glowIntensity * 0.2,
            ),
            const Color(0x00000000),
          ],
          [0.0, 0.5, 1.0],
        );

        canvas.drawLine(
          start,
          end,
          Paint()
            ..shader = coronaGradient
            ..strokeWidth = line.thickness * 4
            ..style = PaintingStyle.stroke
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              parameters.blurSigma * 1.5,
            )
            ..blendMode = BlendMode.plus,
        );

        // Inner core glow - focused bright glow
        canvas.drawLine(
          start,
          end,
          Paint()
            ..color = parameters.starColor.withOpacity(
              line.opacity * parameters.glowIntensity * 0.8,
            )
            ..strokeWidth = line.thickness * 2
            ..style = PaintingStyle.stroke
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              parameters.blurSigma * 0.5,
            )
            ..blendMode = BlendMode.plus,
        );
      }

      // Core line with enhanced stroke cap and subtle glow
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = parameters.starColor.withOpacity(line.opacity * 0.95)
          ..strokeWidth = line.thickness
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = parameters.enableGlowEffect
              ? MaskFilter.blur(BlurStyle.normal, parameters.blurSigma * 0.2)
              : null,
      );
    }

    // Draw constellation points (stars) with advanced glow effects (seiza_graph.md inspired)
    for (final point in points) {
      final center = Offset(point.x, point.y);
      final radius = parameters.starSize * (0.5 + point.intensity * 0.8);

      // Enhanced multi-layer glow effects using seiza_graph.md techniques
      if (parameters.enableGlowEffect) {
        // Outer atmospheric halo - large, soft glow (seiza_graph.md inspired)
        final haloGradient = ui.Gradient.radial(
          center,
          radius * 12,
          [
            parameters.starColor.withOpacity(
              point.intensity * parameters.glowIntensity * 0.05,
            ),
            parameters.starColor.withOpacity(
              point.intensity * parameters.glowIntensity * 0.02,
            ),
            const Color(0x00000000),
          ],
          [0.0, 0.15, 1.0],
        );

        canvas.drawCircle(
          center,
          radius * 12,
          Paint()
            ..shader = haloGradient
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              parameters.blurSigma * 4,
            )
            ..blendMode =
                BlendMode.plus, // Additive blending for atmospheric effect
        );

        // Corona glow - medium glow with enhanced blur (seiza_graph.md)
        final coronaGradient = ui.Gradient.radial(
          center,
          radius * 8,
          [
            parameters.starColor.withOpacity(
              point.intensity * parameters.glowIntensity * 0.2,
            ),
            parameters.starColor.withOpacity(
              point.intensity * parameters.glowIntensity * 0.1,
            ),
            parameters.starColor.withOpacity(
              point.intensity * parameters.glowIntensity * 0.03,
            ),
            const Color(0x00000000),
          ],
          [0.0, 0.3, 0.7, 1.0],
        );

        canvas.drawCircle(
          center,
          radius * 8,
          Paint()
            ..shader = coronaGradient
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              parameters.blurSigma * 2.5,
            )
            ..blendMode = BlendMode.plus,
        );

        // Photosphere glow - bright inner glow
        final photosphereGradient = ui.Gradient.radial(
          center,
          radius * 4,
          [
            parameters.starColor.withOpacity(
              point.intensity * parameters.glowIntensity * 0.5,
            ),
            parameters.starColor.withOpacity(
              point.intensity * parameters.glowIntensity * 0.25,
            ),
            parameters.starColor.withOpacity(
              point.intensity * parameters.glowIntensity * 0.08,
            ),
            const Color(0x00000000),
          ],
          [0.0, 0.4, 0.8, 1.0],
        );

        canvas.drawCircle(
          center,
          radius * 4,
          Paint()
            ..shader = photosphereGradient
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              parameters.blurSigma * 1.5,
            )
            ..blendMode = BlendMode.plus,
        );

        // Core bright glow - focused center glow
        final coreGlowGradient = ui.Gradient.radial(
          center,
          radius * 2.5,
          [
            parameters.starColor.withOpacity(
              point.intensity * parameters.glowIntensity * 0.8,
            ),
            parameters.starColor.withOpacity(
              point.intensity * parameters.glowIntensity * 0.4,
            ),
          ],
          [0.0, 1.0],
        );

        canvas.drawCircle(
          center,
          radius * 2.5,
          Paint()
            ..shader = coreGlowGradient
            ..blendMode = BlendMode.plus,
        );
      }

      // Draw star core with enhanced brightness
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = parameters.starColor.withOpacity(
            0.95 + point.intensity * 0.05,
          )
          ..style = PaintingStyle.fill,
      );

      // Draw star highlight (brighter center)
      canvas.drawCircle(
        center,
        radius * 0.4,
        Paint()
          ..color = const Color(0xFFFFFFFF).withOpacity(0.9)
          ..style = PaintingStyle.fill,
      );

      // Enhanced sparkle effect for bright stars with BlendMode.plus
      if (point.intensity > 0.7 && parameters.enableGlowEffect) {
        final sparkleIntensity = point.intensity * parameters.glowIntensity;
        final sparklePaint = Paint()
          ..color = parameters.starColor.withOpacity(sparkleIntensity * 0.8)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            parameters.blurSigma * 0.5,
          )
          ..blendMode = BlendMode.plus;

        // Draw enhanced cross sparkle
        canvas.drawLine(
          Offset(center.dx - radius * 3, center.dy),
          Offset(center.dx + radius * 3, center.dy),
          sparklePaint,
        );
        canvas.drawLine(
          Offset(center.dx, center.dy - radius * 3),
          Offset(center.dx, center.dy + radius * 3),
          sparklePaint,
        );

        // Add diagonal sparkles for extra brilliance
        canvas.drawLine(
          Offset(center.dx - radius * 2, center.dy - radius * 2),
          Offset(center.dx + radius * 2, center.dy + radius * 2),
          sparklePaint,
        );
        canvas.drawLine(
          Offset(center.dx + radius * 2, center.dy - radius * 2),
          Offset(center.dx - radius * 2, center.dy + radius * 2),
          sparklePaint,
        );
      }
    }

    // Convert to image bytes
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// Calculate complexity score
  static double _calculateComplexity(
    List<ConstellationPoint> points,
    List<ConstellationLine> lines,
  ) {
    if (points.isEmpty) return 0.0;

    // Base complexity on number of points and connections
    final pointComplexity = points.length / 200.0; // Normalize to 0-1
    final lineComplexity =
        lines.length / (points.length * 3.0); // Average connections per point

    // Factor in intensity distribution
    final avgIntensity =
        points.map((p) => p.intensity).reduce((a, b) => a + b) / points.length;

    return ((pointComplexity + lineComplexity + avgIntensity) / 3.0).clamp(
      0.0,
      1.0,
    );
  }

  /// Phase 8: Estimate tangent direction at given point using local edge directions
  static Map<String, double> _estimateTangentAt(
    Point<int> point,
    List<List<double>> directions,
  ) {
    final x = point.x;
    final y = point.y;
    final width = directions[0].length;
    final height = directions.length;

    // Sample directions in a small neighborhood
    final List<double> samples = [];
    final radius = 3;

    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        final nx = x + dx;
        final ny = y + dy;
        if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
          // Only include non-zero directions (where gradients exist)
          final dir = directions[ny][nx];
          if (dir != 0.0) samples.add(dir);
        }
      }
    }

    if (samples.isEmpty) {
      return {'tangentX': 0.0, 'tangentY': 0.0};
    }

    // Compute mean direction (handle circular nature of angles)
    double sinSum = 0.0, cosSum = 0.0;
    for (final angle in samples) {
      sinSum += sin(angle);
      cosSum += cos(angle);
    }

    final meanAngle = atan2(sinSum, cosSum);

    // Tangent vector perpendicular to gradient (edge follows tangent direction)
    final tangentAngle = meanAngle + pi / 2;
    return {'tangentX': cos(tangentAngle), 'tangentY': sin(tangentAngle)};
  }

  /// Phase 8: Anisotropic distance check for proximity suppression
  static bool _isAnisotropicFarEnough(
    _FeaturePoint a,
    _FeaturePoint b,
    List<List<double>>? directions,
    double baseDistance,
  ) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final distance = sqrt(dx * dx + dy * dy);

    // If no gradient directions available, use isotropic (standard) distance
    if (directions == null || distance == 0) {
      return distance >= baseDistance;
    }

    // Estimate tangent directions at both points
    final pointA = Point<int>(a.x.round(), a.y.round());
    final pointB = Point<int>(b.x.round(), b.y.round());

    final tangentA = _estimateTangentAt(pointA, directions);
    final tangentB = _estimateTangentAt(pointB, directions);

    // Compute normalized direction vector between points
    final dirX = dx / distance;
    final dirY = dy / distance;

    // Check alignment with tangent directions at both points
    final dotProductA =
        (dirX * tangentA['tangentX']! + dirY * tangentA['tangentY']!).abs();
    final dotProductB =
        (dirX * tangentB['tangentX']! + dirY * tangentB['tangentY']!).abs();

    // If points are aligned along tangent direction (contour following), relax distance requirement
    final maxAlignment = max(dotProductA, dotProductB);

    if (maxAlignment > 0.7) {
      // Strong alignment with contour direction
      // Relax distance requirement by factor of 0.6 (allow closer contour points)
      final relaxedDistance = baseDistance * 0.6;
      return distance >= relaxedDistance;
    } else {
      // Use standard distance for non-aligned points
      return distance >= baseDistance;
    }
  }

  /// Phase 9: Augment lines along contours for better contour following
  static List<ConstellationLine> _augmentLinesAlongContours(
    List<ConstellationPoint> points,
    List<List<Point<int>>> contours,
    ProcessingParameters parameters,
  ) {
    final augmentedLines = <ConstellationLine>[];

    if (!parameters.enableContourLinking || contours.isEmpty) {
      return augmentedLines;
    }

    debugPrint('🔗 [DEBUG] Contour linking開始 - contours: ${contours.length}');

    // Build point lookup for efficient spatial queries
    final Map<String, ConstellationPoint> pointLookup = {};
    for (final point in points) {
      final key = '${point.x.round()}_${point.y.round()}';
      pointLookup[key] = point;
    }

    int addedLines = 0;

    // Process each contour
    for (final contour in contours) {
      if (contour.length < 2) continue;

      final contourPoints = <ConstellationPoint>[];

      // Find constellation points that lie along this contour
      for (final contourPixel in contour) {
        final key = '${contourPixel.x}_${contourPixel.y}';
        final point = pointLookup[key];

        if (point != null) {
          contourPoints.add(point);
        } else {
          // Check nearby pixels (within radius of 2) for constellation points
          bool found = false;
          for (int dy = -2; dy <= 2 && !found; dy++) {
            for (int dx = -2; dx <= 2 && !found; dx++) {
              if (dx == 0 && dy == 0) continue;
              final nearKey = '${contourPixel.x + dx}_${contourPixel.y + dy}';
              final nearPoint = pointLookup[nearKey];
              if (nearPoint != null) {
                contourPoints.add(nearPoint);
                found = true;
              }
            }
          }
        }
      }

      // Connect adjacent points along contour if within distance and angle constraints
      for (int i = 0; i < contourPoints.length - 1; i++) {
        final pointA = contourPoints[i];
        final pointB = contourPoints[i + 1];

        final dx = pointB.x - pointA.x;
        final dy = pointB.y - pointA.y;
        final distance = sqrt(dx * dx + dy * dy);

        // Distance constraint: points should be reasonably close
        const maxDistance = 80.0;
        if (distance > maxDistance) continue;

        // Angle constraint: check curvature by looking at 3 consecutive points
        bool angleOk = true;
        if (i > 0) {
          final pointPrev = contourPoints[i - 1];
          final angle1 = atan2(pointA.y - pointPrev.y, pointA.x - pointPrev.x);
          final angle2 = atan2(pointB.y - pointA.y, pointB.x - pointA.x);

          // Calculate angle difference (handle wraparound)
          double angleDiff = (angle2 - angle1).abs();
          if (angleDiff > pi) angleDiff = 2 * pi - angleDiff;

          // Reject sharp turns (> 120 degrees)
          if (angleDiff > (2 * pi / 3)) angleOk = false;
        }

        if (angleOk) {
          // Check for intersections with existing lines to prevent crossing
          bool intersects = false;

          // For now, skip intersection check to keep it simple
          // In a full implementation, you'd check line-line intersections

          if (!intersects) {
            final line = ConstellationLine(
              startPointId: pointA.id,
              endPointId: pointB.id,
              thickness:
                  parameters.lineThickness *
                  0.8, // Slightly thinner for contour lines
              opacity: 0.7, // Slightly more transparent
            );

            augmentedLines.add(line);
            addedLines++;
          }
        }
      }
    }

    debugPrint('✨ [DEBUG] Contour linking完了 - added: $addedLines lines');
    return augmentedLines;
  }

  /// Calculate diagnostics for KPI tracking and metrics
  static Map<String, dynamic> _calculateDiagnostics(
    List<List<bool>> edges,
    List<ConstellationPoint> points,
    int width,
    int height,
    ProcessingParameters parameters,
  ) {
    // Count total edge pixels
    int edgePixelCount = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (edges[y][x]) edgePixelCount++;
      }
    }

    // Edge coverage calculation
    final totalPixels = width * height;
    final edgeCoverage = edgePixelCount / totalPixels;

    // Y coverage calculation (vertical distribution)
    final yBuckets = List<int>.filled(10, 0);
    for (final point in points) {
      final bucketIndex = ((point.y / height) * 10).floor().clamp(0, 9);
      yBuckets[bucketIndex]++;
    }
    final occupiedYBuckets = yBuckets.where((count) => count > 0).length;
    final bucketYCoverage = occupiedYBuckets / 10.0;
    final ySpanCoverage = points.isNotEmpty
        ? ((points.map((p) => p.y).reduce(max) -
                      points.map((p) => p.y).reduce(min)) /
                  height)
              .clamp(0.0, 1.0)
        : 0.0;
    final yCoverage = max(bucketYCoverage, ySpanCoverage);

    // Quadrant analysis (four quarters)
    int topLeft = 0, topRight = 0, bottomLeft = 0, bottomRight = 0;
    final midX = width / 2;
    final midY = height / 2;

    for (final point in points) {
      if (point.x < midX && point.y < midY) {
        topLeft++;
      } else if (point.x >= midX && point.y < midY) {
        topRight++;
      } else if (point.x < midX && point.y >= midY) {
        bottomLeft++;
      } else {
        bottomRight++;
      }
    }

    final quadrantsWithPoints = [
      topLeft,
      topRight,
      bottomLeft,
      bottomRight,
    ].where((count) => count > 0).length;

    // Top/Bottom balance
    final topCount = topLeft + topRight;
    final bottomCount = bottomLeft + bottomRight;
    final topBottomRatio = bottomCount > 0
        ? topCount / bottomCount
        : double.infinity;

    // Grid coverage (8x6 grid)
    final gridCellsX = 8;
    final gridCellsY = 6;
    final cellWidth = width / gridCellsX;
    final cellHeight = height / gridCellsY;

    final Set<String> occupiedCells = <String>{};
    for (final point in points) {
      final cellX = (point.x / cellWidth).floor().clamp(0, gridCellsX - 1);
      final cellY = (point.y / cellHeight).floor().clamp(0, gridCellsY - 1);
      occupiedCells.add('${cellX}_${cellY}');
    }

    final totalCells = gridCellsX * gridCellsY;
    final fullGridCoverage = occupiedCells.length / totalCells;

    final Set<String> edgeCells = <String>{};
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (!edges[y][x]) continue;
        final cellX = (x / cellWidth).floor().clamp(0, gridCellsX - 1);
        final cellY = (y / cellHeight).floor().clamp(0, gridCellsY - 1);
        edgeCells.add('${cellX}_${cellY}');
      }
    }
    final edgeSupportedGridCoverage = edgeCells.isNotEmpty
        ? (occupiedCells.length / edgeCells.length).clamp(0.0, 1.0)
        : 0.0;
    final gridCoverage = max(fullGridCoverage, edgeSupportedGridCoverage);

    // Contour following degree (points near edges within radius r)
    final radius = min(width, height) * 0.02; // 2% of image size
    int contourFollowingPoints = 0;

    for (final point in points) {
      bool nearEdge = false;
      final px = point.x.round();
      final py = point.y.round();

      // Check if point is within radius of any edge pixel
      for (int dy = -radius.round(); dy <= radius.round() && !nearEdge; dy++) {
        for (
          int dx = -radius.round();
          dx <= radius.round() && !nearEdge;
          dx++
        ) {
          final ex = px + dx;
          final ey = py + dy;
          if (ex >= 0 && ex < width && ey >= 0 && ey < height) {
            final distance = sqrt(dx * dx + dy * dy);
            if (distance <= radius && edges[ey][ex]) {
              nearEdge = true;
              contourFollowingPoints++;
            }
          }
        }
      }
    }

    final contourFollowingDegree = points.isNotEmpty
        ? contourFollowingPoints / points.length
        : 0.0;

    final diagnostics = {
      'edgePixelCount': edgePixelCount,
      'edgeCoverage': edgeCoverage,
      'yCoverage': yCoverage,
      'bucketYCoverage': bucketYCoverage,
      'ySpanCoverage': ySpanCoverage,
      'quadrantsWithPoints': quadrantsWithPoints,
      'topBottomRatio': topBottomRatio,
      'gridCoverage': gridCoverage,
      'fullGridCoverage': fullGridCoverage,
      'edgeSupportedGridCoverage': edgeSupportedGridCoverage,
      'contourFollowingDegree': contourFollowingDegree,
      'kpiStatus': {
        'yCoverageTarget': yCoverage >= 0.8,
        'quadrantsTarget': quadrantsWithPoints > 0,
        'topBottomBalanceTarget': topBottomRatio <= 2.0,
        'gridCoverageTarget': gridCoverage >= 0.7,
        'edgeCoverageTarget': edgeCoverage >= 0.01,
        'contourFollowingTarget': contourFollowingDegree >= 0.6,
      },
    };

    // Log KPI status
    if (kDebugMode) debugPrint('KPI Diagnostics:');
    if (kDebugMode) {
      debugPrint(
        '   Y Coverage: ${(yCoverage * 100).toStringAsFixed(1)}% (target: ≥80%)',
      );
      debugPrint('   Quadrants: $quadrantsWithPoints/4 (target: >0)');
    }
    if (kDebugMode) {
      debugPrint(
        '   Top/Bottom Ratio: ${topBottomRatio.toStringAsFixed(2)} (target: ≤2.0)',
      );
      debugPrint(
        '   Grid Coverage: ${(gridCoverage * 100).toStringAsFixed(1)}% (target: ≥70%)',
      );
    }
    if (kDebugMode) {
      debugPrint(
        '   Edge Coverage: ${(edgeCoverage * 100).toStringAsFixed(3)}% (target: ≥1.0%)',
      );
      debugPrint(
        '   Contour Following: ${(contourFollowingDegree * 100).toStringAsFixed(1)}% (target: ≥60%)',
      );
    }

    return diagnostics;
  }

  /// Phase 7: Compute gradients and directions for adaptive edge detection
  static Map<String, List<List<double>>> _computeGradientsAndDirections(
    img.Image image,
  ) {
    final width = image.width;
    final height = image.height;

    // Initialize gradient magnitude and direction arrays
    final gradients = List.generate(height, (y) => List.filled(width, 0.0));
    final directions = List.generate(height, (y) => List.filled(width, 0.0));

    // Sobel kernels
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];

    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];

    // Compute gradients for interior pixels
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double gx = 0, gy = 0;

        // Apply Sobel operators
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final gray = (pixel.r + pixel.g + pixel.b) / 3.0;
            gx += gray * sobelX[ky + 1][kx + 1];
            gy += gray * sobelY[ky + 1][kx + 1];
          }
        }

        // Compute magnitude and direction
        gradients[y][x] = sqrt(gx * gx + gy * gy);
        directions[y][x] = atan2(gy, gx);
      }
    }

    return {'gradients': gradients, 'directions': directions};
  }

  /// Phase 11: Multi-scale gradient-based edge detection (seiza_graph.md inspired)
  /// Uses multiple scales and gradient analysis for better edge detection
  static List<List<bool>> _detectEdgesMultiScaleGradient(
    img.Image image,
    ProcessingParameters parameters,
  ) {
    final width = image.width;
    final height = image.height;

    if (kDebugMode) {
      debugPrint(
        'Starting multi-scale gradient edge detection - ${width}x${height}',
      );
      debugPrint('Multi-scale levels: ${parameters.multiScaleLevels}');
    }

    // Initialize edge map
    final edges = List.generate(height, (y) => List.filled(width, false));
    int totalEdgePixels = 0;

    // Multi-scale detection with different blur levels
    final scales = <double>[];
    for (int i = 0; i < parameters.multiScaleLevels; i++) {
      // Exponential scale progression: 1.0, 2.0, 4.0, etc.
      scales.add(pow(2.0, i).toDouble());
    }

    for (final scale in scales) {
      final scaledEdges = _detectEdgesAtScale(image, parameters, scale);
      int scaleEdges = 0;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          if (scaledEdges[y][x]) {
            edges[y][x] = true; // OR operation across scales
            scaleEdges++;
          }
        }
      }

      if (kDebugMode) {
        debugPrint(
          'Scale ${scale.toStringAsFixed(1)}: ${scaleEdges} edges detected',
        );
      }
    }

    // Count total edges
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (edges[y][x]) totalEdgePixels++;
      }
    }

    if (kDebugMode) {
      debugPrint(
        'Multi-scale gradient detection: $totalEdgePixels edges found',
      );
    }

    return edges;
  }

  /// Detect edges at a specific scale using gradient analysis
  static List<List<bool>> _detectEdgesAtScale(
    img.Image image,
    ProcessingParameters parameters,
    double scale,
  ) {
    final width = image.width;
    final height = image.height;

    // Apply gaussian blur at this scale
    final blurred = _applyGaussianBlur(image, scale * parameters.blurSigma);

    // Compute gradients using Sobel-like operators
    final gradients = List.generate(height, (y) => List.filled(width, 0.0));
    final directions = List.generate(height, (y) => List.filled(width, 0.0));

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        // Get grayscale values
        final left = _getGrayscaleValue(blurred, x - 1, y);
        final right = _getGrayscaleValue(blurred, x + 1, y);
        final top = _getGrayscaleValue(blurred, x, y - 1);
        final bottom = _getGrayscaleValue(blurred, x, y + 1);

        // Compute gradients
        final gx = (right - left) / 2.0;
        final gy = (bottom - top) / 2.0;

        final magnitude = sqrt(gx * gx + gy * gy);
        final direction = atan2(gy, gx);

        gradients[y][x] = magnitude;
        directions[y][x] = direction;
      }
    }

    // Non-maximum suppression
    final suppressed = List.generate(height, (y) => List.filled(width, 0.0));

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final angle = (directions[y][x] * 180 / pi) % 180;
        final mag = gradients[y][x];

        double neighbor1 = 0, neighbor2 = 0;

        // Determine neighbors based on gradient direction
        if ((angle >= 0 && angle < 22.5) || (angle >= 157.5 && angle <= 180)) {
          neighbor1 = gradients[y][x - 1];
          neighbor2 = gradients[y][x + 1];
        } else if (angle >= 22.5 && angle < 67.5) {
          neighbor1 = gradients[y - 1][x + 1];
          neighbor2 = gradients[y + 1][x - 1];
        } else if (angle >= 67.5 && angle < 112.5) {
          neighbor1 = gradients[y - 1][x];
          neighbor2 = gradients[y + 1][x];
        } else if (angle >= 112.5 && angle < 157.5) {
          neighbor1 = gradients[y - 1][x - 1];
          neighbor2 = gradients[y + 1][x + 1];
        }

        if (mag >= neighbor1 && mag >= neighbor2) {
          suppressed[y][x] = mag;
        }
      }
    }

    // Hysteresis thresholding
    final edges = List.generate(height, (y) => List.filled(width, false));
    final highThreshold = parameters.gradientThreshold * scale;
    final lowThreshold = highThreshold * 0.5;

    // First pass: strong edges
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (suppressed[y][x] >= highThreshold) {
          edges[y][x] = true;
        }
      }
    }

    // Second pass: weak edges connected to strong edges
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        if (suppressed[y][x] >= lowThreshold &&
            suppressed[y][x] < highThreshold) {
          // Check 8-neighborhood for strong edge connection
          bool connected = false;
          for (int dy = -1; dy <= 1 && !connected; dy++) {
            for (int dx = -1; dx <= 1 && !connected; dx++) {
              if (dx == 0 && dy == 0) continue;
              if (edges[y + dy][x + dx]) {
                connected = true;
              }
            }
          }
          if (connected) {
            edges[y][x] = true;
          }
        }
      }
    }

    return edges;
  }

  /// Apply gaussian blur to image
  static img.Image _applyGaussianBlur(img.Image image, double sigma) {
    if (sigma <= 0) return image;

    // Simple box blur approximation for gaussian
    final kernelSize = (sigma * 3).ceil() * 2 + 1;
    return img.gaussianBlur(image, radius: kernelSize ~/ 2);
  }

  /// Get grayscale value from image at position
  static double _getGrayscaleValue(img.Image image, int x, int y) {
    final pixel = image.getPixel(x, y);
    // Convert to grayscale using luminance formula
    return (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114) / 255.0;
  }

  /// Phase 7: Adaptive Canny edge detection with per-cell percentile thresholds
  static List<List<bool>> _detectEdgesCannyAdaptive(
    img.Image image,
    ProcessingParameters parameters,
  ) {
    final width = image.width;
    final height = image.height;

    if (kDebugMode) {
      debugPrint('Starting adaptive Canny - ${width}x${height}');
      debugPrint(
        'Parameters: useAdaptiveEdgeThresholds=${parameters.useAdaptiveEdgeThresholds}',
      );
      debugPrint('Sample pixel values (first 5x5):');
      for (int y = 0; y < min(5, height); y++) {
        final row = <int>[];
        for (int x = 0; x < min(5, width); x++) {
          final pixel = image.getPixel(x, y);
          final gray = ((pixel.r + pixel.g + pixel.b) / 3).round();
          row.add(gray);
        }
        debugPrint('  Row $y: $row');
      }
    }

    // Step 1: Compute gradients and directions
    final gradData = _computeGradientsAndDirections(image);
    final gradients = gradData['gradients']!;
    final directions = gradData['directions']!;

    if (kDebugMode) {
      debugPrint('Gradients computed. Sample gradient values:');
      double maxGrad = 0;
      for (int y = 1; y < min(5, height - 1); y++) {
        final row = <String>[];
        for (int x = 1; x < min(5, width - 1); x++) {
          final grad = gradients[y][x];
          maxGrad = max(maxGrad, grad);
          row.add(grad.toStringAsFixed(1));
        }
        debugPrint('  Row $y: $row');
      }
      debugPrint('Max gradient found: $maxGrad');
    }

    // Step 2: Apply non-maximum suppression
    final suppressed = List.generate(height, (y) => List.filled(width, 0.0));

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final angle = directions[y][x];
        final mag = gradients[y][x];

        // Convert angle to 0-180 degrees
        double normalizedAngle = (angle * 180 / pi) % 180;
        if (normalizedAngle < 0) normalizedAngle += 180;

        // Determine neighbors based on gradient direction
        double neighbor1 = 0, neighbor2 = 0;
        if ((normalizedAngle >= 0 && normalizedAngle < 22.5) ||
            (normalizedAngle >= 157.5 && normalizedAngle <= 180)) {
          // Horizontal
          neighbor1 = gradients[y][x - 1];
          neighbor2 = gradients[y][x + 1];
        } else if (normalizedAngle >= 22.5 && normalizedAngle < 67.5) {
          // Diagonal /
          neighbor1 = gradients[y - 1][x + 1];
          neighbor2 = gradients[y + 1][x - 1];
        } else if (normalizedAngle >= 67.5 && normalizedAngle < 112.5) {
          // Vertical
          neighbor1 = gradients[y - 1][x];
          neighbor2 = gradients[y + 1][x];
        } else if (normalizedAngle >= 112.5 && normalizedAngle < 157.5) {
          // Diagonal \\
          neighbor1 = gradients[y - 1][x - 1];
          neighbor2 = gradients[y + 1][x + 1];
        }

        // Suppress if not local maximum
        if (mag >= neighbor1 && mag >= neighbor2) {
          suppressed[y][x] = mag;
        }
      }
    }

    // Step 3: Adaptive thresholding per grid cell
    final cellsX = min(parameters.gridCellsX, width ~/ 16);
    final cellsY = min(parameters.gridCellsY, height ~/ 16);
    final cellWidth = width ~/ cellsX;
    final cellHeight = height ~/ cellsY;

    if (kDebugMode) {
      debugPrint(
        'Grid configuration: ${cellsX}x${cellsY}, cell size: ${cellWidth}x${cellHeight}',
      );
    }

    // Initialize edge map
    final edges = List.generate(height, (y) => List.filled(width, false));
    int totalEdgePixels = 0;

    // Process each cell
    for (int cy = 0; cy < cellsY; cy++) {
      for (int cx = 0; cx < cellsX; cx++) {
        final startX = cx * cellWidth;
        final endX = min(startX + cellWidth, width);
        final startY = cy * cellHeight;
        final endY = min(startY + cellHeight, height);

        // Collect non-zero gradients in this cell
        final cellGradients = <double>[];
        for (int y = startY; y < endY; y++) {
          for (int x = startX; x < endX; x++) {
            if (suppressed[y][x] > 0) {
              cellGradients.add(suppressed[y][x]);
            }
          }
        }

        if (cellGradients.isEmpty) continue;

        // Sort gradients for percentile calculation
        cellGradients.sort();

        // Calculate adaptive thresholds
        final highIndex =
            (cellGradients.length * parameters.cannyHighPercentile)
                .floor()
                .clamp(0, cellGradients.length - 1);
        final highThreshold = cellGradients[highIndex];
        final lowThreshold = highThreshold * parameters.cannyLowRatio;

        // Apply double thresholding in this cell
        final strongEdges = <List<int>>[];
        final weakEdges = <List<int>>[];

        for (int y = startY; y < endY; y++) {
          for (int x = startX; x < endX; x++) {
            final mag = suppressed[y][x];
            if (mag >= highThreshold) {
              edges[y][x] = true;
              strongEdges.add([x, y]);
            } else if (mag >= lowThreshold) {
              weakEdges.add([x, y]);
            }
          }
        }

        // Hysteresis tracking with halo cells support
        _hysteresisTrackingWithHalo(
          edges,
          strongEdges,
          weakEdges,
          suppressed,
          lowThreshold,
          parameters.hysteresisHaloCells,
          width,
          height,
          startX,
          endX,
          startY,
          endY,
        );
      }
    }

    // Count total edge pixels for coverage calculation
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (edges[y][x]) totalEdgePixels++;
      }
    }

    final edgeCoverage = totalEdgePixels / (width * height);
    if (kDebugMode) {
      debugPrint(
        'Edge coverage: ${(edgeCoverage * 100).toStringAsFixed(2)}% (${totalEdgePixels}/${width * height})',
      );
      debugPrint('Edges array dimensions: ${edges.length}x${edges[0].length}');
      // Count actual true values in edges array
      int actualEdgeCount = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          if (edges[y][x]) actualEdgeCount++;
        }
      }
      debugPrint('Actual edge count in edges array: $actualEdgeCount');
    }

    // Fallback to absolute threshold if coverage too low
    if (edgeCoverage < parameters.minEdgeCoverageAbs) {
      debugPrint('⚠️ Low edge coverage detected, using fallback');
      return _detectEdgesCanny(image, parameters);
    }

    return edges;
  }

  /// Helper for hysteresis tracking with halo cell support
  static void _hysteresisTrackingWithHalo(
    List<List<bool>> edges,
    List<List<int>> strongEdges,
    List<List<int>> weakEdges,
    List<List<double>> suppressed,
    double lowThreshold,
    int haloCells,
    int width,
    int height,
    int cellStartX,
    int cellEndX,
    int cellStartY,
    int cellEndY,
  ) {
    final queue = <List<int>>[];
    queue.addAll(strongEdges);

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final x = current[0];
      final y = current[1];

      // Check 8-connected neighbors (with halo extension for cell boundaries)
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;

          final nx = x + dx;
          final ny = y + dy;

          if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
          if (edges[ny][nx]) continue;

          // Allow halo extension outside current cell
          bool inHalo = false;
          if (haloCells > 0) {
            inHalo =
                (nx >= cellStartX - haloCells &&
                nx < cellEndX + haloCells &&
                ny >= cellStartY - haloCells &&
                ny < cellEndY + haloCells);
          }

          final inCurrentCell =
              (nx >= cellStartX &&
              nx < cellEndX &&
              ny >= cellStartY &&
              ny < cellEndY);

          if ((inCurrentCell || inHalo) && suppressed[ny][nx] >= lowThreshold) {
            edges[ny][nx] = true;
            queue.add([nx, ny]);
          }
        }
      }
    }
  }

  /// Extract skeleton from line art using simple thinning
  // ignore: unused_element
  static List<List<bool>> _extractSkeleton(img.Image image) {
    if (kDebugMode) debugPrint('Starting skeleton extraction');

    final width = image.width;
    final height = image.height;

    // Convert to binary (black/white)
    final binary = List.generate(height, (_) => List.filled(width, false));

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final luminance = (pixel.r + pixel.g + pixel.b) / 3;
        // Assume line art has black lines (low luminance) on white background
        binary[y][x] = luminance < 128; // Black pixels = true (foreground)
      }
    }

    // Apply simple thinning algorithm (Zhang-Suen algorithm simplified)
    final skeleton = _applyThinning(binary);

    if (kDebugMode) debugPrint('Skeleton extraction completed');
    return skeleton;
  }

  /// Apply thinning algorithm to create skeleton
  static List<List<bool>> _applyThinning(List<List<bool>> binary) {
    final height = binary.length;
    final width = binary[0].length;

    // Create working copy
    var skeleton = List.generate(height, (y) => List<bool>.from(binary[y]));

    bool changed = true;
    int iterations = 0;
    const maxIterations = 50; // Prevent infinite loops

    while (changed && iterations < maxIterations) {
      changed = false;
      iterations++;

      // Two sub-iterations for Zhang-Suen algorithm
      for (int subIter = 0; subIter < 2; subIter++) {
        final toRemove = <Point<int>>[];

        for (int y = 1; y < height - 1; y++) {
          for (int x = 1; x < width - 1; x++) {
            if (!skeleton[y][x]) continue; // Only process foreground pixels

            // Get 8-neighbors in order: P2, P3, P4, P5, P6, P7, P8, P9
            final neighbors = [
              skeleton[y - 1][x], // P2 (top)
              skeleton[y - 1][x + 1], // P3 (top-right)
              skeleton[y][x + 1], // P4 (right)
              skeleton[y + 1][x + 1], // P5 (bottom-right)
              skeleton[y + 1][x], // P6 (bottom)
              skeleton[y + 1][x - 1], // P7 (bottom-left)
              skeleton[y][x - 1], // P8 (left)
              skeleton[y - 1][x - 1], // P9 (top-left)
            ];

            // Count black neighbors
            final blackCount = neighbors.where((n) => n).length;

            // Count transitions from white to black
            int transitions = 0;
            for (int i = 0; i < 8; i++) {
              if (!neighbors[i] && neighbors[(i + 1) % 8]) {
                transitions++;
              }
            }

            // Zhang-Suen conditions
            bool condition1 = (blackCount >= 2 && blackCount <= 6);
            bool condition2 = (transitions == 1);

            bool condition3, condition4;
            if (subIter == 0) {
              // First sub-iteration
              condition3 =
                  !(neighbors[0] && neighbors[2] && neighbors[4]); // P2*P4*P6
              condition4 =
                  !(neighbors[2] && neighbors[4] && neighbors[6]); // P4*P6*P8
            } else {
              // Second sub-iteration
              condition3 =
                  !(neighbors[0] && neighbors[2] && neighbors[6]); // P2*P4*P8
              condition4 =
                  !(neighbors[0] && neighbors[4] && neighbors[6]); // P2*P6*P8
            }

            if (condition1 && condition2 && condition3 && condition4) {
              toRemove.add(Point(x, y));
            }
          }
        }

        // Remove marked pixels
        for (final point in toRemove) {
          skeleton[point.y][point.x] = false;
          changed = true;
        }
      }
    }

    if (kDebugMode) debugPrint('Thinning completed - iterations: $iterations');
    return skeleton;
  }

  /// Extract feature points from line art skeleton
  // ignore: unused_element
  static List<ConstellationPoint> _extractLineArtFeaturePoints(
    List<List<bool>> skeleton,
    ProcessingParameters parameters,
  ) {
    if (kDebugMode) debugPrint('Starting line art feature point extraction');

    final height = skeleton.length;
    final width = skeleton[0].length;
    final points = <ConstellationPoint>[];
    int pointId = 0;

    // Find endpoints, junctions, and high-curvature points
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        if (!skeleton[y][x]) continue; // Only process skeleton pixels

        // Count connected neighbors
        final neighbors = [
          skeleton[y - 1][x - 1],
          skeleton[y - 1][x],
          skeleton[y - 1][x + 1],
          skeleton[y][x - 1],
          skeleton[y][x + 1],
          skeleton[y + 1][x - 1],
          skeleton[y + 1][x],
          skeleton[y + 1][x + 1],
        ];

        final connectedCount = neighbors.where((n) => n).length;

        double intensity = 1.0;
        bool isKeyPoint = false;

        if (connectedCount == 1) {
          // Endpoint
          intensity = 0.9;
          isKeyPoint = true;
        } else if (connectedCount >= 3) {
          // Junction point
          intensity = 0.8;
          isKeyPoint = true;
        } else if (connectedCount == 2) {
          // Check for high curvature
          if (_isHighCurvature(skeleton, x, y)) {
            intensity = 0.7;
            isKeyPoint = true;
          }
        }

        if (isKeyPoint) {
          points.add(
            ConstellationPoint(
              x: x.toDouble(),
              y: y.toDouble(),
              intensity: intensity,
              id: pointId++,
            ),
          );
        }
      }
    }

    // Add regular sampling points if not enough key points
    if (points.length < parameters.maxPoints * 0.5) {
      _addSampledPoints(skeleton, points, parameters, pointId);
    }

    // Limit to max points
    points.sort((a, b) => b.intensity.compareTo(a.intensity));
    final finalPoints = points.take(parameters.maxPoints).toList();

    if (kDebugMode)
      debugPrint(
        'Line art feature point extraction completed - points: ${finalPoints.length}',
      );
    return finalPoints;
  }

  /// Check if a point has high curvature
  static bool _isHighCurvature(List<List<bool>> skeleton, int x, int y) {
    // Simple curvature detection by checking direction changes
    final directions = <Point<int>>[];

    // Find connected neighbors and their directions
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        if (skeleton[y + dy][x + dx]) {
          directions.add(Point(dx, dy));
        }
      }
    }

    if (directions.length != 2) return false;

    // Calculate angle between directions
    final dir1 = directions[0];
    final dir2 = directions[1];

    final dot = dir1.x * dir2.x + dir1.y * dir2.y;
    final mag1 = sqrt(dir1.x * dir1.x + dir1.y * dir1.y);
    final mag2 = sqrt(dir2.x * dir2.x + dir2.y * dir2.y);

    if (mag1 == 0 || mag2 == 0) return false;

    final cosAngle = dot / (mag1 * mag2);
    final angle = acos(cosAngle.clamp(-1.0, 1.0));

    // Consider high curvature if angle > 45 degrees
    return angle > pi / 4;
  }

  /// Add sampled points along skeleton lines
  static void _addSampledPoints(
    List<List<bool>> skeleton,
    List<ConstellationPoint> existingPoints,
    ProcessingParameters parameters,
    int startId,
  ) {
    final height = skeleton.length;
    final width = skeleton[0].length;
    final samplingInterval = 20; // Sample every 20 pixels
    int pointId = startId;

    for (int y = 0; y < height; y += samplingInterval) {
      for (int x = 0; x < width; x += samplingInterval) {
        if (!skeleton[y][x]) continue;

        // Check if too close to existing points
        bool tooClose = false;
        for (final existing in existingPoints) {
          final dist = sqrt(pow(existing.x - x, 2) + pow(existing.y - y, 2));
          if (dist < 15) {
            tooClose = true;
            break;
          }
        }

        if (!tooClose) {
          existingPoints.add(
            ConstellationPoint(
              x: x.toDouble(),
              y: y.toDouble(),
              intensity: 0.5,
              id: pointId++,
            ),
          );
        }
      }
    }
  }

  /// Generate constellation lines from line art key points
  // ignore: unused_element
  static List<ConstellationLine> _generateLineArtConstellationLines(
    List<ConstellationPoint> points,
    List<List<bool>> skeleton,
    ProcessingParameters parameters,
  ) {
    if (kDebugMode)
      debugPrint('Starting line art constellation line generation');

    final lines = <ConstellationLine>[];

    // Strategy 1: Connect nearby points along skeleton paths
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final point1 = points[i];
        final point2 = points[j];

        final distance = sqrt(
          pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2),
        );

        // Connect if reasonably close and path follows skeleton
        if (distance < 100 && _hasSkeletonPath(skeleton, point1, point2)) {
          final opacity = (1.0 - distance / 100).clamp(0.3, 0.9);
          final thickness = parameters.lineThickness * opacity;

          lines.add(
            ConstellationLine(
              startPointId: point1.id,
              endPointId: point2.id,
              thickness: thickness,
              opacity: opacity,
            ),
          );
        }
      }
    }

    if (kDebugMode)
      debugPrint(
        'Line art constellation line generation completed - lines: ${lines.length}',
      );
    return lines;
  }

  /// Check if there's a skeleton path between two points
  static bool _hasSkeletonPath(
    List<List<bool>> skeleton,
    ConstellationPoint point1,
    ConstellationPoint point2,
  ) {
    // Simple line-of-sight check along skeleton
    final x1 = point1.x.round();
    final y1 = point1.y.round();
    final x2 = point2.x.round();
    final y2 = point2.y.round();

    final dx = (x2 - x1).abs();
    final dy = (y2 - y1).abs();
    final steps = max(dx, dy);

    if (steps == 0) return true;

    final xStep = (x2 - x1) / steps;
    final yStep = (y2 - y1) / steps;

    int skeletonHits = 0;
    for (int i = 0; i <= steps; i++) {
      final x = (x1 + xStep * i).round();
      final y = (y1 + yStep * i).round();

      if (x >= 0 && x < skeleton[0].length && y >= 0 && y < skeleton.length) {
        if (skeleton[y][x]) skeletonHits++;
      }
    }

    // Require at least 30% of the path to be on skeleton
    return skeletonHits / steps > 0.3;
  }

  /// Count non-zero pixels in skeleton
  // ignore: unused_element
  static int _countNonZeroPixels(List<List<bool>> skeleton) {
    int count = 0;
    for (final row in skeleton) {
      for (final pixel in row) {
        if (pixel) count++;
      }
    }
    return count;
  }
}

/// Helper class for edges in Delaunay triangulation
class _Edge {
  final int a;
  final int b;

  _Edge(int a, int b) : a = min(a, b), b = max(a, b);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _Edge && a == other.a && b == other.b;

  @override
  int get hashCode => a.hashCode ^ b.hashCode;
}

/// Task for isolate processing
class ProcessingTask {
  final ImageEntity imageEntity;
  final ProcessingParameters parameters;

  const ProcessingTask({required this.imageEntity, required this.parameters});
}

/// Task for line art geometry processing
class LineArtProcessingTask {
  final LineArtEntity lineArtEntity;
  final ProcessingParameters parameters;

  const LineArtProcessingTask({
    required this.lineArtEntity,
    required this.parameters,
  });
}

/// Extract constellation points using enhanced pipeline
///
/// 新しい処理パイプライン:
/// 1. 二値化 → 2. 形態学的前処理 → 3. 骨格化 → 4. 特徴点検出 → 5. 階層的星配置
List<ConstellationPoint> _extractConstellationPointsEnhanced(
  img.Image image,
  ProcessingParameters parameters,
) {
  debugPrint('🌟 [NEW] 新しい星座変換パイプライン開始 (${image.width}x${image.height})');

  try {
    // Step 1: 二値化処理
    final binaryImage = _convertToBinaryImage(image, threshold: 128);
    final originalPixels = _countTruePixels(binaryImage);
    debugPrint('📊 [BINARY] 二値化完了: ${originalPixels}個のピクセル');

    // Step 2: 形態学的前処理（ノイズ除去・断線修復）
    final morphResult = MorphologicalProcessor.preprocessLineArt(
      binaryImage,
      noiseRemovalKernel: 3,
      gapClosingKernel: 5,
      minComponentSize: 10,
    );
    debugPrint(
      '🧹 [MORPH] 形態学的処理: ${morphResult.originalComponentCount} → ${morphResult.filteredComponentCount} 成分',
    );

    // Step 3: Zhang-Suen骨格化
    final skeleton = SkeletonizationProcessor.zhangSuenThinning(
      morphResult.cleanedImage,
    );
    final skeletonPixels = _countTruePixels(skeleton);
    debugPrint(
      '🦴 [SKELETON] 骨格化完了: ${skeletonPixels}個のピクセル (圧縮率: ${((1.0 - skeletonPixels / originalPixels) * 100).toStringAsFixed(1)}%)',
    );

    // Step 4: 特徴点検出
    final features = FeatureDetector.detectFeatures(skeleton);
    debugPrint(
      '🎯 [FEATURES] 特徴点検出: 端点${features.endpoints.length}個, 分岐点${features.junctions.length}個, 曲率${features.highCurvaturePoints.length}個',
    );

    // Step 5: 骨格追跡ベースの星配置
    final constellationPoints = _placeStarsWithSkeletonTracing(
      skeleton,
      features,
      parameters,
    );
    debugPrint('⭐ [STARS] 骨格追跡ベースの星配置完了: ${constellationPoints.length}個の星');

    return constellationPoints;
  } catch (e, stackTrace) {
    debugPrint('❌ [ERROR] 星座変換パイプライン失敗: $e');
    debugPrint('📍 [STACK] $stackTrace');

    // フォールバック: 従来の処理
    return _extractConstellationPointsFallback(image, parameters);
  }
}

/// 画像を二値化
List<List<bool>> _convertToBinaryImage(img.Image image, {int threshold = 128}) {
  final int height = image.height;
  final int width = image.width;

  List<List<bool>> binaryImage = List.generate(
    height,
    (y) => List.generate(width, (x) {
      final pixel = image.getPixel(x, y);
      final luminance = img.getLuminance(pixel);
      return luminance < threshold; // 暗いピクセルが前景
    }),
  );

  return binaryImage;
}

/// 骨格追跡ベースの星配置
List<ConstellationPoint> _placeStarsWithSkeletonTracing(
  List<List<bool>> skeleton,
  SkeletonFeatures features,
  ProcessingParameters parameters,
) {
  debugPrint('🌟 [SKELETON-TRACE] 骨格追跡ベースの星配置を開始');

  // Step 1: 骨格から線分を追跡
  final lineSegments = SkeletonTracer.traceSkeleton(skeleton, features);
  debugPrint('📏 [SKELETON-TRACE] 追跡完了: ${lineSegments.length}個の線分');

  // Step 2: 線分に沿って星を配置
  List<ConstellationPoint> stars = [];
  int starId = 0;
  double minStarDistance = parameters.minStarDistance ?? 15.0;

  for (final segment in lineSegments) {
    // 端点に必ず星を配置（高輝度）
    stars.add(
      ConstellationPoint(
        x: segment.startPoint.x.toDouble(),
        y: segment.startPoint.y.toDouble(),
        intensity: 1.0, // 端点は最高輝度
        id: starId++,
      ),
    );

    // 線分の長さに応じて中間点に星を配置
    List<Point<int>> sampledPoints = segment.samplePoints(minStarDistance);

    for (final p in sampledPoints) {
      // 曲率に基づく輝度計算（曲率が高いほど明るい）
      double intensity = 0.4 + (segment.curvature * 0.6);

      stars.add(
        ConstellationPoint(
          x: p.x.toDouble(),
          y: p.y.toDouble(),
          intensity: intensity,
          id: starId++,
        ),
      );
    }

    // 終点に星を配置（重複チェック）
    if (!_isNearExistingStar(segment.endPoint, stars, minStarDistance)) {
      stars.add(
        ConstellationPoint(
          x: segment.endPoint.x.toDouble(),
          y: segment.endPoint.y.toDouble(),
          intensity: 1.0, // 終点も高輝度
          id: starId++,
        ),
      );
    }
  }

  // Step 3: maxPointsを超えている場合は制限
  if (stars.length > parameters.maxPoints) {
    // 輝度順でソートして上位を選択
    stars.sort((a, b) => b.intensity.compareTo(a.intensity));
    stars = stars.take(parameters.maxPoints).toList();

    // IDを振り直し
    for (int i = 0; i < stars.length; i++) {
      stars[i] = ConstellationPoint(
        x: stars[i].x,
        y: stars[i].y,
        intensity: stars[i].intensity,
        id: i,
      );
    }

    debugPrint(
      '⚡ [SKELETON-TRACE] 星数を制限: ${stars.length}個 (最大: ${parameters.maxPoints}個)',
    );
  }

  debugPrint('✅ [SKELETON-TRACE] 星配置完了: ${stars.length}個の星');

  // デバッグ情報
  final avgIntensity =
      stars.fold(0.0, (sum, star) => sum + star.intensity) / stars.length;
  debugPrint(
    '📊 [SKELETON-TRACE] 統計: 平均輝度=${avgIntensity.toStringAsFixed(3)}, 線分数=${lineSegments.length}',
  );

  return stars;
}

/// 既存の星の近くかどうかチェック
bool _isNearExistingStar(
  Point<int> point,
  List<ConstellationPoint> existingStars,
  double minDistance,
) {
  for (final star in existingStars) {
    final distance = sqrt(
      pow(star.x - point.x.toDouble(), 2) + pow(star.y - point.y.toDouble(), 2),
    );
    if (distance < minDistance) {
      return true;
    }
  }
  return false;
}

/// 骨格追跡ベースの星座線生成
List<_ConstellationLine> _generateLinesFromSkeletonTracing(
  List<ConstellationPoint> constellationPoints,
  img.Image image,
  ProcessingParameters parameters,
) {
  debugPrint('🔗 [SKELETON-LINES] 骨格追跡ベースの線生成を開始');

  // Step 1: 画像を再処理して骨格と特徴点を取得
  final binaryImage = _convertToBinaryImage(image, threshold: 128);
  final morphResult = MorphologicalProcessor.preprocessLineArt(
    binaryImage,
    noiseRemovalKernel: 3,
    gapClosingKernel: 5,
    minComponentSize: 10,
  );
  final skeleton = SkeletonizationProcessor.zhangSuenThinning(
    morphResult.cleanedImage,
  );
  final features = FeatureDetector.detectFeatures(skeleton);

  // Step 2: 骨格から線分を追跡
  final lineSegments = SkeletonTracer.traceSkeleton(skeleton, features);

  // Step 3: 各線分に対応する星を特定し、順次接続
  List<_ConstellationLine> lines = [];
  double minStarDistance = parameters.minStarDistance ?? 15.0;

  for (final segment in lineSegments) {
    List<ConstellationPoint> segmentStars = _findStarsOnSegment(
      constellationPoints,
      segment,
      minStarDistance * 1.5, // 少し余裕を持って検索
    );

    // 線分に沿った順序で星をソート
    segmentStars = _sortStarsAlongSegment(segmentStars, segment);

    // 隣接する星同士を接続
    for (int i = 0; i < segmentStars.length - 1; i++) {
      lines.add(
        _ConstellationLine(
          startPointId: segmentStars[i].id,
          endPointId: segmentStars[i + 1].id,
          thickness: _calculateLineThickness(segment),
          opacity: _calculateLineOpacity(segment),
        ),
      );
    }

    debugPrint(
      '📏 [SKELETON-LINES] 線分から線を生成: ${segmentStars.length}個の星, ${segmentStars.length - 1}本の線',
    );
  }

  debugPrint('✅ [SKELETON-LINES] 線生成完了: ${lines.length}本');
  return lines;
}

/// 線分上にある星を特定
List<ConstellationPoint> _findStarsOnSegment(
  List<ConstellationPoint> allStars,
  SkeletonSegment segment,
  double maxDistance,
) {
  List<ConstellationPoint> segmentStars = [];

  // 各星について、線分との最短距離を計算
  for (final star in allStars) {
    double minDistToSegment = double.infinity;

    // 線分の各ピクセルに対する距離を計算
    for (final pixel in segment.pixels) {
      double dist = sqrt(
        pow(star.x - pixel.x.toDouble(), 2) +
            pow(star.y - pixel.y.toDouble(), 2),
      );
      minDistToSegment = min(minDistToSegment, dist);
    }

    // 閾値以内なら線分の星として認定
    if (minDistToSegment <= maxDistance) {
      segmentStars.add(star);
    }
  }

  return segmentStars;
}

/// 線分に沿って星をソート
List<ConstellationPoint> _sortStarsAlongSegment(
  List<ConstellationPoint> stars,
  SkeletonSegment segment,
) {
  if (stars.length <= 1) return stars;

  // 各星について、線分の開始点からの距離を計算してソート
  stars.sort((a, b) {
    double distA = sqrt(
      pow(a.x - segment.startPoint.x.toDouble(), 2) +
          pow(a.y - segment.startPoint.y.toDouble(), 2),
    );
    double distB = sqrt(
      pow(b.x - segment.startPoint.x.toDouble(), 2) +
          pow(b.y - segment.startPoint.y.toDouble(), 2),
    );
    return distA.compareTo(distB);
  });

  return stars;
}

/// 線分の曲率に基づいて線の太さを計算
double _calculateLineThickness(SkeletonSegment segment) {
  // 曲率が高いほど細く、直線に近いほど太く
  double baseTickness = 1.5;
  double curvatureMultiplier = 1.0 - (segment.curvature * 0.5);
  return baseTickness * curvatureMultiplier.clamp(0.5, 1.5);
}

/// 線分の長さに基づいて線の透明度を計算
double _calculateLineOpacity(SkeletonSegment segment) {
  // 長い線分ほど不透明に（最大0.9、最小0.6）
  double lengthFactor = (segment.length / 100.0).clamp(0.0, 1.0);
  return 0.6 + (lengthFactor * 0.3);
}

/// 二値画像内のtrueピクセル数をカウント
int _countTruePixels(List<List<bool>> image) {
  int count = 0;
  for (var row in image) {
    count += row.where((pixel) => pixel).length;
  }
  return count;
}

/// フォールバック: 従来の処理方式
List<ConstellationPoint> _extractConstellationPointsFallback(
  img.Image image,
  ProcessingParameters parameters,
) {
  debugPrint('⚠️ [FALLBACK] 従来方式で処理中...');

  final linePixels = <Point<int>>[];
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final luminance = img.getLuminance(pixel);
      if (luminance < 128) {
        linePixels.add(Point(x, y));
      }
    }
  }

  // 従来のロジックで ConstellationPoint に変換
  List<ConstellationPoint> points = [];
  int id = 0;
  for (var pixel in linePixels.take(parameters.maxPoints)) {
    points.add(
      ConstellationPoint(
        x: pixel.x.toDouble(),
        y: pixel.y.toDouble(),
        intensity: 0.7,
        id: id++,
      ),
    );
  }

  debugPrint('📊 [FALLBACK] フォールバック完了: ${points.length}個の星');
  return points;
}

/// フォールバック用の従来のピクセル抽出
List<Point<int>> _extractLinePixelsFallback(img.Image image) {
  final linePixels = <Point<int>>[];

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final luminance = img.getLuminance(pixel);

      if (luminance < 128) {
        linePixels.add(Point(x, y));
      }
    }
  }

  debugPrint('📊 [FALLBACK] 従来方式でピクセル抽出: ${linePixels.length}個');
  return linePixels;
}

/// ConstellationPointから線を生成
// ignore: unused_element
List<_ConstellationLine> _generateLinesFromConstellationPoints(
  List<ConstellationPoint> points,
  int width,
  int height,
) {
  List<_ConstellationLine> lines = [];

  if (points.length < 2) {
    debugPrint('🔗 [LINES] 点が少なすぎるため線を生成できません');
    return lines;
  }

  // 簡単な実装: 近接する点を接続
  const double maxDistance = 50.0;

  for (int i = 0; i < points.length; i++) {
    for (int j = i + 1; j < points.length; j++) {
      double distance = sqrt(
        pow(points[i].x - points[j].x, 2) + pow(points[i].y - points[j].y, 2),
      );

      if (distance <= maxDistance) {
        lines.add(
          _ConstellationLine(
            startPointId: points[i].id,
            endPointId: points[j].id,
            thickness: 1.0,
            opacity: 0.8,
          ),
        );
      }
    }
  }

  debugPrint('🔗 [LINES] 星座線生成: ${lines.length}本の線');
  return lines;
}

/// Enhanced line tracing with morphological operations and performance optimizations
List<_LineSegment> _traceLineSegmentsMorphological(
  List<Point<int>> linePixels,
  int width,
  int height,
) {
  final segments = <_LineSegment>[];

  // Performance check: Skip if too few pixels
  if (linePixels.length < 10) {
    debugPrint(
      '⚡ [PERF] Skipping morphological tracing: insufficient pixels (${linePixels.length})',
    );
    return segments;
  }

  // Step 1: Convert pixels to binary image (optimized)
  final binaryImage = List.generate(
    height,
    (_) => List<bool>.filled(width, false),
  );
  int validPixels = 0;
  for (final pixel in linePixels) {
    if (pixel.x >= 0 && pixel.x < width && pixel.y >= 0 && pixel.y < height) {
      binaryImage[pixel.y][pixel.x] = true;
      validPixels++;
    }
  }

  debugPrint(
    '⚡ [PERF] Morphological tracing: ${validPixels} valid pixels from ${linePixels.length} total',
  );

  // Step 2: Morphological thinning (Zhang-Suen algorithm)
  final skeleton = _zhangSuenThinning(binaryImage, width, height);

  // Step 3: Extract endpoints and junctions from skeleton
  final endpoints = _extractEndpoints(skeleton, width, height);
  final junctions = _extractJunctions(skeleton, width, height);

  debugPrint(
    '🔍 [DEBUG] Skeleton analysis: ${skeleton.length} pixels, ${endpoints.length} endpoints, ${junctions.length} junctions',
  );

  // Step 4: Trace paths between endpoints and junctions
  final tracedPaths = _traceSkeletonPaths(
    skeleton,
    endpoints,
    junctions,
    width,
    height,
  );

  // Convert to line segments
  for (final path in tracedPaths) {
    if (path.length >= 3) {
      // Minimum 3 pixels for a valid segment
      segments.add(_LineSegment(path));
    }
  }

  debugPrint(
    '📐 [DEBUG] Enhanced tracing: ${segments.length} segments from ${tracedPaths.length} paths',
  );
  return segments;
}

/// Optimized Zhang-Suen thinning algorithm for skeletonization
List<Point<int>> _zhangSuenThinning(
  List<List<bool>> binaryImage,
  int width,
  int height,
) {
  final skeleton = <Point<int>>[];

  // Performance optimization: Early exit for small images
  if (width < 5 || height < 5) {
    debugPrint(
      '⚡ [PERF] Skipping thinning: image too small (${width}x${height})',
    );
    return skeleton;
  }

  // Create working copy with memory optimization
  final image = List.generate(height, (y) => List<bool>.from(binaryImage[y]));

  bool hasChanged = true;
  int iterations = 0;
  const maxIterations = 50; // Reduced from 100 for performance
  int totalPixels = 0;

  // Count initial pixels for progress tracking
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (image[y][x]) totalPixels++;
    }
  }

  debugPrint(
    '⚡ [PERF] Starting thinning: ${totalPixels} pixels, max iterations: $maxIterations',
  );

  while (hasChanged && iterations < maxIterations && totalPixels > 0) {
    hasChanged = false;
    iterations++;

    // Optimization: Process only border regions
    final borderPixels = <Point<int>>[];
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        if (image[y][x]) {
          // Check if this is a border pixel
          bool isBorder = false;
          for (int dy = -1; dy <= 1 && !isBorder; dy++) {
            for (int dx = -1; dx <= 1 && !isBorder; dx++) {
              if (dx == 0 && dy == 0) continue;
              final nx = x + dx;
              final ny = y + dy;
              if (nx >= 0 &&
                  nx < width &&
                  ny >= 0 &&
                  ny < height &&
                  !image[ny][nx]) {
                isBorder = true;
              }
            }
          }
          if (isBorder) {
            borderPixels.add(Point(x, y));
          }
        }
      }
    }

    // Step 1: Remove south-east boundary points (optimized)
    final toRemove1 = <Point<int>>[];
    for (final point in borderPixels) {
      if (image[point.y][point.x] &&
          _shouldRemoveInStep1(image, point.x, point.y, width, height)) {
        toRemove1.add(point);
      }
    }

    // Remove identified points
    for (final point in toRemove1) {
      if (image[point.y][point.x]) {
        image[point.y][point.x] = false;
        hasChanged = true;
        totalPixels--;
      }
    }

    // Step 2: Remove north-west boundary points (optimized)
    final toRemove2 = <Point<int>>[];
    for (final point in borderPixels) {
      if (image[point.y][point.x] &&
          _shouldRemoveInStep2(image, point.x, point.y, width, height)) {
        toRemove2.add(point);
      }
    }

    // Remove identified points
    for (final point in toRemove2) {
      if (image[point.y][point.x]) {
        image[point.y][point.x] = false;
        hasChanged = true;
        totalPixels--;
      }
    }

    // Early exit if too many pixels removed in one iteration
    if (totalPixels < borderPixels.length * 0.1) {
      debugPrint(
        '⚡ [PERF] Early exit: too many pixels removed in iteration $iterations',
      );
      break;
    }
  }

  // Collect remaining pixels as skeleton
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (image[y][x]) {
        skeleton.add(Point(x, y));
      }
    }
  }

  debugPrint(
    '🦴 [DEBUG] Zhang-Suen thinning completed in $iterations iterations, skeleton: ${skeleton.length} pixels',
  );
  return skeleton;
}

/// Check if point should be removed in Step 1 (south-east boundary)
bool _shouldRemoveInStep1(
  List<List<bool>> image,
  int x,
  int y,
  int width,
  int height,
) {
  // Get 8-neighbors
  final p2 = image[y - 1][x]; // North
  final p3 = image[y - 1][x + 1]; // North-East
  final p4 = image[y][x + 1]; // East
  final p5 = image[y + 1][x + 1]; // South-East
  final p6 = image[y + 1][x]; // South
  final p7 = image[y + 1][x - 1]; // South-West
  final p8 = image[y][x - 1]; // West
  final p9 = image[y - 1][x - 1]; // North-West

  // Count black neighbors
  final neighbors = [p2, p3, p4, p5, p6, p7, p8, p9];
  final blackCount = neighbors.where((p) => p).length;

  // Condition 1: 2 <= B(P1) <= 6
  if (blackCount < 2 || blackCount > 6) return false;

  // Condition 2: A(P1) == 1 (single transition)
  if (_countTransitions(neighbors) != 1) return false;

  // Condition 3: P2*P4*P6 == 0
  if (p2 && p4 && p6) return false;

  // Condition 4: P4*P6*P8 == 0
  if (p4 && p6 && p8) return false;

  return true;
}

/// Check if point should be removed in Step 2 (north-west boundary)
bool _shouldRemoveInStep2(
  List<List<bool>> image,
  int x,
  int y,
  int width,
  int height,
) {
  // Get 8-neighbors
  final p2 = image[y - 1][x]; // North
  final p3 = image[y - 1][x + 1]; // North-East
  final p4 = image[y][x + 1]; // East
  final p5 = image[y + 1][x + 1]; // South-East
  final p6 = image[y + 1][x]; // South
  final p7 = image[y + 1][x - 1]; // South-West
  final p8 = image[y][x - 1]; // West
  final p9 = image[y - 1][x - 1]; // North-West

  // Count black neighbors
  final neighbors = [p2, p3, p4, p5, p6, p7, p8, p9];
  final blackCount = neighbors.where((p) => p).length;

  // Condition 1: 2 <= B(P1) <= 6
  if (blackCount < 2 || blackCount > 6) return false;

  // Condition 2: A(P1) == 1 (single transition)
  if (_countTransitions(neighbors) != 1) return false;

  // Condition 3: P2*P4*P8 == 0
  if (p2 && p4 && p8) return false;

  // Condition 4: P2*P6*P8 == 0
  if (p2 && p6 && p8) return false;

  return true;
}

/// Count 0-1 transitions in 8-neighbors (clockwise)
int _countTransitions(List<bool> neighbors) {
  int transitions = 0;
  for (int i = 0; i < 8; i++) {
    if (!neighbors[i] && neighbors[(i + 1) % 8]) {
      transitions++;
    }
  }
  return transitions;
}

/// Extract endpoints from skeleton (pixels with exactly 1 neighbor)
List<Point<int>> _extractEndpoints(
  List<Point<int>> skeleton,
  int width,
  int height,
) {
  final endpoints = <Point<int>>[];
  final skeletonSet = Set<Point<int>>.from(skeleton);

  for (final point in skeleton) {
    final neighbors = _getNeighbors(point, width, height);
    final connectedNeighbors = neighbors
        .where((n) => skeletonSet.contains(n))
        .length;

    if (connectedNeighbors == 1) {
      endpoints.add(point);
    }
  }

  debugPrint('🎯 [DEBUG] Extracted ${endpoints.length} endpoints');
  return endpoints;
}

/// Extract junctions from skeleton (pixels with 3 or more neighbors)
List<Point<int>> _extractJunctions(
  List<Point<int>> skeleton,
  int width,
  int height,
) {
  final junctions = <Point<int>>[];
  final skeletonSet = Set<Point<int>>.from(skeleton);

  for (final point in skeleton) {
    final neighbors = _getNeighbors(point, width, height);
    final connectedNeighbors = neighbors
        .where((n) => skeletonSet.contains(n))
        .length;

    if (connectedNeighbors >= 3) {
      junctions.add(point);
    }
  }

  debugPrint('🔀 [DEBUG] Extracted ${junctions.length} junctions');
  return junctions;
}

/// Get 8-neighbors of a point
List<Point<int>> _getNeighbors(Point<int> point, int width, int height) {
  final neighbors = <Point<int>>[];
  final dx = [-1, -1, -1, 0, 0, 1, 1, 1];
  final dy = [-1, 0, 1, -1, 1, -1, 0, 1];

  for (int i = 0; i < 8; i++) {
    final nx = point.x + dx[i];
    final ny = point.y + dy[i];

    if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
      neighbors.add(Point(nx, ny));
    }
  }

  return neighbors;
}

/// Trace paths between endpoints and junctions in skeleton
List<List<Point<int>>> _traceSkeletonPaths(
  List<Point<int>> skeleton,
  List<Point<int>> endpoints,
  List<Point<int>> junctions,
  int width,
  int height,
) {
  final paths = <List<Point<int>>>[];
  final skeletonSet = Set<Point<int>>.from(skeleton);
  final visited = Set<Point<int>>();

  // Start from each endpoint
  for (final startPoint in endpoints) {
    if (visited.contains(startPoint)) continue;

    final queue = <List<Point<int>>>[];
    final pathVisited = Set<Point<int>>();

    queue.add([startPoint]);
    pathVisited.add(startPoint);

    while (queue.isNotEmpty) {
      final currentPath = queue.removeAt(0);
      final currentPoint = currentPath.last;

      // Check if we reached another endpoint or junction
      final isEndpoint =
          endpoints.contains(currentPoint) && currentPoint != startPoint;
      final isJunction = junctions.contains(currentPoint);

      if (isEndpoint || isJunction) {
        // Found a complete path
        if (currentPath.length >= 3) {
          paths.add(List<Point<int>>.from(currentPath));
        }
        continue;
      }

      // Continue tracing from current point
      final neighbors = _getNeighbors(currentPoint, width, height);
      final connectedNeighbors = neighbors
          .where((n) => skeletonSet.contains(n) && !pathVisited.contains(n))
          .toList();

      for (final neighbor in connectedNeighbors) {
        final newPath = List<Point<int>>.from(currentPath)..add(neighbor);
        queue.add(newPath);
        pathVisited.add(neighbor);
      }

      // Prevent infinite loops
      if (queue.length > 1000) break;
    }
  }

  debugPrint('🛤️ [DEBUG] Traced ${paths.length} skeleton paths');
  return paths;
}

/// Original tracing method (kept for compatibility)
List<_LineSegment> _traceLineSegments(
  List<Point<int>> linePixels,
  int width,
  int height,
) {
  final segments = <_LineSegment>[];
  final visited = List.generate(height, (_) => List.filled(width, false));

  // Mark all line pixels as visited initially
  for (final pixel in linePixels) {
    if (pixel.x >= 0 && pixel.x < width && pixel.y >= 0 && pixel.y < height) {
      visited[pixel.y][pixel.x] = true;
    }
  }

  for (final startPixel in linePixels) {
    if (!visited[startPixel.y][startPixel.x]) continue;

    // Start tracing a new segment
    final segmentPixels = <Point<int>>[];
    final queue = <Point<int>>[startPixel];
    visited[startPixel.y][startPixel.x] = false; // Mark as processed

    // BFS to find connected pixels
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      segmentPixels.add(current);

      // Check 8-connected neighbors
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;

          final nx = current.x + dx;
          final ny = current.y + dy;

          if (nx >= 0 &&
              nx < width &&
              ny >= 0 &&
              ny < height &&
              visited[ny][nx]) {
            visited[ny][nx] = false; // Mark as processed
            queue.add(Point(nx, ny));
          }
        }
      }
    }

    if (segmentPixels.length >= 3) {
      // Only consider segments with at least 3 pixels
      segments.add(_LineSegment(segmentPixels));
    }
  }

  debugPrint('📏 [DEBUG] Traced ${segments.length} line segments');
  return segments;
}

/// Generate constellation points along line segments
List<_FeaturePoint> _generatePointsAlongLines(
  List<_LineSegment> segments,
  ProcessingParameters parameters,
  int width,
  int height,
) {
  final points = <_FeaturePoint>[];
  int pointId = 0;

  // Step 1: Calculate total line length for proportional allocation
  double totalLineLength = 0.0;
  for (final segment in segments) {
    totalLineLength += segment.length;
  }

  // Step 2: Distribute points proportionally with curvature consideration
  final targetLinePoints = (parameters.maxPoints * 0.6)
      .round(); // 60% for line-based points
  int allocatedPoints = 0;

  for (final segment in segments) {
    final length = segment.length;
    if (length < 10) continue; // Skip very short segments

    // Calculate proportional allocation
    final segmentProportion = length / totalLineLength;
    final basePoints = (targetLinePoints * segmentProportion).round().clamp(
      1,
      12,
    );

    // Adjust for curvature
    final curvatureScore = segment.curvature;
    final int curvatureAdjustment = (curvatureScore * 2.0).round().clamp(0, 3);
    final int numPoints = basePoints + curvatureAdjustment;

    for (int i = 0; i < numPoints; i++) {
      final t = i / (numPoints - 1).clamp(1, numPoints - 1);
      final position = segment.getPointAt(t);

      // Calculate local intensity based on position and curvature
      final localIntensity = _calculateLinePointIntensity(
        position,
        segment,
        width,
        height,
        curvatureScore,
      );

      points.add(
        _FeaturePoint(
          x: position.x,
          y: position.y,
          intensity: localIntensity,
          priority: curvatureScore > 0.3
              ? 2
              : 1, // Higher priority for curved segments
          id: pointId,
        ),
      );

      pointId++;
      allocatedPoints++;
    }
  }

  debugPrint(
    '📍 [DEBUG] Generated $allocatedPoints line-based points (${points.length} total)',
  );

  // Step 3: Apply spatial distribution constraints
  _applySpatialConstraints(points, width, height, parameters);

  // Limit total points and assign final IDs
  final maxPoints = parameters.maxPoints;
  if (points.length > maxPoints) {
    points.sort((a, b) => b.priority.compareTo(a.priority));
    points.length = maxPoints;
  }

  // Re-assign IDs after filtering
  for (int i = 0; i < points.length; i++) {
    points[i] = _FeaturePoint(
      x: points[i].x,
      y: points[i].y,
      intensity: points[i].intensity,
      priority: points[i].priority,
      id: i,
    );
  }

  debugPrint(
    '⭐ [DEBUG] Generated ${points.length} constellation points from ${segments.length} segments',
  );
  return points;
}

/// Calculate curvature score for a line segment (0.0 = straight, 1.0 = highly curved)
// ignore: unused_element
double _calculateSkeletonSegmentCurvature(SkeletonSegment segment) {
  if (segment.pixels.length < 5) return 0.0;

  double totalAngleChange = 0.0;
  int validMeasurements = 0;

  // Sample points for curvature calculation
  final samplePoints = <Point<int>>[];
  final step = (segment.pixels.length / 10).ceil().clamp(
    1,
    5,
  ); // Sample every 1-5 pixels

  for (int i = 0; i < segment.pixels.length; i += step) {
    samplePoints.add(segment.pixels[i]);
  }

  if (samplePoints.length < 3) return 0.0;

  // Calculate angle changes between consecutive triplets
  for (int i = 1; i < samplePoints.length - 1; i++) {
    final p1 = samplePoints[i - 1];
    final p2 = samplePoints[i];
    final p3 = samplePoints[i + 1];

    // Calculate vectors
    final v1x = p2.x - p1.x;
    final v1y = p2.y - p1.y;
    final v2x = p3.x - p2.x;
    final v2y = p3.y - p2.y;

    // Calculate angle between vectors
    final dot = v1x * v2x + v1y * v2y;
    final mag1 = sqrt(v1x * v1x + v1y * v1y);
    final mag2 = sqrt(v2x * v2x + v2y * v2y);

    if (mag1 > 0.1 && mag2 > 0.1) {
      final cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
      final angle = acos(cosAngle);
      totalAngleChange += angle;
      validMeasurements++;
    }
  }

  return validMeasurements > 0
      ? (totalAngleChange / validMeasurements / pi).clamp(0.0, 1.0)
      : 0.0;
}

/// Calculate adaptive spacing for line point placement
// ignore: unused_element
double _calculateAdaptiveLineSpacing(
  double length,
  int numPoints,
  double curvatureScore,
  ProcessingParameters parameters,
) {
  final baseSpacing = length / numPoints;

  // Reduce spacing for curved segments (more points needed)
  final curvatureFactor = 1.0 - (curvatureScore * 0.4); // 0.6-1.0

  // Adjust for point density parameter
  final densityFactor =
      2.0 - parameters.pointDensity; // Higher density = smaller spacing

  return (baseSpacing * curvatureFactor * densityFactor).clamp(5.0, 50.0);
}

/// Calculate intensity for a point on a line segment
double _calculateLinePointIntensity(
  Point<double> position,
  _LineSegment segment,
  int width,
  int height,
  double curvatureScore,
) {
  double intensity = 0.7; // Base intensity

  // Boost for endpoints
  if (segment.pixels.isNotEmpty) {
    final firstPixel = segment.pixels.first;
    final lastPixel = segment.pixels.last;
    final distanceToStart = sqrt(
      pow(position.x - firstPixel.x, 2) + pow(position.y - firstPixel.y, 2),
    );
    final distanceToEnd = sqrt(
      pow(position.x - lastPixel.x, 2) + pow(position.y - lastPixel.y, 2),
    );

    if (distanceToStart < 5 || distanceToEnd < 5) {
      intensity += 0.15; // Endpoint bonus
    }
  }

  // Boost for curved regions
  intensity += curvatureScore * 0.2; // Curvature bonus

  // Boost near image boundaries
  final borderDistance = min(
    min(position.x, position.y),
    min(width - 1 - position.x, height - 1 - position.y),
  );
  if (borderDistance < 30) {
    intensity += 0.1; // Boundary bonus
  }

  return intensity.clamp(0.5, 1.0);
}

/// Apply spatial distribution constraints to prevent clustering (optimized)
void _applySpatialConstraints(
  List<_FeaturePoint> points,
  int width,
  int height,
  ProcessingParameters parameters,
) {
  if (points.length < 3) return;

  final minDistance = (15 / parameters.pointDensity).round().clamp(8, 25);
  final minDistanceSquared =
      minDistance * minDistance; // Avoid sqrt for performance
  final toRemove = <int>[];

  // Performance optimization: Use spatial grid for faster neighbor lookup
  final gridSize = (minDistance * 1.5).round().clamp(16, 64);
  final gridWidth = (width / gridSize).ceil();
  final gridHeight = (height / gridSize).ceil();

  // Create spatial grid
  final grid = List.generate(
    gridHeight,
    (_) => List<Set<int>>.generate(gridWidth, (_) => <int>{}),
  );

  // Assign points to grid cells
  for (int i = 0; i < points.length; i++) {
    final point = points[i];
    final gridX = (point.x / gridSize).floor().clamp(0, gridWidth - 1);
    final gridY = (point.y / gridSize).floor().clamp(0, gridHeight - 1);
    grid[gridY][gridX].add(i);
  }

  debugPrint(
    '⚡ [PERF] Spatial grid created: ${gridWidth}x${gridHeight} cells, grid size: $gridSize',
  );

  // Check for clustering within each cell and neighboring cells
  for (int gridY = 0; gridY < gridHeight; gridY++) {
    for (int gridX = 0; gridX < gridWidth; gridX++) {
      final cellPoints = grid[gridY][gridX];
      if (cellPoints.isEmpty) continue;

      // Check against points in current cell and neighboring cells
      final checkCells = <Set<int>>[];
      checkCells.add(cellPoints);

      // Add neighboring cells
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = gridX + dx;
          final ny = gridY + dy;
          if (nx >= 0 && nx < gridWidth && ny >= 0 && ny < gridHeight) {
            checkCells.add(grid[ny][nx]);
          }
        }
      }

      // Check each point in current cell against all points in check cells
      for (final i in cellPoints) {
        if (toRemove.contains(i)) continue;

        for (final checkCell in checkCells) {
          for (final j in checkCell) {
            if (i >= j || toRemove.contains(j))
              continue; // Avoid double-checking

            final dx = points[i].x - points[j].x;
            final dy = points[i].y - points[j].y;
            final distanceSquared = dx * dx + dy * dy;

            if (distanceSquared < minDistanceSquared) {
              // Keep the point with higher quality (priority * intensity)
              final qualityI = points[i].priority * points[i].intensity;
              final qualityJ = points[j].priority * points[j].intensity;

              if (qualityJ <= qualityI) {
                toRemove.add(j);
              } else {
                toRemove.add(i);
                break; // Current point is being removed, move to next
              }
            }
          }
        }
      }
    }
  }

  // Remove clustered points (in reverse order to maintain indices)
  if (toRemove.isNotEmpty) {
    toRemove.sort((a, b) => b.compareTo(a));
    for (final index in toRemove) {
      if (index < points.length) {
        points.removeAt(index);
      }
    }
  }

  debugPrint(
    '🔧 [DEBUG] Spatial constraints applied: ${toRemove.length} clustered points removed, ${points.length} remaining',
  );
}

/// Generate constellation lines from line segments
List<_ConstellationLine> _generateLinesFromSegments(
  List<_LineSegment> segments,
  List<_FeaturePoint> points,
  ProcessingParameters parameters,
) {
  final lines = <_ConstellationLine>[];

  // Step 1: Create intra-segment lines (within each segment)
  _generateIntraSegmentLines(segments, points, lines, parameters);

  // Step 2: Create inter-segment connections (between nearby segments)
  _generateInterSegmentLines(segments, points, lines, parameters);

  // Step 3: Filter and optimize lines
  _filterAndOptimizeLines(lines, points, parameters);

  debugPrint(
    '🔗 [DEBUG] Generated ${lines.length} optimized constellation lines from ${segments.length} segments',
  );
  return lines;
}

/// Generate lines within individual segments
void _generateIntraSegmentLines(
  List<_LineSegment> segments,
  List<_FeaturePoint> points,
  List<_ConstellationLine> lines,
  ProcessingParameters parameters,
) {
  for (final segment in segments) {
    final segmentPoints = <int>[];

    // Find points that belong to this segment
    for (int i = 0; i < points.length; i++) {
      if (segment.containsPoint(points[i].x.round(), points[i].y.round())) {
        segmentPoints.add(i);
      }
    }

    if (segmentPoints.length < 2) continue;

    // Sort points along the segment
    segmentPoints.sort((a, b) {
      final pointA = points[a];
      final pointB = points[b];
      final distA = segment.distanceToPoint(pointA.x, pointA.y);
      final distB = segment.distanceToPoint(pointB.x, pointB.y);
      return distA.compareTo(distB);
    });

    // Calculate segment curvature for line quality
    final curvatureScore = segment.curvature;

    // Create lines between consecutive points with quality-based parameters
    for (int i = 0; i < segmentPoints.length - 1; i++) {
      final startId = segmentPoints[i];
      final endId = segmentPoints[i + 1];
      final startPoint = points[startId];
      final endPoint = points[endId];

      // Calculate line quality metrics
      final distance = sqrt(
        pow(startPoint.x - endPoint.x, 2) + pow(startPoint.y - endPoint.y, 2),
      );
      final intensity = (startPoint.intensity + endPoint.intensity) / 2.0;

      // Adaptive thickness based on curvature and intensity
      final adaptiveThickness = _calculateAdaptiveLineThickness(
        parameters.lineThickness,
        curvatureScore,
        intensity,
        distance,
      );

      // Adaptive opacity based on point quality
      final adaptiveOpacity = _calculateAdaptiveLineOpacity(
        startPoint,
        endPoint,
        distance,
        parameters,
      );

      lines.add(
        _ConstellationLine(
          startPointId: startId,
          endPointId: endId,
          thickness: adaptiveThickness,
          opacity: adaptiveOpacity,
        ),
      );
    }
  }
}

/// Generate connections between nearby segments
void _generateInterSegmentLines(
  List<_LineSegment> segments,
  List<_FeaturePoint> points,
  List<_ConstellationLine> lines,
  ProcessingParameters parameters,
) {
  if (segments.length < 2) return;

  final connectionCandidates = <_ConnectionCandidate>[];

  // Find potential connections between segment endpoints
  for (int i = 0; i < segments.length; i++) {
    for (int j = i + 1; j < segments.length; j++) {
      final segmentA = segments[i];
      final segmentB = segments[j];

      if (segmentA.pixels.isEmpty || segmentB.pixels.isEmpty) continue;

      // Check distance between segment endpoints
      final endpointsA = [segmentA.pixels.first, segmentA.pixels.last];
      final endpointsB = [segmentB.pixels.first, segmentB.pixels.last];

      for (final endA in endpointsA) {
        for (final endB in endpointsB) {
          final distance = sqrt(
            pow(endA.x - endB.x, 2) + pow(endA.y - endB.y, 2),
          );

          // Only consider reasonable connection distances
          if (distance > 20 && distance < 100) {
            connectionCandidates.add(
              _ConnectionCandidate(
                segmentA: segmentA,
                segmentB: segmentB,
                pointA: endA,
                pointB: endB,
                distance: distance,
              ),
            );
          }
        }
      }
    }
  }

  // Sort by distance and create top connections
  connectionCandidates.sort((a, b) => a.distance.compareTo(b.distance));

  final maxConnections = (segments.length * 0.3).round().clamp(
    1,
    8,
  ); // 30% of segments
  final selectedConnections = connectionCandidates.take(maxConnections);

  // Convert connections to constellation lines
  for (final connection in selectedConnections) {
    // Find nearest constellation points
    final nearestPointA = _findNearestConstellationPoint(
      connection.pointA,
      points,
    );
    final nearestPointB = _findNearestConstellationPoint(
      connection.pointB,
      points,
    );

    if (nearestPointA != null &&
        nearestPointB != null &&
        nearestPointA != nearestPointB) {
      final distance = sqrt(
        pow(points[nearestPointA].x - points[nearestPointB].x, 2) +
            pow(points[nearestPointA].y - points[nearestPointB].y, 2),
      );

      // Only create line if points aren't too far apart
      if (distance < 80) {
        lines.add(
          _ConstellationLine(
            startPointId: nearestPointA,
            endPointId: nearestPointB,
            thickness:
                parameters.lineThickness * 0.7, // Thinner inter-segment lines
            opacity: 0.6, // More transparent inter-segment lines
          ),
        );
      }
    }
  }

  debugPrint(
    '🔗 [DEBUG] Added ${selectedConnections.length} inter-segment connections',
  );
}

/// Filter and optimize generated lines
void _filterAndOptimizeLines(
  List<_ConstellationLine> lines,
  List<_FeaturePoint> points,
  ProcessingParameters parameters,
) {
  if (lines.isEmpty) return;

  final filteredLines = <_ConstellationLine>[];

  // Remove duplicate lines
  final lineSet = <String>{};
  for (final line in lines) {
    final key =
        '${min(line.startPointId, line.endPointId)}_${max(line.startPointId, line.endPointId)}';
    if (!lineSet.contains(key)) {
      lineSet.add(key);
      filteredLines.add(line);
    }
  }

  // Remove overly long lines
  final maxLineLength = 100.0; // Maximum line length in pixels
  filteredLines.removeWhere((line) {
    final startPoint = points[line.startPointId];
    final endPoint = points[line.endPointId];
    final distance = sqrt(
      pow(startPoint.x - endPoint.x, 2) + pow(startPoint.y - endPoint.y, 2),
    );
    return distance > maxLineLength;
  });

  // Update the original list
  lines.clear();
  lines.addAll(filteredLines);

  debugPrint(
    '🔧 [DEBUG] Filtered lines: ${filteredLines.length} remaining (from ${lineSet.length} unique)',
  );
}

/// Calculate adaptive line thickness
double _calculateAdaptiveLineThickness(
  double baseThickness,
  double curvatureScore,
  double intensity,
  double distance,
) {
  double thickness = baseThickness;

  // Increase thickness for curved lines
  thickness += curvatureScore * 0.5;

  // Increase thickness for high-intensity points
  thickness += (intensity - 0.5) * 0.3;

  // Decrease thickness for longer lines
  final lengthFactor = max(0.5, 1.0 - (distance - 30) / 100);
  thickness *= lengthFactor;

  return thickness.clamp(0.5, 3.0);
}

/// Calculate adaptive line opacity
double _calculateAdaptiveLineOpacity(
  _FeaturePoint startPoint,
  _FeaturePoint endPoint,
  double distance,
  ProcessingParameters parameters,
) {
  double opacity = 0.9; // Base opacity

  // Higher opacity for higher priority points
  final avgPriority = (startPoint.priority + endPoint.priority) / 2.0;
  opacity += (avgPriority - 1) * 0.1;

  // Higher opacity for higher intensity points
  final avgIntensity = (startPoint.intensity + endPoint.intensity) / 2.0;
  opacity += (avgIntensity - 0.5) * 0.2;

  // Lower opacity for longer lines
  opacity *= max(0.4, 1.0 - (distance - 20) / 80);

  return opacity.clamp(0.3, 1.0);
}

/// Find nearest constellation point to a pixel location
int? _findNearestConstellationPoint(
  Point<int> pixel,
  List<_FeaturePoint> points,
) {
  if (points.isEmpty) return null;

  int nearestIndex = 0;
  double minDistance = double.infinity;

  for (int i = 0; i < points.length; i++) {
    final point = points[i];
    final distance = sqrt(
      pow(point.x - pixel.x, 2) + pow(point.y - pixel.y, 2),
    );

    if (distance < minDistance) {
      minDistance = distance;
      nearestIndex = i;
    }
  }

  return minDistance < 15
      ? nearestIndex
      : null; // Only return if reasonably close
}

/// Connection candidate between two segments
class _ConnectionCandidate {
  final _LineSegment segmentA;
  final _LineSegment segmentB;
  final Point<int> pointA;
  final Point<int> pointB;
  final double distance;

  _ConnectionCandidate({
    required this.segmentA,
    required this.segmentB,
    required this.pointA,
    required this.pointB,
    required this.distance,
  });
}

/// Exception for processing operations
class ProcessingException implements Exception {
  final String message;
  const ProcessingException(this.message);

  @override
  String toString() => 'ProcessingException: $message';
}

/// Internal class representing a line segment
class _LineSegment {
  final List<Point<int>> pixels;

  _LineSegment(this.pixels);

  double get length {
    if (pixels.length < 2) return 0.0;

    double totalLength = 0.0;
    for (int i = 1; i < pixels.length; i++) {
      final dx = pixels[i].x - pixels[i - 1].x;
      final dy = pixels[i].y - pixels[i - 1].y;
      totalLength += sqrt(dx * dx + dy * dy);
    }
    return totalLength;
  }

  /// Calculate curvature of the line segment
  double get curvature {
    if (pixels.length < 3) return 0.0;

    double totalAngleChange = 0.0;
    int validPoints = 0;

    for (int i = 1; i < pixels.length - 1; i++) {
      Point<int> p1 = pixels[i - 1];
      Point<int> p2 = pixels[i];
      Point<int> p3 = pixels[i + 1];

      // Calculate angle change
      double angle1 = atan2(p2.y - p1.y, p2.x - p1.x);
      double angle2 = atan2(p3.y - p2.y, p3.x - p2.x);

      double angleChange = (angle2 - angle1).abs();
      if (angleChange > pi) angleChange = 2 * pi - angleChange;

      totalAngleChange += angleChange;
      validPoints++;
    }

    if (validPoints == 0) return 0.0;

    // Return normalized curvature (0.0-1.0)
    return (totalAngleChange / validPoints).clamp(0.0, 1.0);
  }

  Point<double> getPointAt(double t) {
    if (pixels.isEmpty) return Point(0.0, 0.0);
    if (pixels.length == 1)
      return Point(pixels[0].x.toDouble(), pixels[0].y.toDouble());

    final targetLength = t * length;
    double currentLength = 0.0;

    for (int i = 1; i < pixels.length; i++) {
      final dx = pixels[i].x - pixels[i - 1].x;
      final dy = pixels[i].y - pixels[i - 1].y;
      final segmentLength = sqrt(dx * dx + dy * dy);

      if (currentLength + segmentLength >= targetLength) {
        final remainingLength = targetLength - currentLength;
        final ratio = remainingLength / segmentLength;
        final x = pixels[i - 1].x + dx * ratio;
        final y = pixels[i - 1].y + dy * ratio;
        return Point(x, y);
      }

      currentLength += segmentLength;
    }

    // Return last point if t = 1.0
    return Point(pixels.last.x.toDouble(), pixels.last.y.toDouble());
  }

  bool containsPoint(int x, int y) {
    return pixels.any((pixel) => pixel.x == x && pixel.y == y);
  }

  double distanceToPoint(double x, double y) {
    double minDistance = double.infinity;

    for (final pixel in pixels) {
      final dx = pixel.x - x;
      final dy = pixel.y - y;
      final distance = sqrt(dx * dx + dy * dy);
      minDistance = min(minDistance, distance);
    }

    return minDistance;
  }
}

/// Internal class for feature points
class _FeaturePoint {
  final double x;
  final double y;
  final double intensity;
  final int priority;
  final int id;

  _FeaturePoint({
    required this.x,
    required this.y,
    required this.intensity,
    required this.priority,
    this.id = 0,
  });
}

/// Internal class for constellation lines
class _ConstellationLine {
  final int startPointId;
  final int endPointId;
  final double thickness;
  final double opacity;

  _ConstellationLine({
    required this.startPointId,
    required this.endPointId,
    required this.thickness,
    required this.opacity,
  });
}

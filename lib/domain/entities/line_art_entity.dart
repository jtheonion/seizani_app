import 'dart:typed_data';

/// Represents a line art image created from processing an original image
class LineArtEntity {
  final String id;
  final String originalImageId;
  final Uint8List lineArtImageBytes;
  final int width;
  final int height;
  final DateTime createdAt;
  final LineArtMetadata metadata;

  const LineArtEntity({
    required this.id,
    required this.originalImageId,
    required this.lineArtImageBytes,
    required this.width,
    required this.height,
    required this.createdAt,
    required this.metadata,
  });

  LineArtEntity copyWith({
    String? id,
    String? originalImageId,
    Uint8List? lineArtImageBytes,
    int? width,
    int? height,
    DateTime? createdAt,
    LineArtMetadata? metadata,
  }) {
    return LineArtEntity(
      id: id ?? this.id,
      originalImageId: originalImageId ?? this.originalImageId,
      lineArtImageBytes: lineArtImageBytes ?? this.lineArtImageBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LineArtEntity &&
        other.id == id &&
        other.originalImageId == originalImageId &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        originalImageId.hashCode ^
        width.hashCode ^
        height.hashCode;
  }

  @override
  String toString() {
    return 'LineArtEntity(id: $id, originalImageId: $originalImageId, size: ${width}x$height)';
  }
}

/// Metadata about the line art processing operation
class LineArtMetadata {
  final Duration processingTime;
  final LineArtAlgorithm algorithm;
  final double edgeStrength; // 0.0 - 1.0, strength of edge detection
  final double contrastLevel; // 0.0 - 1.0, contrast enhancement level
  final String algorithmVersion;
  final Map<String, dynamic> parameters;

  const LineArtMetadata({
    required this.processingTime,
    required this.algorithm,
    required this.edgeStrength,
    required this.contrastLevel,
    required this.algorithmVersion,
    this.parameters = const {},
  });

  LineArtMetadata copyWith({
    Duration? processingTime,
    LineArtAlgorithm? algorithm,
    double? edgeStrength,
    double? contrastLevel,
    String? algorithmVersion,
    Map<String, dynamic>? parameters,
  }) {
    return LineArtMetadata(
      processingTime: processingTime ?? this.processingTime,
      algorithm: algorithm ?? this.algorithm,
      edgeStrength: edgeStrength ?? this.edgeStrength,
      contrastLevel: contrastLevel ?? this.contrastLevel,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      parameters: parameters ?? this.parameters,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'processingTime': processingTime.inMilliseconds,
      'algorithm': algorithm.name,
      'edgeStrength': edgeStrength,
      'contrastLevel': contrastLevel,
      'algorithmVersion': algorithmVersion,
      'parameters': parameters,
    };
  }

  factory LineArtMetadata.fromJson(Map<String, dynamic> json) {
    return LineArtMetadata(
      processingTime: Duration(
        milliseconds: (json['processingTime'] as num?)?.toInt() ?? 0,
      ),
      algorithm: LineArtAlgorithm.fromName(json['algorithm'] as String?),
      edgeStrength: (json['edgeStrength'] as num?)?.toDouble() ?? 0.3,
      contrastLevel: (json['contrastLevel'] as num?)?.toDouble() ?? 1.2,
      algorithmVersion: json['algorithmVersion'] as String? ?? 'unknown',
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
    );
  }
}

/// Available line art processing algorithms
enum LineArtAlgorithm {
  sobel('Sobel Edge Detection'),
  canny('Canny Edge Detection'),
  xdog('Extended Difference of Gaussians'),
  pencilSketch('Pencil Sketch Effect'),
  adaptiveEdge('Adaptive Edge Detection'),
  dexined('DexiNed線画');

  const LineArtAlgorithm(this.displayName);

  final String displayName;

  static LineArtAlgorithm fromName(String? name) {
    return LineArtAlgorithm.values.firstWhere(
      (algorithm) => algorithm.name == name,
      orElse: () => LineArtAlgorithm.sobel,
    );
  }
}

/// Parameters for line art processing
class LineArtParameters {
  static const double dexinedDefaultPercentile = 92.0;
  static const int dexinedDefaultMinThreshold = 24;

  static const LineArtParameters dexinedDefaults = LineArtParameters(
    algorithm: LineArtAlgorithm.dexined,
    edgeThreshold: 0.3,
    lineThickness: 1.0,
    contrast: 1.0,
    invertColors: false,
    smoothLines: false,
    dexinedPercentile: dexinedDefaultPercentile,
    dexinedMinThreshold: dexinedDefaultMinThreshold,
  );

  final LineArtAlgorithm algorithm;
  final double edgeThreshold; // 0.1 - 1.0, threshold for edge detection
  final double lineThickness; // 0.5 - 3.0, thickness of output lines
  final double contrast; // 0.5 - 2.0, contrast enhancement factor
  final bool invertColors; // whether to invert black/white
  final bool smoothLines; // apply smoothing to reduce noise

  // XDoG specific parameters
  final double sigma1; // 0.5 - 2.0, first Gaussian sigma
  final double sigma2; // 1.0 - 4.0, second Gaussian sigma (should be > sigma1)
  final double tau; // 0.9 - 0.99, threshold parameter
  final double phi; // 1.0 - 10.0, sharpening factor
  final double epsilon; // -1.0 - 1.0, offset parameter

  // DexiNed specific post-processing parameters
  final double dexinedPercentile; // 85.0 - 98.0, higher keeps fewer lines
  final int dexinedMinThreshold; // 0 - 80, suppresses faint edge noise

  const LineArtParameters({
    this.algorithm = LineArtAlgorithm.sobel,
    this.edgeThreshold = 0.3,
    this.lineThickness = 1.0,
    this.contrast = 1.2,
    this.invertColors = false,
    this.smoothLines = true,
    // XDoG parameters with sensible defaults
    this.sigma1 = 0.5,
    this.sigma2 = 0.8,
    this.tau = 0.95,
    this.phi = 2.0,
    this.epsilon = 0.1,
    this.dexinedPercentile = dexinedDefaultPercentile,
    this.dexinedMinThreshold = dexinedDefaultMinThreshold,
  });

  LineArtParameters copyWith({
    LineArtAlgorithm? algorithm,
    double? edgeThreshold,
    double? lineThickness,
    double? contrast,
    bool? invertColors,
    bool? smoothLines,
    double? sigma1,
    double? sigma2,
    double? tau,
    double? phi,
    double? epsilon,
    double? dexinedPercentile,
    int? dexinedMinThreshold,
  }) {
    return LineArtParameters(
      algorithm: algorithm ?? this.algorithm,
      edgeThreshold: edgeThreshold ?? this.edgeThreshold,
      lineThickness: lineThickness ?? this.lineThickness,
      contrast: contrast ?? this.contrast,
      invertColors: invertColors ?? this.invertColors,
      smoothLines: smoothLines ?? this.smoothLines,
      sigma1: sigma1 ?? this.sigma1,
      sigma2: sigma2 ?? this.sigma2,
      tau: tau ?? this.tau,
      phi: phi ?? this.phi,
      epsilon: epsilon ?? this.epsilon,
      dexinedPercentile: dexinedPercentile ?? this.dexinedPercentile,
      dexinedMinThreshold: dexinedMinThreshold ?? this.dexinedMinThreshold,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'algorithm': algorithm.name,
      'edgeThreshold': edgeThreshold,
      'lineThickness': lineThickness,
      'contrast': contrast,
      'invertColors': invertColors,
      'smoothLines': smoothLines,
      'sigma1': sigma1,
      'sigma2': sigma2,
      'tau': tau,
      'phi': phi,
      'epsilon': epsilon,
      'dexinedPercentile': dexinedPercentile,
      'dexinedMinThreshold': dexinedMinThreshold,
    };
  }

  factory LineArtParameters.fromJson(Map<String, dynamic> json) {
    return LineArtParameters(
      algorithm: LineArtAlgorithm.fromName(json['algorithm'] as String?),
      edgeThreshold: (json['edgeThreshold'] as num?)?.toDouble() ?? 0.3,
      lineThickness: (json['lineThickness'] as num?)?.toDouble() ?? 1.0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 1.2,
      invertColors: json['invertColors'] as bool? ?? false,
      smoothLines: json['smoothLines'] as bool? ?? true,
      sigma1: (json['sigma1'] as num?)?.toDouble() ?? 0.5,
      sigma2: (json['sigma2'] as num?)?.toDouble() ?? 0.8,
      tau: (json['tau'] as num?)?.toDouble() ?? 0.95,
      phi: (json['phi'] as num?)?.toDouble() ?? 2.0,
      epsilon: (json['epsilon'] as num?)?.toDouble() ?? 0.1,
      dexinedPercentile:
          (json['dexinedPercentile'] as num?)?.toDouble() ??
          dexinedDefaultPercentile,
      dexinedMinThreshold:
          (json['dexinedMinThreshold'] as num?)?.toInt() ??
          dexinedDefaultMinThreshold,
    );
  }

  @override
  String toString() {
    return 'LineArtParameters(algorithm: $algorithm, edgeThreshold: $edgeThreshold)';
  }
}

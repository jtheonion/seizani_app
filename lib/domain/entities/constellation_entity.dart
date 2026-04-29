import 'dart:typed_data';

/// Represents a point in the constellation pattern
class ConstellationPoint {
  final double x;
  final double y;
  final double intensity; // 0.0 - 1.0, brightness of the star
  final int id;

  const ConstellationPoint({
    required this.x,
    required this.y,
    required this.intensity,
    required this.id,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConstellationPoint &&
        other.x == x &&
        other.y == y &&
        other.intensity == intensity &&
        other.id == id;
  }

  @override
  int get hashCode =>
      x.hashCode ^ y.hashCode ^ intensity.hashCode ^ id.hashCode;
}

/// Represents a line connecting two constellation points
class ConstellationLine {
  final int startPointId;
  final int endPointId;
  final double thickness; // 0.5 - 3.0, thickness of the line
  final double opacity; // 0.0 - 1.0, opacity of the line

  const ConstellationLine({
    required this.startPointId,
    required this.endPointId,
    this.thickness = 1.0,
    this.opacity = 0.8,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConstellationLine &&
        other.startPointId == startPointId &&
        other.endPointId == endPointId &&
        other.thickness == thickness &&
        other.opacity == opacity;
  }

  @override
  int get hashCode =>
      startPointId.hashCode ^
      endPointId.hashCode ^
      thickness.hashCode ^
      opacity.hashCode;
}

/// Core constellation entity representing the processed constellation pattern
class ConstellationEntity {
  final String id;
  final String originalImageId;
  final List<ConstellationPoint> points;
  final List<ConstellationLine> lines;
  final Uint8List renderedImageBytes;
  final int width;
  final int height;
  final DateTime createdAt;
  final ProcessingMetadata metadata;

  const ConstellationEntity({
    required this.id,
    required this.originalImageId,
    required this.points,
    required this.lines,
    required this.renderedImageBytes,
    required this.width,
    required this.height,
    required this.createdAt,
    required this.metadata,
  });

  ConstellationEntity copyWith({
    String? id,
    String? originalImageId,
    List<ConstellationPoint>? points,
    List<ConstellationLine>? lines,
    Uint8List? renderedImageBytes,
    int? width,
    int? height,
    DateTime? createdAt,
    ProcessingMetadata? metadata,
  }) {
    return ConstellationEntity(
      id: id ?? this.id,
      originalImageId: originalImageId ?? this.originalImageId,
      points: points ?? this.points,
      lines: lines ?? this.lines,
      renderedImageBytes: renderedImageBytes ?? this.renderedImageBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConstellationEntity &&
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
    return 'ConstellationEntity(id: $id, originalImageId: $originalImageId, points: ${points.length}, lines: ${lines.length})';
  }
}

/// Metadata about the processing operation
class ProcessingMetadata {
  final Duration processingTime;
  final int edgePoints;
  final double complexity; // 0.0 - 1.0, complexity score of the image
  final String algorithmVersion;
  final Map<String, dynamic> parameters;

  const ProcessingMetadata({
    required this.processingTime,
    required this.edgePoints,
    required this.complexity,
    required this.algorithmVersion,
    this.parameters = const {},
  });

  ProcessingMetadata copyWith({
    Duration? processingTime,
    int? edgePoints,
    double? complexity,
    String? algorithmVersion,
    Map<String, dynamic>? parameters,
  }) {
    return ProcessingMetadata(
      processingTime: processingTime ?? this.processingTime,
      edgePoints: edgePoints ?? this.edgePoints,
      complexity: complexity ?? this.complexity,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      parameters: parameters ?? this.parameters,
    );
  }
}

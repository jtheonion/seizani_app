import 'package:flutter/foundation.dart';

/// Parameters for the simple star decoration step after line art generation.
@immutable
class StarDecorationParams {
  final double lineWidthThreshold;
  final double starDensity;
  final double starMinSize;
  final double starMaxSize;
  final double starBrightness;
  final double starGlow;
  final int starColor;
  final int? seed;

  const StarDecorationParams({
    this.lineWidthThreshold = 2.0,
    this.starDensity = 1.0,
    this.starMinSize = 1.2,
    this.starMaxSize = 2.8,
    this.starBrightness = 0.9,
    this.starGlow = 0.6,
    this.starColor = 0xFFFFFFFF,
    this.seed,
  });

  StarDecorationParams copyWith({
    double? lineWidthThreshold,
    double? starDensity,
    double? starMinSize,
    double? starMaxSize,
    double? starBrightness,
    double? starGlow,
    int? starColor,
    int? seed,
  }) {
    return StarDecorationParams(
      lineWidthThreshold: lineWidthThreshold ?? this.lineWidthThreshold,
      starDensity: starDensity ?? this.starDensity,
      starMinSize: starMinSize ?? this.starMinSize,
      starMaxSize: starMaxSize ?? this.starMaxSize,
      starBrightness: starBrightness ?? this.starBrightness,
      starGlow: starGlow ?? this.starGlow,
      starColor: starColor ?? this.starColor,
      seed: seed ?? this.seed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lineWidthThreshold': lineWidthThreshold,
      'starDensity': starDensity,
      'starMinSize': starMinSize,
      'starMaxSize': starMaxSize,
      'starBrightness': starBrightness,
      'starGlow': starGlow,
      'starColor': starColor,
      'seed': seed,
    };
  }

  factory StarDecorationParams.fromJson(Map<String, dynamic> json) {
    return StarDecorationParams(
      lineWidthThreshold:
          (json['lineWidthThreshold'] as num?)?.toDouble() ?? 2.0,
      starDensity: (json['starDensity'] as num?)?.toDouble() ?? 1.0,
      starMinSize: (json['starMinSize'] as num?)?.toDouble() ?? 1.2,
      starMaxSize: (json['starMaxSize'] as num?)?.toDouble() ?? 2.8,
      starBrightness: (json['starBrightness'] as num?)?.toDouble() ?? 0.9,
      starGlow: (json['starGlow'] as num?)?.toDouble() ?? 0.6,
      starColor: (json['starColor'] as int?) ?? 0xFFFFFFFF,
      seed: (json['seed'] as num?)?.toInt(),
    );
  }
}

/// Metadata for star decoration results.
@immutable
class LineArtDecorationMetadata {
  final Duration processingTime;
  final String algorithmVersion;
  final int starCount;
  final bool maskInverted;
  final StarDecorationParams parameters;

  const LineArtDecorationMetadata({
    required this.processingTime,
    required this.algorithmVersion,
    required this.starCount,
    required this.maskInverted,
    required this.parameters,
  });

  Map<String, dynamic> toJson() {
    return {
      'processingTimeMs': processingTime.inMilliseconds,
      'algorithmVersion': algorithmVersion,
      'starCount': starCount,
      'maskInverted': maskInverted,
      'parameters': parameters.toJson(),
    };
  }

  factory LineArtDecorationMetadata.fromJson(Map<String, dynamic> json) {
    return LineArtDecorationMetadata(
      processingTime: Duration(
        milliseconds: (json['processingTimeMs'] as int?) ?? 0,
      ),
      algorithmVersion: json['algorithmVersion'] as String? ?? 'unknown',
      starCount: (json['starCount'] as num?)?.toInt() ?? 0,
      maskInverted: json['maskInverted'] as bool? ?? false,
      parameters: StarDecorationParams.fromJson(
        Map<String, dynamic>.from(json['parameters'] ?? {}),
      ),
    );
  }
}

/// Result entity for the simple line-art star decoration flow.
@immutable
class LineArtDecorationEntity {
  final String id;
  final String sourceLineArtId;
  final Uint8List decoratedImageBytes;
  final int width;
  final int height;
  final DateTime createdAt;
  final LineArtDecorationMetadata metadata;

  const LineArtDecorationEntity({
    required this.id,
    required this.sourceLineArtId,
    required this.decoratedImageBytes,
    required this.width,
    required this.height,
    required this.createdAt,
    required this.metadata,
  });

  LineArtDecorationEntity copyWith({
    String? id,
    String? sourceLineArtId,
    Uint8List? decoratedImageBytes,
    int? width,
    int? height,
    DateTime? createdAt,
    LineArtDecorationMetadata? metadata,
  }) {
    return LineArtDecorationEntity(
      id: id ?? this.id,
      sourceLineArtId: sourceLineArtId ?? this.sourceLineArtId,
      decoratedImageBytes: decoratedImageBytes ?? this.decoratedImageBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

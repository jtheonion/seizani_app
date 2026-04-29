import 'dart:typed_data';

/// Core image entity representing an image in the domain layer
class ImageEntity {
  final String id;
  final String path;
  final Uint8List? bytes;
  final int width;
  final int height;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const ImageEntity({
    required this.id,
    required this.path,
    this.bytes,
    required this.width,
    required this.height,
    required this.createdAt,
    this.metadata = const {},
  });

  ImageEntity copyWith({
    String? id,
    String? path,
    Uint8List? bytes,
    int? width,
    int? height,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return ImageEntity(
      id: id ?? this.id,
      path: path ?? this.path,
      bytes: bytes ?? this.bytes,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageEntity &&
        other.id == id &&
        other.path == path &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode {
    return id.hashCode ^ path.hashCode ^ width.hashCode ^ height.hashCode;
  }

  @override
  String toString() {
    return 'ImageEntity(id: $id, path: $path, width: $width, height: $height)';
  }
}

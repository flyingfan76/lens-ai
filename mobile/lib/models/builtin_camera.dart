/// Model representing a built-in camera (laptop/desktop camera)
/// This is used for macOS cameras accessed via platform channels
class BuiltInCamera {
  final String id;
  final String name;
  final String lensDirection; // 'front', 'back', 'external'
  final int sensorOrientation;
  
  const BuiltInCamera({
    required this.id,
    required this.name,
    required this.lensDirection,
    this.sensorOrientation = 0,
  });
  
  factory BuiltInCamera.fromMap(Map<String, dynamic> map) {
    return BuiltInCamera(
      id: map['id'] as String,
      name: map['name'] as String,
      lensDirection: map['lensDirection'] as String,
      sensorOrientation: map['sensorOrientation'] as int? ?? 0,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lensDirection': lensDirection,
      'sensorOrientation': sensorOrientation,
    };
  }
  
  @override
  String toString() {
    return 'BuiltInCamera(id: $id, name: $name, lensDirection: $lensDirection)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BuiltInCamera && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}
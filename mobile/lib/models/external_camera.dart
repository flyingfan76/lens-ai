enum CameraConnectionType {
  usb,
  wifi,
  bluetooth,
}

enum CameraBrand {
  nikon,
  canon,
  sony,
  fujifilm,
  olympus,
  panasonic,
  unknown,
}

enum CameraType {
  dslr,
  mirrorless,
  compact,
  unknown,
}

class ExternalCamera {
  final String id;
  final String name;
  final String model;
  final CameraBrand brand;
  final CameraType type;
  final CameraConnectionType connectionType;
  final String? ipAddress;
  final int? port;
  final String? usbPath;
  final bool isConnected;
  final Map<String, dynamic>? capabilities;
  final DateTime discoveredAt;

  ExternalCamera({
    required this.id,
    required this.name,
    required this.model,
    required this.brand,
    required this.type,
    required this.connectionType,
    this.ipAddress,
    this.port,
    this.usbPath,
    this.isConnected = false,
    this.capabilities,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  ExternalCamera copyWith({
    String? id,
    String? name,
    String? model,
    CameraBrand? brand,
    CameraType? type,
    CameraConnectionType? connectionType,
    String? ipAddress,
    int? port,
    String? usbPath,
    bool? isConnected,
    Map<String, dynamic>? capabilities,
    DateTime? discoveredAt,
  }) {
    return ExternalCamera(
      id: id ?? this.id,
      name: name ?? this.name,
      model: model ?? this.model,
      brand: brand ?? this.brand,
      type: type ?? this.type,
      connectionType: connectionType ?? this.connectionType,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      usbPath: usbPath ?? this.usbPath,
      isConnected: isConnected ?? this.isConnected,
      capabilities: capabilities ?? this.capabilities,
      discoveredAt: discoveredAt ?? this.discoveredAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model': model,
      'brand': brand.name,
      'type': type.name,
      'connectionType': connectionType.name,
      'ipAddress': ipAddress,
      'port': port,
      'usbPath': usbPath,
      'isConnected': isConnected,
      'capabilities': capabilities,
      'discoveredAt': discoveredAt.toIso8601String(),
    };
  }

  factory ExternalCamera.fromJson(Map<String, dynamic> json) {
    return ExternalCamera(
      id: json['id'],
      name: json['name'],
      model: json['model'],
      brand: CameraBrand.values.firstWhere(
        (e) => e.name == json['brand'],
        orElse: () => CameraBrand.unknown,
      ),
      type: CameraType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CameraType.unknown,
      ),
      connectionType: CameraConnectionType.values.firstWhere(
        (e) => e.name == json['connectionType'],
        orElse: () => CameraConnectionType.wifi,
      ),
      ipAddress: json['ipAddress'],
      port: json['port'],
      usbPath: json['usbPath'],
      isConnected: json['isConnected'] ?? false,
      capabilities: json['capabilities'],
      discoveredAt: DateTime.parse(json['discoveredAt']),
    );
  }

  @override
  String toString() {
    return 'ExternalCamera(name: $name, model: $model, brand: ${brand.name}, type: ${connectionType.name}, connected: $isConnected)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExternalCamera && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class CameraCapabilities {
  final bool supportsLiveView;
  final bool supportsRemoteCapture;
  final bool supportsSettingsControl;
  final bool supportsFocusControl;
  final bool supportsZoomControl;
  final List<String> supportedImageFormats;
  final List<String> supportedVideoFormats;
  final Map<String, List<dynamic>> availableSettings;

  CameraCapabilities({
    this.supportsLiveView = false,
    this.supportsRemoteCapture = false,
    this.supportsSettingsControl = false,
    this.supportsFocusControl = false,
    this.supportsZoomControl = false,
    this.supportedImageFormats = const [],
    this.supportedVideoFormats = const [],
    this.availableSettings = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'supportsLiveView': supportsLiveView,
      'supportsRemoteCapture': supportsRemoteCapture,
      'supportsSettingsControl': supportsSettingsControl,
      'supportsFocusControl': supportsFocusControl,
      'supportsZoomControl': supportsZoomControl,
      'supportedImageFormats': supportedImageFormats,
      'supportedVideoFormats': supportedVideoFormats,
      'availableSettings': availableSettings,
    };
  }

  factory CameraCapabilities.fromJson(Map<String, dynamic> json) {
    return CameraCapabilities(
      supportsLiveView: json['supportsLiveView'] ?? false,
      supportsRemoteCapture: json['supportsRemoteCapture'] ?? false,
      supportsSettingsControl: json['supportsSettingsControl'] ?? false,
      supportsFocusControl: json['supportsFocusControl'] ?? false,
      supportsZoomControl: json['supportsZoomControl'] ?? false,
      supportedImageFormats: List<String>.from(json['supportedImageFormats'] ?? []),
      supportedVideoFormats: List<String>.from(json['supportedVideoFormats'] ?? []),
      availableSettings: Map<String, List<dynamic>>.from(json['availableSettings'] ?? {}),
    );
  }
}
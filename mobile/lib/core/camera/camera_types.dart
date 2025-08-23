/// Camera type definitions for the unified camera system
library;

/// Type of camera hardware
enum CameraType {
  dslr('DSLR'),
  mirrorless('Mirrorless'),
  compact('Compact'),
  builtInMobile('Built-in Mobile'),
  builtInDesktop('Built-in Desktop'),
  webcam('Webcam'),
  unknown('Unknown');
  
  const CameraType(this.displayName);
  final String displayName;
}

/// Camera manufacturer/brand
enum CameraBrand {
  nikon('Nikon'),
  canon('Canon'),
  sony('Sony'),
  fujifilm('Fujifilm'),
  olympus('Olympus'),
  panasonic('Panasonic'),
  apple('Apple'),
  logitech('Logitech'),
  microsoft('Microsoft'),
  unknown('Unknown');
  
  const CameraBrand(this.displayName);
  final String displayName;
}

/// Platform the camera operates on
enum CameraPlatform {
  ios('iOS'),
  android('Android'),
  macOS('macOS'),
  windows('Windows'),
  linux('Linux'),
  external('External'); // USB/WiFi connected external cameras
  
  const CameraPlatform(this.displayName);
  final String displayName;
}

/// Connection type for cameras
enum CameraConnectionType {
  usb('USB'),
  wifi('WiFi'),
  bluetooth('Bluetooth'),
  builtin('Built-in'),
  unknown('Unknown');
  
  const CameraConnectionType(this.displayName);
  final String displayName;
}

/// Camera lens direction (for built-in cameras)
enum CameraLensDirection {
  front('Front'),
  back('Back'),
  external('External'),
  unknown('Unknown');
  
  const CameraLensDirection(this.displayName);
  final String displayName;
}


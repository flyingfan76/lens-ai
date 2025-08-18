import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udp/udp.dart';
import '../models/external_camera.dart';
import 'native_system_service.dart';
import 'nikon_sdk_service.dart';
import 'libgphoto2_service.dart';

class ExternalCameraService {
  static final ExternalCameraService _instance = ExternalCameraService._internal();
  factory ExternalCameraService() => _instance;
  ExternalCameraService._internal();

  final StreamController<List<ExternalCamera>> _cameraStreamController = 
      StreamController<List<ExternalCamera>>.broadcast();
  
  final List<ExternalCamera> _discoveredCameras = [];
  Timer? _discoveryTimer;
  bool _isScanning = false;
  bool _hasInitialScan = false;
  
  // Persistence constants
  static const String _connectedCameraKey = 'connected_camera';
  static const String _discoveredCamerasKey = 'discovered_cameras';

  Stream<List<ExternalCamera>> get cameraStream => _cameraStreamController.stream;
  List<ExternalCamera> get discoveredCameras => List.unmodifiable(_discoveredCameras);

  // USB Vendor ID to Brand mapping (from POC implementation)
  static const Map<String, CameraBrand> usbVendorIds = {
    '04a9': CameraBrand.canon,
    '04b0': CameraBrand.nikon,
    '054c': CameraBrand.sony,
    '04cb': CameraBrand.fujifilm,
    '07b4': CameraBrand.olympus,
    '04da': CameraBrand.panasonic,
  };
  
  // Camera identification patterns
  static const Map<String, CameraBrand> brandPatterns = {
    'nikon': CameraBrand.nikon,
    'canon': CameraBrand.canon,
    'sony': CameraBrand.sony,
    'fujifilm': CameraBrand.fujifilm,
    'fuji': CameraBrand.fujifilm,
    'olympus': CameraBrand.olympus,
    'panasonic': CameraBrand.panasonic,
  };

  static const Map<String, CameraType> typePatterns = {
    'd90': CameraType.dslr,
    'd850': CameraType.dslr,
    'd780': CameraType.dslr,
    'd500': CameraType.dslr,
    'd7500': CameraType.dslr,
    'eos': CameraType.dslr,
    'eos r': CameraType.mirrorless,
    'α': CameraType.mirrorless,
    'alpha': CameraType.mirrorless,
    'a7': CameraType.mirrorless,
    'x-t': CameraType.mirrorless,
    'x-h': CameraType.mirrorless,
    'om-d': CameraType.mirrorless,
    'powershot': CameraType.compact,
  };
  
  // Model specific information (adapted from POC)
  static const Map<String, Map<String, dynamic>> modelDatabase = {
    'd90': {
      'fullName': 'Nikon D90',
      'brand': CameraBrand.nikon,
      'type': CameraType.dslr,
      'level': 'enthusiast',
      'capabilities': {
        'liveView': true,
        'remoteCapture': true,
        'settingsControl': true,
        'focusControl': true,
        'wifi': false,
        'bluetooth': false,
      }
    },
    'd850': {
      'fullName': 'Nikon D850',
      'brand': CameraBrand.nikon,
      'type': CameraType.dslr,
      'level': 'professional',
      'capabilities': {
        'liveView': true,
        'remoteCapture': true,
        'settingsControl': true,
        'focusControl': true,
        'wifi': true,
        'bluetooth': true,
      }
    },
  };

  Future<void> startDiscovery() async {
    if (_isScanning) {
      debugPrint('ExternalCameraService: Discovery already in progress');
      return;
    }
    
    debugPrint('ExternalCameraService: Starting camera discovery...');
    _isScanning = true;
    
    try {
      // Initial discovery
      await _discoverCameras();
      
      // Start continuous discovery only after first scan
      if (!_hasInitialScan) {
        _hasInitialScan = true;
        _discoveryTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
          if (!_isScanning) {
            timer.cancel();
            return;
          }
          _discoverCameras();
        });
      }
    } catch (e) {
      debugPrint('ExternalCameraService: Discovery start error: $e');
      _isScanning = false;
    }
  }

  Future<void> stopDiscovery() async {
    debugPrint('ExternalCameraService: Stopping camera discovery...');
    _isScanning = false;
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    
    // Allow restart
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _discoverCameras() async {
    if (!_isScanning) return;
    
    try {
      debugPrint('ExternalCameraService: Starting camera discovery scan...');
      final currentCameras = <ExternalCamera>[];
      
      // Discover USB cameras first (main focus for D90 support)
      final usbCameras = await _discoverUSBCameras();
      currentCameras.addAll(usbCameras);
      debugPrint('ExternalCameraService: Found ${usbCameras.length} USB cameras');
      
      // Discover WiFi cameras (secondary) - but limit to avoid timeout
      if (currentCameras.isEmpty) {
        final wifiCameras = await _discoverWiFiCameras();
        currentCameras.addAll(wifiCameras);
        debugPrint('ExternalCameraService: Found ${wifiCameras.length} WiFi cameras');
      }
      
      // Update discovered cameras list while preserving connection state
      _updateCameraListWithConnectionState(currentCameras);
      
      debugPrint('ExternalCameraService: Discovery completed. Total cameras: ${currentCameras.length}');
      
    } catch (e) {
      debugPrint('ExternalCameraService: Discovery error: $e');
    }
  }

  Future<List<ExternalCamera>> _discoverWiFiCameras() async {
    final cameras = <ExternalCamera>[];
    
    try {
      // Get current WiFi network info
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      
      if (wifiIP == null) {
        debugPrint('ExternalCameraService: No WiFi connection');
        return cameras;
      }
      
      debugPrint('ExternalCameraService: Scanning WiFi network: $wifiIP');
      
      // Get network subnet (e.g., 192.168.1.0/24)
      final subnet = _getSubnet(wifiIP);
      
      // Scan common camera ports on the network
      final futures = <Future>[];
      
      for (int i = 1; i <= 254; i++) {
        final targetIP = '$subnet.$i';
        
        // Skip own IP
        if (targetIP == wifiIP) continue;
        
        // Scan common camera service ports
        futures.add(_scanCameraServices(targetIP));
      }
      
      final results = await Future.wait(futures);
      for (final result in results) {
        if (result != null) {
          cameras.add(result as ExternalCamera);
        }
      }
      
    } catch (e) {
      debugPrint('ExternalCameraService: WiFi discovery error: $e');
    }
    
    return cameras;
  }

  String _getSubnet(String ip) {
    final parts = ip.split('.');
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  Future<ExternalCamera?> _scanCameraServices(String ip) async {
    try {
      // Common camera service ports
      const cameraPorts = [
        8080, // Common HTTP port for cameras
        80,   // Standard HTTP
        443,  // HTTPS
        8008, // Canon cameras
        8000, // Some camera services
        15740, // Nikon SnapBridge
        1900,  // UPnP discovery
      ];
      
      for (final port in cameraPorts) {
        try {
          final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 2));
          socket.destroy();
          
          // Found an open port, check if it's a camera service
          final camera = await _identifyCameraService(ip, port);
          if (camera != null) {
            debugPrint('ExternalCameraService: Found camera at $ip:$port - ${camera.name}');
            return camera;
          }
        } catch (e) {
          // Port not open, continue scanning
        }
      }
    } catch (e) {
      // IP not reachable, continue scanning
    }
    
    return null;
  }

  Future<ExternalCamera?> _identifyCameraService(String ip, int port) async {
    try {
      // Try to get camera info via HTTP
      final response = await http.get(
        Uri.parse('http://$ip:$port/'),
        headers: {'User-Agent': 'LensAI/1.0'},
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final content = response.body.toLowerCase();
        final headers = response.headers;
        
        // Identify camera by response content or headers
        final cameraInfo = _parseCameraInfo(content, headers, ip, port);
        if (cameraInfo != null) {
          return cameraInfo;
        }
      }
    } catch (e) {
      // Not a standard HTTP service, might be proprietary protocol
      debugPrint('ExternalCameraService: HTTP check failed for $ip:$port - $e');
    }
    
    // Try UPnP discovery for cameras
    return await _tryUPnPDiscovery(ip, port);
  }

  ExternalCamera? _parseCameraInfo(String content, Map<String, String> headers, String ip, int port) {
    // Check for camera-specific identifiers in content or headers
    final serverHeader = headers['server']?.toLowerCase() ?? '';
    final contentLower = content.toLowerCase();
    
    // Look for camera brand indicators
    CameraBrand brand = CameraBrand.unknown;
    CameraType type = CameraType.unknown;
    String model = 'Unknown Camera';
    
    for (final entry in brandPatterns.entries) {
      if (contentLower.contains(entry.key) || serverHeader.contains(entry.key)) {
        brand = entry.value;
        break;
      }
    }
    
    for (final entry in typePatterns.entries) {
      if (contentLower.contains(entry.key)) {
        type = entry.value;
        if (entry.key == 'd90') {
          model = 'Nikon D90';
          brand = CameraBrand.nikon;
        }
        break;
      }
    }
    
    // If we found camera indicators, create camera object
    if (brand != CameraBrand.unknown || _containsCameraKeywords(contentLower)) {
      return ExternalCamera(
        id: 'wifi_${ip}_$port',
        name: '$model (WiFi)',
        model: model,
        brand: brand,
        type: type,
        connectionType: CameraConnectionType.wifi,
        ipAddress: ip,
        port: port,
        isConnected: false,
        capabilities: {
          'supportsLiveView': true,
          'supportsRemoteCapture': true,
          'supportsSettingsControl': true,
        },
      );
    }
    
    return null;
  }

  bool _containsCameraKeywords(String content) {
    const cameraKeywords = [
      'camera', 'liveview', 'capture', 'shutter', 'iso', 'aperture',
      'exposure', 'focus', 'zoom', 'photography', 'image', 'photo'
    ];
    
    return cameraKeywords.any((keyword) => content.contains(keyword));
  }

  Future<ExternalCamera?> _tryUPnPDiscovery(String ip, int port) async {
    try {
      // Send UPnP SSDP discovery message
      final socket = await UDP.bind(Endpoint.any(port: const Port(0)));
      
      const ssdpMessage = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'ST: upnp:rootdevice\r\n'
          'MX: 3\r\n\r\n';
      
      await socket.send(
        ssdpMessage.codeUnits,
        Endpoint.unicast(InternetAddress(ip), port: Port(1900)),
      );
      
      // Listen for responses
      final completer = Completer<ExternalCamera?>();
      
      socket.asStream(timeout: const Duration(seconds: 3)).listen(
        (datagram) {
          final response = String.fromCharCodes(datagram!.data);
          final camera = _parseUPnPResponse(response, ip);
          if (camera != null && !completer.isCompleted) {
            completer.complete(camera);
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
      );
      
      Timer(const Duration(seconds: 3), () {
        socket.close();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });
      
      return await completer.future;
      
    } catch (e) {
      debugPrint('ExternalCameraService: UPnP discovery error: $e');
      return null;
    }
  }

  ExternalCamera? _parseUPnPResponse(String response, String ip) {
    // Parse UPnP response for camera device information
    final lines = response.toLowerCase().split('\n');
    
    for (final line in lines) {
      if (line.contains('camera') || line.contains('imaging')) {
        return ExternalCamera(
          id: 'upnp_$ip',
          name: 'UPnP Camera',
          model: 'Unknown UPnP Camera',
          brand: CameraBrand.unknown,
          type: CameraType.unknown,
          connectionType: CameraConnectionType.wifi,
          ipAddress: ip,
          port: 1900,
          isConnected: false,
        );
      }
    }
    
    return null;
  }

  Future<List<ExternalCamera>> _discoverUSBCameras() async {
    final cameras = <ExternalCamera>[];
    
    try {
      debugPrint('ExternalCameraService: Starting USB camera discovery...');
      
      // Platform-specific USB detection using system commands (like POC)
      if (Platform.isAndroid) {
        cameras.addAll(await _discoverAndroidUSBCameras());
      } else if (Platform.isIOS) {
        cameras.addAll(await _discoveriOSUSBCameras());
      } else if (Platform.isMacOS) {
        cameras.addAll(await _discoverMacOSUSBCameras());
      } else if (Platform.isLinux) {
        cameras.addAll(await _discoverLinuxUSBCameras());
      }
      
      debugPrint('ExternalCameraService: USB discovery found ${cameras.length} cameras');
      for (final camera in cameras) {
        debugPrint('  - ${camera.toString()}');
      }
      
    } catch (e) {
      debugPrint('ExternalCameraService: USB discovery error: $e');
    }
    
    return cameras;
  }

  Future<List<ExternalCamera>> _discoverAndroidUSBCameras() async {
    final cameras = <ExternalCamera>[];
    
    try {
      // Try to execute lsusb command on Android (requires root or specific permissions)
      final result = await _executeSystemCommand('lsusb');
      if (result != null) {
        cameras.addAll(_parseUSBDevices(result, 'android'));
      } else {
        // Fallback: check Android USB device files
        cameras.addAll(await _checkAndroidUSBDevices());
      }
      
      // Add simulation camera for testing
      if (kDebugMode) {
        cameras.add(_createSimulationCamera());
      }
      
    } catch (e) {
      debugPrint('ExternalCameraService: Android USB discovery error: $e');
    }
    
    return cameras;
  }
  
  Future<List<ExternalCamera>> _discoveriOSUSBCameras() async {
    final cameras = <ExternalCamera>[];
    
    try {
      // iOS has strict MFi requirements, but we can try USB-C cameras on newer devices
      // This would require platform-specific implementation via method channels
      debugPrint('ExternalCameraService: iOS USB camera detection - MFi limitations apply');
      
      // Add simulation for testing
      if (kDebugMode) {
        cameras.add(_createSimulationCamera());
      }
      
    } catch (e) {
      debugPrint('ExternalCameraService: iOS USB discovery error: $e');
    }
    
    return cameras;
  }
  
  Future<List<ExternalCamera>> _discoverMacOSUSBCameras() async {
    final cameras = <ExternalCamera>[];
    
    try {
      // Use system_profiler command like in POC
      final result = await _executeSystemCommand('system_profiler SPUSBDataType -xml');
      if (result != null) {
        cameras.addAll(_parseMacOSUSBData(result));
      }
      
    } catch (e) {
      debugPrint('ExternalCameraService: macOS USB discovery error: $e');
    }
    
    return cameras;
  }
  
  Future<List<ExternalCamera>> _discoverLinuxUSBCameras() async {
    final cameras = <ExternalCamera>[];
    
    try {
      // Use lsusb command like in POC
      final result = await _executeSystemCommand('lsusb');
      if (result != null) {
        cameras.addAll(_parseUSBDevices(result, 'linux'));
      }
      
    } catch (e) {
      debugPrint('ExternalCameraService: Linux USB discovery error: $e');
    }
    
    return cameras;
  }

  void _updateCameraList(List<ExternalCamera> newCameras) {
    // Remove cameras that are no longer available
    _discoveredCameras.removeWhere((existing) => 
      !newCameras.any((newCamera) => newCamera.id == existing.id));
    
    // Add or update cameras
    for (final newCamera in newCameras) {
      final existingIndex = _discoveredCameras.indexWhere((c) => c.id == newCamera.id);
      if (existingIndex >= 0) {
        // Update existing camera
        _discoveredCameras[existingIndex] = newCamera;
      } else {
        // Add new camera
        _discoveredCameras.add(newCamera);
      }
    }
    
    // Save discovered cameras
    _saveDiscoveredCameras(_discoveredCameras);
    
    // Notify listeners
    if (!_cameraStreamController.isClosed) {
      _cameraStreamController.add(List.unmodifiable(_discoveredCameras));
    }
    
    debugPrint('ExternalCameraService: Updated camera list: ${_discoveredCameras.length} cameras');
    for (final camera in _discoveredCameras) {
      debugPrint('  - ${camera.toString()}');
    }
  }
  
  void _updateCameraListWithConnectionState(List<ExternalCamera> newCameras) {
    // Preserve connection state when updating camera list
    final updatedCameras = <ExternalCamera>[];
    
    for (final newCamera in newCameras) {
      final existingIndex = _discoveredCameras.indexWhere((existing) => existing.id == newCamera.id);
      final existingCamera = existingIndex >= 0 ? _discoveredCameras[existingIndex] : null;
      
      // If this camera was previously connected, preserve that state
      if (existingCamera != null && existingCamera.isConnected) {
        updatedCameras.add(newCamera.copyWith(isConnected: true));
        debugPrint('ExternalCameraService: Preserved connection state for ${newCamera.name}');
      } else {
        updatedCameras.add(newCamera);
      }
    }
    
    // Update the camera list
    _updateCameraList(updatedCameras);
  }

  Future<bool> connectToCamera(String cameraId) async {
    try {
      final camera = _discoveredCameras.firstWhere((c) => c.id == cameraId);
      
      debugPrint('ExternalCameraService: Attempting to connect to camera: ${camera.name} (${camera.model})');
      
      // Check if camera is already connected
      if (camera.isConnected) {
        debugPrint('ExternalCameraService: Camera ${camera.name} is already connected');
        return true;
      }
      
      if (camera.model == 'Unknown Model' && !camera.id.contains('simulation')) {
        debugPrint('ExternalCameraService: Cannot connect to unknown camera model');
        return false;
      }
      
      // Allow connection for properly identified cameras
      if (camera.model != 'Unknown Model') {
        debugPrint('ExternalCameraService: Camera model identified as: ${camera.model}');
      }
    } catch (e) {
      debugPrint('ExternalCameraService: Camera not found in discovered list: $cameraId');
      return false;
    }
    
    final camera = _discoveredCameras.firstWhere((c) => c.id == cameraId);
    
    try {
      debugPrint('ExternalCameraService: Connecting to camera: ${camera.name}');
      
      // Connection logic based on camera type
      bool connected = false;
      
      switch (camera.connectionType) {
        case CameraConnectionType.wifi:
          connected = await _connectWiFiCamera(camera);
          break;
        case CameraConnectionType.usb:
          connected = await _connectUSBCamera(camera);
          break;
        case CameraConnectionType.bluetooth:
          connected = await _connectBluetoothCamera(camera);
          break;
      }
      
      if (connected) {
        // Update camera connection status
        final updatedCamera = camera.copyWith(isConnected: true);
        debugPrint('ExternalCameraService: Updating camera ${camera.name} connection status to connected');
        debugPrint('ExternalCameraService: Original camera isConnected: ${camera.isConnected}');
        debugPrint('ExternalCameraService: Updated camera isConnected: ${updatedCamera.isConnected}');
        
        final index = _discoveredCameras.indexWhere((c) => c.id == cameraId);
        if (index >= 0) {
          _discoveredCameras[index] = updatedCamera;
          debugPrint('ExternalCameraService: Updated camera in list at index $index');
          
          // Save connected camera state
          await _saveConnectedCamera(updatedCamera);
          await _saveDiscoveredCameras(_discoveredCameras);
          
          try {
            _cameraStreamController.add(List.unmodifiable(_discoveredCameras));
            debugPrint('ExternalCameraService: Notified stream listeners of connection status change');
          } catch (e) {
            debugPrint('ExternalCameraService: Stream controller error: $e');
            // Stream is closed, but camera is still updated in the list
            // UnifiedCameraProvider should still work with the updated camera state
          }
        } else {
          debugPrint('ExternalCameraService: Camera not found in discovered list for status update');
        }
        
        debugPrint('ExternalCameraService: Successfully connected to ${camera.name}');
      }
      
      return connected;
    } catch (e) {
      debugPrint('ExternalCameraService: Connection error: $e');
      return false;
    }
  }

  Future<bool> _connectWiFiCamera(ExternalCamera camera) async {
    try {
      debugPrint('ExternalCameraService: Attempting WiFi connection to ${camera.name}');
      
      if (camera.ipAddress == null) {
        debugPrint('ExternalCameraService: No IP address for WiFi camera');
        return false;
      }
      
      // Test connectivity by attempting HTTP connection
      final response = await http.get(
        Uri.parse('http://${camera.ipAddress}:${camera.port ?? 8080}/'),
        headers: {'User-Agent': 'LensAI/1.0'},
      ).timeout(const Duration(seconds: 5));
      
      final success = response.statusCode == 200;
      debugPrint('ExternalCameraService: WiFi connection ${success ? "successful" : "failed"} (${response.statusCode})');
      return success;
      
    } catch (e) {
      debugPrint('ExternalCameraService: WiFi connection error: $e');
      return false;
    }
  }

  Future<bool> _connectUSBCamera(ExternalCamera camera) async {
    try {
      debugPrint('ExternalCameraService: Attempting USB connection to ${camera.name}');
      
      // For simulation cameras, always succeed
      if (camera.id.contains('simulation')) {
        debugPrint('ExternalCameraService: Simulation camera connected successfully');
        return true;
      }
      
      // For real cameras, we need to implement platform-specific connection
      // For now, simulate a successful connection if the camera was detected
      if (camera.brand != CameraBrand.unknown || camera.model != 'Unknown Model') {
        debugPrint('ExternalCameraService: USB camera connected (identified model)');
        return true;
      }
      
      debugPrint('ExternalCameraService: USB connection failed - unknown camera model');
      return false;
      
    } catch (e) {
      debugPrint('ExternalCameraService: USB connection error: $e');
      return false;
    }
  }

  Future<bool> _connectBluetoothCamera(ExternalCamera camera) async {
    try {
      debugPrint('ExternalCameraService: Attempting Bluetooth connection to ${camera.name}');
      // Bluetooth implementation would go here
      // For now, return false as it's not implemented
      return false;
    } catch (e) {
      debugPrint('ExternalCameraService: Bluetooth connection error: $e');
      return false;
    }
  }

  Future<void> disconnectFromCamera(String cameraId) async {
    final camera = _discoveredCameras.firstWhere((c) => c.id == cameraId);
    
    try {
      debugPrint('ExternalCameraService: Disconnecting from camera: ${camera.name}');
      
      // Disconnect logic based on camera type
      // ... implementation ...
      
      // Update camera connection status
      final updatedCamera = camera.copyWith(isConnected: false);
      final index = _discoveredCameras.indexWhere((c) => c.id == cameraId);
      if (index >= 0) {
        _discoveredCameras[index] = updatedCamera;
        
        // Clear connected camera state
        await _saveConnectedCamera(null);
        await _saveDiscoveredCameras(_discoveredCameras);
        
        if (!_cameraStreamController.isClosed) {
          _cameraStreamController.add(List.unmodifiable(_discoveredCameras));
        }
      }
      
      debugPrint('ExternalCameraService: Disconnected from ${camera.name}');
    } catch (e) {
      debugPrint('ExternalCameraService: Disconnection error: $e');
    }
  }

  // System command execution (adapted from POC)
  Future<String?> _executeSystemCommand(String command) async {
    try {
      return await NativeSystemService.executeCommand(command, timeoutMs: 5000);
    } catch (e) {
      debugPrint('ExternalCameraService: System command error: $e');
      return null;
    }
  }
  
  
  // Parse USB device information (adapted from POC logic)
  List<ExternalCamera> _parseUSBDevices(String usbData, String platform) {
    final cameras = <ExternalCamera>[];
    final lines = usbData.split('\n');
    
    for (final line in lines) {
      try {
        if (platform == 'linux') {
          // Parse lsusb output: "Bus 001 Device 002: ID 04b0:0421 Nikon Corp. NIKON D90"
          final match = RegExp(r'ID ([0-9a-f]{4}):([0-9a-f]{4})\s+(.+)').firstMatch(line);
          if (match != null) {
            final vendorId = match.group(1)!.toLowerCase();
            final productId = match.group(2)!.toLowerCase();
            final deviceName = match.group(3)!;
            
            final camera = _createCameraFromUSBInfo(vendorId, productId, deviceName, platform);
            if (camera != null) {
              cameras.add(camera);
            }
          }
        }
      } catch (e) {
        debugPrint('ExternalCameraService: USB parsing error: $e');
      }
    }
    
    return cameras;
  }
  
  List<ExternalCamera> _parseMacOSUSBData(String xmlData) {
    final cameras = <ExternalCamera>[];
    
    try {
      debugPrint('ExternalCameraService: Parsing macOS USB XML data...');
      
      // Split into device blocks - each device is in a <dict> block
      final deviceBlocks = xmlData.split('<dict>').where((block) => 
        block.contains('vendor_id') && block.contains('product_id')
      ).toList();
      
      debugPrint('ExternalCameraService: Found ${deviceBlocks.length} USB device blocks');
      
      for (final block in deviceBlocks) {
        try {
          // Extract vendor_id
          final vendorMatch = RegExp(r'<key>vendor_id</key>\s*<string>0x([0-9a-f]{4})', caseSensitive: false)
              .firstMatch(block);
          
          // Extract product_id  
          final productMatch = RegExp(r'<key>product_id</key>\s*<string>0x([0-9a-f]{4})', caseSensitive: false)
              .firstMatch(block);
          
          // Extract device name (_name key)
          final nameMatch = RegExp(r'<key>_name</key>\s*<string>([^<]+)</string>', caseSensitive: false)
              .firstMatch(block);
          
          // Extract manufacturer
          final manufacturerMatch = RegExp(r'<key>manufacturer</key>\s*<string>([^<]+)</string>', caseSensitive: false)
              .firstMatch(block);
          
          if (vendorMatch != null && productMatch != null) {
            final vendorId = vendorMatch.group(1)!.toLowerCase();
            final productId = productMatch.group(1)!.toLowerCase();
            final deviceName = nameMatch?.group(1)?.trim() ?? 'Unknown Device';
            final manufacturer = manufacturerMatch?.group(1)?.trim() ?? '';
            
            debugPrint('ExternalCameraService: Found USB device - VendorID: $vendorId, ProductID: $productId, Name: $deviceName, Manufacturer: $manufacturer');
            
            // Check if this is a known camera vendor
            if (usbVendorIds.containsKey(vendorId)) {
              final camera = _createCameraFromUSBInfo(vendorId, productId, deviceName, 'macos');
              if (camera != null) {
                debugPrint('ExternalCameraService: Created camera: ${camera.name}');
                cameras.add(camera);
              }
            }
          }
        } catch (e) {
          debugPrint('ExternalCameraService: Error parsing device block: $e');
        }
      }
    } catch (e) {
      debugPrint('ExternalCameraService: macOS XML parsing error: $e');
    }
    
    return cameras;
  }
  
  ExternalCamera? _createCameraFromUSBInfo(String vendorId, String productId, String deviceName, String platform) {
    final brand = usbVendorIds[vendorId];
    if (brand == null) return null;
    
    // Determine model and type from device name
    final deviceLower = deviceName.toLowerCase();
    String model = 'Unknown Model';
    CameraType type = CameraType.unknown;
    Map<String, dynamic> capabilities = {};
    
    // Check for specific models
    debugPrint('ExternalCameraService: Checking device name "$deviceName" (lower: "$deviceLower") against model database');
    
    for (final entry in modelDatabase.entries) {
      debugPrint('ExternalCameraService: Checking if "$deviceLower" contains "${entry.key}"');
      if (deviceLower.contains(entry.key)) {
        final modelInfo = entry.value;
        model = modelInfo['fullName'] as String;
        type = modelInfo['type'] as CameraType;
        capabilities = Map<String, dynamic>.from(modelInfo['capabilities'] as Map);
        debugPrint('ExternalCameraService: Found model match: $model');
        break;
      }
    }
    
    // Special case handling for common patterns
    if (model == 'Unknown Model') {
      if (deviceLower.contains('dsc d90') || deviceLower.contains('d90')) {
        model = 'Nikon D90';
        type = CameraType.dslr;
        capabilities = {
          'liveView': true,
          'remoteCapture': true,
          'settingsControl': true,
          'focusControl': true,
          'wifi': false,
          'bluetooth': false,
        };
        debugPrint('ExternalCameraService: Special case detection - D90 found');
      }
    }
    
    // Fallback type detection
    if (type == CameraType.unknown) {
      for (final entry in typePatterns.entries) {
        if (deviceLower.contains(entry.key)) {
          type = entry.value;
          break;
        }
      }
    }
    
    return ExternalCamera(
      id: 'usb_${vendorId}_${productId}',  // Consistent ID without timestamp
      name: '$model (USB)',
      model: model,
      brand: brand,
      type: type,
      connectionType: CameraConnectionType.usb,
      usbPath: '/dev/usb/${vendorId}_${productId}',
      isConnected: false,
      capabilities: capabilities.isNotEmpty ? capabilities : {
        'supportsLiveView': true,
        'supportsRemoteCapture': true,
        'supportsSettingsControl': type != CameraType.compact,
        'supportsFocusControl': true,
      },
    );
  }
  
  Future<List<ExternalCamera>> _checkAndroidUSBDevices() async {
    final cameras = <ExternalCamera>[];
    
    try {
      // Check Android USB device files
      const usbDevicePaths = [
        '/sys/bus/usb/devices',
        '/proc/bus/usb/devices',
        '/dev/bus/usb',
      ];
      
      for (final path in usbDevicePaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          // This would require platform-specific implementation
          debugPrint('ExternalCameraService: Found USB device path: $path');
        }
      }
    } catch (e) {
      debugPrint('ExternalCameraService: Android USB device check error: $e');
    }
    
    return cameras;
  }
  
  ExternalCamera _createSimulationCamera() {
    return ExternalCamera(
      id: 'simulation_d90',  // Consistent simulation ID
      name: 'Nikon D90 (Simulation)',
      model: 'Nikon D90',  // Use full model name instead of just 'D90'
      brand: CameraBrand.nikon,
      type: CameraType.dslr,
      connectionType: CameraConnectionType.usb,
      usbPath: '/dev/usb/simulation',
      isConnected: false,
      capabilities: {
        'supportsLiveView': true,
        'supportsRemoteCapture': true,
        'supportsSettingsControl': true,
        'supportsFocusControl': true,
        'supportsZoomControl': false,
        'wifi': false,
        'bluetooth': false,
      },
    );
  }
  
  // Live view streaming functionality with frame rate control
  StreamController<Uint8List>? _liveViewStreamController;
  StreamController<Uint8List>? _bufferedLiveViewController;
  Timer? _liveViewTimer;
  bool _isLiveViewActive = false;
  String? _activeLiveViewCameraId;
  
  // Frame rate control for smoother streaming
  static const int _targetFPS = 15;  // Limit to 15 FPS for smoother experience  
  static const Duration _frameInterval = Duration(milliseconds: 66); // ~15 FPS
  DateTime? _lastFrameTime;
  Uint8List? _lastValidFrame;
  
  // Real camera services
  final NikonSDKService _nikonSDK = NikonSDKService();
  final LibGPhoto2Service _libgphoto2 = LibGPhoto2Service();

  Stream<Uint8List>? get liveViewStream => _bufferedLiveViewController?.stream;
  bool get isLiveViewActive => _isLiveViewActive;

  /// Start live view streaming from the specified camera
  Future<bool> startLiveView(String cameraId) async {
    try {
      debugPrint('🚨 LIVE VIEW BUTTON CLICKED! CameraId: $cameraId');
      final camera = _discoveredCameras.firstWhere((c) => c.id == cameraId && c.isConnected);
      
      debugPrint('🚨 ExternalCameraService: Starting live view for ${camera.name}');
      debugPrint('🚨 Camera details: ${camera.toString()}');
      
      // Stop any existing live view
      if (_isLiveViewActive) {
        await stopLiveView();
      }
      
      // Create both raw and buffered stream controllers
      _liveViewStreamController = StreamController<Uint8List>.broadcast();
      _bufferedLiveViewController = StreamController<Uint8List>.broadcast();
      _activeLiveViewCameraId = cameraId;
      _isLiveViewActive = true;
      _lastFrameTime = null;
      _lastValidFrame = null;
      
      // Set up frame rate limiting for buffered stream
      _liveViewStreamController!.stream.listen(_processFrameWithRateLimit);
      
      // Start live view based on camera type
      if (camera.connectionType == CameraConnectionType.usb) {
        return await _startUSBLiveView(camera);
      } else if (camera.connectionType == CameraConnectionType.wifi) {
        return await _startWiFiLiveView(camera);
      }
      
      return false;
    } catch (e) {
      debugPrint('🚨 ExternalCameraService: CRITICAL ERROR - Failed to start live view: $e');
      debugPrint('🚨 Error type: ${e.runtimeType}');
      debugPrint('🚨 Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Process frame with rate limiting for smoother playback
  void _processFrameWithRateLimit(Uint8List frameData) {
    final now = DateTime.now();
    
    // Rate limiting: only process frames at target FPS
    if (_lastFrameTime != null && 
        now.difference(_lastFrameTime!) < _frameInterval) {
      return; // Skip this frame to maintain target FPS
    }
    
    // Validate frame data
    if (_isValidJpegFrame(frameData)) {
      _lastValidFrame = frameData;
      _lastFrameTime = now;
      
      // Send to buffered stream
      if (_bufferedLiveViewController != null && !_bufferedLiveViewController!.isClosed) {
        _bufferedLiveViewController!.add(frameData);
      }
    } else {
      // Use last valid frame if current is corrupted
      if (_lastValidFrame != null) {
        _bufferedLiveViewController?.add(_lastValidFrame!);
      }
    }
  }
  
  /// Validate JPEG frame data
  bool _isValidJpegFrame(Uint8List data) {
    // More lenient validation for live view streams
    return data.length > 1000 && 
           data[0] == 0xFF && 
           data[1] == 0xD8;
           // Don't check end marker as live streams may not have complete frames
  }

  /// Stop live view streaming
  Future<void> stopLiveView() async {
    if (!_isLiveViewActive) return;
    
    debugPrint('ExternalCameraService: Stopping live view');
    
    _liveViewTimer?.cancel();
    _liveViewTimer = null;
    
    // Stop libgphoto2 live view if active
    try {
      if (_libgphoto2.isLiveViewActive) {
        await _libgphoto2.stopLiveView();
      }
    } catch (e) {
      debugPrint('ExternalCameraService: Error stopping libgphoto2: $e');
    }
    
    // Stop Nikon SDK live view if active
    try {
      await _nikonSDK.stopLiveView();
    } catch (e) {
      debugPrint('ExternalCameraService: Error stopping Nikon SDK: $e');
    }
    
    // Close both stream controllers
    await _liveViewStreamController?.close();
    _liveViewStreamController = null;
    await _bufferedLiveViewController?.close();
    _bufferedLiveViewController = null;
    
    // Clear frame cache
    _lastFrameTime = null;
    _lastValidFrame = null;
    
    _isLiveViewActive = false;
    _activeLiveViewCameraId = null;
  }

  /// Start USB live view streaming (for Nikon D90, etc.)
  Future<bool> _startUSBLiveView(ExternalCamera camera) async {
    try {
      debugPrint('ExternalCameraService: Starting USB live view for ${camera.model}');
      
      // For Nikon cameras, try the real SDK first
      if (camera.brand == CameraBrand.nikon) {
        debugPrint('ExternalCameraService: Attempting real Nikon SDK live view for ${camera.model}');
        final realSdkSuccess = await _startNikonLiveView(camera);
        if (realSdkSuccess) {
          return true;
        }
        debugPrint('ExternalCameraService: Real Nikon SDK failed - no mock fallback');
        return false;
      }
      
      // No other camera types supported for live view yet
      debugPrint('ExternalCameraService: Live view not supported for ${camera.brand} cameras');
      return false;
    } catch (e) {
      debugPrint('ExternalCameraService: USB live view error: $e');
      return false;
    }
  }
  
  /// Start live view using libgphoto2 (primary) or Nikon SDK (fallback)
  Future<bool> _startNikonLiveView(ExternalCamera camera) async {
    try {
      debugPrint('ExternalCameraService: Starting camera live view for ${camera.model}');
      
      // Try libgphoto2 first (purpose-built for D90 PTP cameras)
      debugPrint('ExternalCameraService: Attempting libgphoto2 live view (PTP camera support)');
      final libgphoto2Success = await _startLibGPhoto2LiveView(camera);
      if (libgphoto2Success) {
        debugPrint('ExternalCameraService: ✅ libgphoto2 live view successful - using real D90 camera');
        return true;
      }
      
      // Fallback to Nikon SDK (AVFoundation) - will likely use Mac camera
      debugPrint('ExternalCameraService: ⚠️ libgphoto2 failed, falling back to AVFoundation (likely Mac camera)');
      return await _startNikonSDKLiveView(camera);
      
    } catch (e) {
      debugPrint('ExternalCameraService: Camera live view error: $e');
      return false;
    }
  }
  
  /// Start live view using libgphoto2 (primary method)
  Future<bool> _startLibGPhoto2LiveView(ExternalCamera camera) async {
    try {
      debugPrint('ExternalCameraService: Starting libgphoto2 live view for ${camera.model}');
      
      // Initialize libgphoto2 service
      final initialized = await _libgphoto2.initialize();
      if (!initialized) {
        debugPrint('ExternalCameraService: libgphoto2 initialization failed');
        return false;
      }
      
      // Detect cameras
      final cameras = await _libgphoto2.detectCameras();
      if (cameras.isEmpty) {
        debugPrint('ExternalCameraService: No cameras detected by libgphoto2');
        return false;
      }
      
      debugPrint('ExternalCameraService: libgphoto2 detected ${cameras.length} cameras');
      
      // Connect to camera
      final connected = await _libgphoto2.connect();
      if (!connected) {
        debugPrint('ExternalCameraService: libgphoto2 connection failed');
        return false;
      }
      
      // Start live view
      final liveViewStarted = await _libgphoto2.startLiveView();
      if (!liveViewStarted) {
        debugPrint('ExternalCameraService: libgphoto2 live view start failed');
        return false;
      }
      
      // Subscribe to libgphoto2 live view stream
      final libgphoto2Stream = _libgphoto2.liveViewStream;
      if (libgphoto2Stream != null) {
        libgphoto2Stream.listen(
          (imageData) {
            if (_isLiveViewActive && _liveViewStreamController != null) {
              debugPrint('ExternalCameraService: Received libgphoto2 live view frame: ${imageData.length} bytes');
              _liveViewStreamController!.add(imageData);
            }
          },
          onError: (error) {
            debugPrint('ExternalCameraService: libgphoto2 live view stream error: $error');
          },
        );
      }
      
      debugPrint('ExternalCameraService: libgphoto2 live view started successfully');
      return true;
      
    } catch (e) {
      debugPrint('ExternalCameraService: libgphoto2 live view error: $e');
      return false;
    }
  }
  
  /// Start live view using Nikon SDK (fallback method)
  Future<bool> _startNikonSDKLiveView(ExternalCamera camera) async {
    try {
      debugPrint('ExternalCameraService: Starting Nikon SDK live view for ${camera.model}');
      
      // Initialize the Nikon SDK service
      await _nikonSDK.initialize();
      
      // Test method channel connectivity first with timeout
      debugPrint('ExternalCameraService: Testing method channel connection...');
      bool testResult = false;
      try {
        testResult = await _nikonSDK.testConnection().timeout(Duration(seconds: 15));
        debugPrint('ExternalCameraService: Method channel test result: $testResult');
      } catch (e) {
        debugPrint('ExternalCameraService: Method channel test timeout or error: $e');
        return false;
      }
      
      if (!testResult) {
        debugPrint('ExternalCameraService: Method channel test failed - SDK bridge not working');
        return false;
      }
      
      // Check if camera is connected via SDK with timeout
      bool isConnected = false;
      try {
        isConnected = await _nikonSDK.isCameraConnected().timeout(Duration(seconds: 15));
        debugPrint('ExternalCameraService: Camera connection check: $isConnected');
      } catch (e) {
        debugPrint('ExternalCameraService: Camera connection check timeout or error: $e');
        return false;
      }
      
      if (!isConnected) {
        debugPrint('ExternalCameraService: Nikon camera not connected via SDK');
        return false;
      }
      
      // Start live view via SDK with timeout
      bool success = false;
      try {
        success = await _nikonSDK.startLiveView().timeout(Duration(seconds: 20));
        debugPrint('ExternalCameraService: Nikon SDK live view start result: $success');
      } catch (e) {
        debugPrint('ExternalCameraService: Nikon SDK live view start timeout or error: $e');
        return false;
      }
      
      if (!success) {
        debugPrint('ExternalCameraService: Failed to start Nikon SDK live view');
        return false;
      }
      
      // Subscribe to the real live view stream from SDK
      final sdkStream = _nikonSDK.liveViewStream;
      if (sdkStream != null) {
        sdkStream.listen(
          (imageData) {
            if (_isLiveViewActive && _liveViewStreamController != null) {
              debugPrint('ExternalCameraService: Received Nikon SDK live view frame: ${imageData.length} bytes');
              _liveViewStreamController!.add(imageData);
            }
          },
          onError: (error) {
            debugPrint('ExternalCameraService: Nikon SDK live view stream error: $error');
          },
        );
      }
      
      debugPrint('ExternalCameraService: Nikon SDK live view started successfully');
      return true;
      
    } catch (e) {
      debugPrint('ExternalCameraService: Nikon SDK live view error: $e');
      return false;
    }
  }

  /// Start WiFi live view streaming
  Future<bool> _startWiFiLiveView(ExternalCamera camera) async {
    try {
      debugPrint('ExternalCameraService: WiFi live view not implemented for ${camera.name}');
      // WiFi live view would require camera-specific HTTP/RTSP stream implementation
      // This is not implemented yet - would need camera manufacturer protocols
      return false;
    } catch (e) {
      debugPrint('ExternalCameraService: WiFi live view error: $e');
      return false;
    }
  }

  /// Stop macOS PTP services that block camera access
  Future<bool> stopPTPService() async {
    try {
      debugPrint('ExternalCameraService: Stopping PTP service via Nikon SDK');
      final success = await _nikonSDK.stopPTPService();
      debugPrint('ExternalCameraService: Stop PTP service result: $success');
      return success;
    } catch (e) {
      debugPrint('ExternalCameraService: Stop PTP service error: $e');
      return false;
    }
  }

  void dispose() {
    stopDiscovery();
    _liveViewTimer?.cancel();
    _liveViewStreamController?.close();
    _bufferedLiveViewController?.close();
    _cameraStreamController.close();
  }
  
  // Camera state persistence methods
  Future<void> _saveConnectedCamera(ExternalCamera? camera) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (camera != null) {
        await prefs.setString(_connectedCameraKey, jsonEncode(camera.toJson()));
        debugPrint('ExternalCameraService: Saved connected camera: ${camera.name}');
      } else {
        await prefs.remove(_connectedCameraKey);
        debugPrint('ExternalCameraService: Removed connected camera from storage');
      }
    } catch (e) {
      debugPrint('ExternalCameraService: Error saving connected camera: $e');
    }
  }
  
  Future<ExternalCamera?> _loadConnectedCamera() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cameraJson = prefs.getString(_connectedCameraKey);
      if (cameraJson != null) {
        final camera = ExternalCamera.fromJson(jsonDecode(cameraJson));
        debugPrint('ExternalCameraService: Loaded connected camera: ${camera.name}');
        return camera;
      }
    } catch (e) {
      debugPrint('ExternalCameraService: Error loading connected camera: $e');
    }
    return null;
  }
  
  Future<void> _saveDiscoveredCameras(List<ExternalCamera> cameras) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final camerasJson = cameras.map((c) => c.toJson()).toList();
      await prefs.setString(_discoveredCamerasKey, jsonEncode(camerasJson));
      debugPrint('ExternalCameraService: Saved ${cameras.length} discovered cameras');
    } catch (e) {
      debugPrint('ExternalCameraService: Error saving discovered cameras: $e');
    }
  }
  
  Future<List<ExternalCamera>> _loadDiscoveredCameras() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final camerasJson = prefs.getString(_discoveredCamerasKey);
      if (camerasJson != null) {
        final camerasList = jsonDecode(camerasJson) as List;
        final cameras = camerasList.map((c) => ExternalCamera.fromJson(c)).toList();
        debugPrint('ExternalCameraService: Loaded ${cameras.length} discovered cameras');
        return cameras;
      }
    } catch (e) {
      debugPrint('ExternalCameraService: Error loading discovered cameras: $e');
    }
    return [];
  }
  
  Future<void> initializeFromStorage() async {
    try {
      // Load previously discovered cameras
      final savedCameras = await _loadDiscoveredCameras();
      _discoveredCameras.clear();
      _discoveredCameras.addAll(savedCameras);
      
      // Load and restore connected camera state
      final connectedCamera = await _loadConnectedCamera();
      if (connectedCamera != null) {
        // Find the camera in discovered cameras and update its connection status
        final index = _discoveredCameras.indexWhere((c) => c.id == connectedCamera.id);
        if (index >= 0) {
          _discoveredCameras[index] = _discoveredCameras[index].copyWith(isConnected: true);
          debugPrint('ExternalCameraService: Restored connection status for ${connectedCamera.name}');
        } else {
          // Add the connected camera to discovered cameras if not found
          _discoveredCameras.add(connectedCamera.copyWith(isConnected: true));
          debugPrint('ExternalCameraService: Added previously connected camera ${connectedCamera.name}');
        }
      }
      
      // Notify listeners of initial state
      if (!_cameraStreamController.isClosed) {
        _cameraStreamController.add(List.unmodifiable(_discoveredCameras));
      }
      
      debugPrint('ExternalCameraService: Initialized from storage with ${_discoveredCameras.length} cameras');
    } catch (e) {
      debugPrint('ExternalCameraService: Error initializing from storage: $e');
    }
  }
}
import 'dart:io';
import 'lib/services/external_camera_service.dart';
import 'lib/services/native_system_service.dart';

/// Standalone test for external camera detection
/// Run with: dart run test_external_camera.dart
void main() async {
  print('=== Lens AI External Camera Detection Test ===');
  print('Platform: ${Platform.operatingSystem}');
  print('');

  // Test system information
  print('Getting system information...');
  final systemInfo = await NativeSystemService.getSystemInfo();
  systemInfo.forEach((key, value) {
    print('  $key: $value');
  });
  print('');

  // Test camera detection
  print('Initializing external camera service...');
  final cameraService = ExternalCameraService();
  
  // Listen for camera discoveries
  var cameraCount = 0;
  cameraService.cameraStream.listen((cameras) {
    print('Camera discovery update: ${cameras.length} cameras found');
    
    for (final camera in cameras) {
      cameraCount++;
      print('  Camera #$cameraCount:');
      print('    Name: ${camera.name}');
      print('    Model: ${camera.model}');
      print('    Brand: ${camera.brand.name}');
      print('    Type: ${camera.type.name}');
      print('    Connection: ${camera.connectionType.name}');
      print('    Connected: ${camera.isConnected}');
      
      if (camera.ipAddress != null) {
        print('    IP Address: ${camera.ipAddress}');
      }
      
      if (camera.usbPath != null) {
        print('    USB Path: ${camera.usbPath}');
      }
      
      if (camera.capabilities != null && camera.capabilities!.isNotEmpty) {
        print('    Capabilities:');
        camera.capabilities!.forEach((key, value) {
          if (value == true) {
            print('      - $key');
          }
        });
      }
      print('');
    }
    
    if (cameras.isEmpty) {
      print('  No cameras detected.');
      print('  This could mean:');
      print('    - No external cameras are connected');
      print('    - USB permissions are needed');
      print('    - Platform-specific drivers are missing');
      print('');
    }
  });

  print('Starting camera discovery...');
  await cameraService.startDiscovery();
  
  // Wait for discovery to complete
  print('Waiting 10 seconds for camera discovery...');
  await Future.delayed(const Duration(seconds: 10));
  
  print('Stopping camera discovery...');
  await cameraService.stopDiscovery();
  
  print('Test completed.');
  print('');
  
  // Test specific D90 simulation
  print('=== D90 Simulation Test ===');
  final testCameras = cameraService.discoveredCameras;
  final d90Cameras = testCameras.where((c) => 
    c.model.toLowerCase().contains('d90') || 
    c.name.toLowerCase().contains('d90')
  ).toList();
  
  if (d90Cameras.isNotEmpty) {
    print('Found ${d90Cameras.length} D90 camera(s):');
    for (final camera in d90Cameras) {
      print('  - ${camera.name} (${camera.connectionType.name})');
    }
  } else {
    print('No D90 cameras detected.');
    print('In debug mode, a simulation camera should be created.');
  }
  
  cameraService.dispose();
  print('');
  print('Test finished. Exiting...');
}
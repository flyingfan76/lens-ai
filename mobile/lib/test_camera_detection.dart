import 'package:flutter/material.dart';
import 'services/external_camera_service.dart';
import 'services/native_system_service.dart';
import 'models/external_camera.dart';

/// Test screen for camera detection functionality
class CameraDetectionTestScreen extends StatefulWidget {
  const CameraDetectionTestScreen({super.key});

  @override
  State<CameraDetectionTestScreen> createState() => _CameraDetectionTestScreenState();
}

class _CameraDetectionTestScreenState extends State<CameraDetectionTestScreen> {
  final ExternalCameraService _cameraService = ExternalCameraService();
  List<ExternalCamera> _detectedCameras = [];
  Map<String, String> _systemInfo = {};
  bool _isScanning = false;
  String _scanStatus = 'Ready to scan';

  @override
  void initState() {
    super.initState();
    _initializeTest();
  }

  Future<void> _initializeTest() async {
    // Get system information
    final systemInfo = await NativeSystemService.getSystemInfo();
    setState(() {
      _systemInfo = systemInfo;
    });

    // Listen to camera discoveries
    _cameraService.cameraStream.listen((cameras) {
      setState(() {
        _detectedCameras = cameras;
        _isScanning = false;
        _scanStatus = cameras.isEmpty 
          ? 'No cameras detected' 
          : 'Found ${cameras.length} camera(s)';
      });
    });
  }

  Future<void> _startCameraDetection() async {
    setState(() {
      _isScanning = true;
      _scanStatus = 'Scanning for cameras...';
    });

    try {
      await _cameraService.startDiscovery();
    } catch (e) {
      setState(() {
        _isScanning = false;
        _scanStatus = 'Scan failed: $e';
      });
    }
  }

  Future<void> _stopCameraDetection() async {
    await _cameraService.stopDiscovery();
    setState(() {
      _isScanning = false;
      _scanStatus = 'Scan stopped';
    });
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Detection Test'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // System Information
            _buildSystemInfoCard(),
            const SizedBox(height: 16),
            
            // Camera Detection Controls
            _buildDetectionControlsCard(),
            const SizedBox(height: 16),
            
            // Detected Cameras
            _buildDetectedCamerasCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_systemInfo.isEmpty)
              const Text('Loading system info...')
            else
              ..._systemInfo.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            '${entry.key}:',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionControlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Camera Detection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _scanStatus,
              style: TextStyle(
                color: _isScanning ? Colors.orange : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startCameraDetection,
                  icon: _isScanning 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                  label: Text(_isScanning ? 'Scanning...' : 'Start Detection'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isScanning ? _stopCameraDetection : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectedCamerasCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detected Cameras',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_detectedCameras.isEmpty)
              const Text('No cameras detected yet. Try starting detection.')
            else
              ..._detectedCameras.map((camera) => _buildCameraCard(camera)),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraCard(ExternalCamera camera) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: camera.isConnected ? Colors.green[50] : Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getCameraIcon(camera.brand),
                color: camera.isConnected ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  camera.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: camera.isConnected ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  camera.isConnected ? 'Connected' : 'Available',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Model', camera.model),
          _buildInfoRow('Brand', camera.brand.name.toUpperCase()),
          _buildInfoRow('Type', camera.type.name.toUpperCase()),
          _buildInfoRow('Connection', camera.connectionType.name.toUpperCase()),
          if (camera.ipAddress != null)
            _buildInfoRow('IP Address', camera.ipAddress!),
          if (camera.usbPath != null)
            _buildInfoRow('USB Path', camera.usbPath!),
          _buildInfoRow('Discovered', 
            '${DateTime.now().difference(camera.discoveredAt).inSeconds}s ago'),
          
          // Capabilities
          if (camera.capabilities != null && camera.capabilities!.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Capabilities:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: camera.capabilities!.entries
                  .where((entry) => entry.value == true)
                  .map((entry) => Chip(
                        label: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 10),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCameraIcon(CameraBrand brand) {
    switch (brand) {
      case CameraBrand.nikon:
        return Icons.camera_alt;
      case CameraBrand.canon:
        return Icons.camera;
      case CameraBrand.sony:
        return Icons.camera_enhance;
      case CameraBrand.fujifilm:
        return Icons.camera_alt_outlined;
      case CameraBrand.olympus:
        return Icons.camera_rear;
      case CameraBrand.panasonic:
        return Icons.videocam;
      default:
        return Icons.camera_alt_outlined;
    }
  }
}
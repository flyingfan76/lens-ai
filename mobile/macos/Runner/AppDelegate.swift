import Cocoa
import FlutterMacOS
import AVFoundation

@main  
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
  }
}

/// macOS camera bridge that provides built-in camera functionality
/// This addresses the limitation where Flutter's camera plugin doesn't work on macOS
class MacOSCameraBridge: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    
    // Camera capture session
    private var captureSession: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    
    // Live preview
    private var previewView: NSView?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // State management
    private var isInitialized = false
    private var isRecording = false
    private var availableCameras: [AVCaptureDevice] = []
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "lens_ai/macos_camera", binaryMessenger: registrar.messenger)
        let eventChannel = FlutterEventChannel(name: "lens_ai/macos_camera_events", binaryMessenger: registrar.messenger)
        
        let instance = MacOSCameraBridge()
        instance.channel = channel
        instance.eventChannel = eventChannel
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAvailableCameras":
            getAvailableCameras(result: result)
            
        case "initializeCamera":
            guard let args = call.arguments as? [String: Any],
                  let cameraId = args["cameraId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing cameraId", details: nil))
                return
            }
            initializeCamera(cameraId: cameraId, result: result)
            
        case "startImageStream":
            startImageStream(result: result)
            
        case "stopImageStream":
            stopImageStream(result: result)
            
        case "takePicture":
            takePicture(result: result)
            
        case "dispose":
            dispose(result: result)
            
        case "startVideoRecording":
            startVideoRecording(result: result)
            
        case "stopVideoRecording":
            stopVideoRecording(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func getAvailableCameras(result: @escaping FlutterResult) {
        // Request camera permissions first
        requestCameraPermissions { [weak self] granted in
            guard granted else {
                result(FlutterError(code: "PERMISSION_DENIED", message: "Camera permission denied", details: nil))
                return
            }
            
            self?.discoverAvailableCameras()
            
            let cameras = self?.availableCameras.enumerated().map { index, device in
                return [
                    "id": device.uniqueID,
                    "name": device.localizedName,
                    "lensDirection": self?.getLensDirection(for: device) ?? "unknown",
                    "sensorOrientation": 0
                ]
            } ?? []
            
            result(cameras)
        }
    }
    
    private func requestCameraPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func discoverAvailableCameras() {
        // Use older API that works on macOS 10.14+
        availableCameras = AVCaptureDevice.devices(for: .video)
        print("MacOSCameraBridge: Found \(availableCameras.count) cameras")
        for camera in availableCameras {
            print("  - \(camera.localizedName) (ID: \(camera.uniqueID))")
        }
    }
    
    private func getLensDirection(for device: AVCaptureDevice) -> String {
        switch device.position {
        case .front:
            return "front"
        case .back:
            return "back"
        case .unspecified:
            return "external"
        @unknown default:
            return "unknown"
        }
    }
    
    private func initializeCamera(cameraId: String, result: @escaping FlutterResult) {
        // Clean up existing session
        cleanupCaptureSession()
        
        // Find the requested camera
        guard let device = availableCameras.first(where: { $0.uniqueID == cameraId }) else {
            result(FlutterError(code: "CAMERA_NOT_FOUND", message: "Camera with ID \(cameraId) not found", details: nil))
            return
        }
        
        do {
            // Create capture session
            captureSession = AVCaptureSession()
            captureSession?.sessionPreset = .high
            
            // Create device input
            videoDeviceInput = try AVCaptureDeviceInput(device: device)
            guard let videoInput = videoDeviceInput else {
                throw NSError(domain: "MacOSCameraBridge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create video input"])
            }
            
            if captureSession?.canAddInput(videoInput) == true {
                captureSession?.addInput(videoInput)
                videoDevice = device
            } else {
                throw NSError(domain: "MacOSCameraBridge", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input to session"])
            }
            
            // Create video output for live stream
            videoOutput = AVCaptureVideoDataOutput()
            videoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_video_queue"))
            
            if captureSession?.canAddOutput(videoOutput!) == true {
                captureSession?.addOutput(videoOutput!)
            }
            
            // Start the session
            captureSession?.startRunning()
            
            isInitialized = true
            
            let cameraInfo = [
                "textureId": 0, // Not used for macOS implementation
                "previewWidth": 1920.0,
                "previewHeight": 1080.0
            ]
            
            result(cameraInfo)
            print("MacOSCameraBridge: Camera \(device.localizedName) initialized successfully")
            
        } catch {
            result(FlutterError(code: "CAMERA_ERROR", message: "Failed to initialize camera: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func startImageStream(result: @escaping FlutterResult) {
        result(nil)
    }
    
    private func stopImageStream(result: @escaping FlutterResult) {
        result(nil)
    }
    
    private func takePicture(result: @escaping FlutterResult) {
        result(FlutterError(code: "NOT_IMPLEMENTED", message: "Photo capture not implemented yet", details: nil))
    }
    
    private func startVideoRecording(result: @escaping FlutterResult) {
        result(FlutterError(code: "NOT_IMPLEMENTED", message: "Video recording not implemented yet", details: nil))
    }
    
    private func stopVideoRecording(result: @escaping FlutterResult) {
        result(FlutterError(code: "NOT_IMPLEMENTED", message: "Video recording not implemented yet", details: nil))
    }
    
    private func dispose(result: @escaping FlutterResult) {
        cleanupCaptureSession()
        isInitialized = false
        result(nil)
    }
    
    private func cleanupCaptureSession() {
        captureSession?.stopRunning()
        
        if let inputs = captureSession?.inputs {
            for input in inputs {
                captureSession?.removeInput(input)
            }
        }
        
        if let outputs = captureSession?.outputs {
            for output in outputs {
                captureSession?.removeOutput(output)
            }
        }
        
        captureSession = nil
        videoDevice = nil
        videoDeviceInput = nil
        videoOutput = nil
        previewLayer = nil
    }
}

// MARK: - FlutterStreamHandler
extension MacOSCameraBridge: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension MacOSCameraBridge: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Convert sample buffer to image data and send via event sink for live preview
        guard let eventSink = eventSink else { return }
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [:]) else { return }
        
        // Send image data to Flutter
        eventSink(FlutterStandardTypedData(bytes: jpegData))
    }
}

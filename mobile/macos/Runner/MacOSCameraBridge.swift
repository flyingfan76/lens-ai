import Cocoa
import FlutterMacOS
import AVFoundation

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
    private var photoOutput: AVCapturePhotoOutput?
    
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
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        availableCameras = discoverySession.devices
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
            
            // Create photo output
            photoOutput = AVCapturePhotoOutput()
            if captureSession?.canAddOutput(photoOutput!) == true {
                captureSession?.addOutput(photoOutput!)
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
            
        } catch {
            result(FlutterError(code: "CAMERA_ERROR", message: "Failed to initialize camera: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func startImageStream(result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Camera not initialized", details: nil))
            return
        }
        
        result(nil)
    }
    
    private func stopImageStream(result: @escaping FlutterResult) {
        result(nil)
    }
    
    private func takePicture(result: @escaping FlutterResult) {
        guard isInitialized, let photoOutput = photoOutput else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Camera not initialized", details: nil))
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        
        let photoDelegate = PhotoCaptureDelegate { [weak self] imageData, error in
            if let error = error {
                result(FlutterError(code: "CAPTURE_ERROR", message: error.localizedDescription, details: nil))
            } else if let imageData = imageData {
                self?.savePhotoToDesktop(imageData: imageData) { path, error in
                    if let error = error {
                        result(FlutterError(code: "SAVE_ERROR", message: error.localizedDescription, details: nil))
                    } else if let path = path {
                        result(["path": path])
                    }
                }
            }
        }
        
        photoOutput.capturePhoto(with: settings, delegate: photoDelegate)
    }
    
    private func savePhotoToDesktop(imageData: Data, completion: @escaping (String?, Error?) -> Void) {
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let filename = "lens_ai_\(Date().timeIntervalSince1970).jpg"
        let fileURL = desktopURL.appendingPathComponent(filename)
        
        do {
            try imageData.write(to: fileURL)
            completion(fileURL.path, nil)
        } catch {
            completion(nil, error)
        }
    }
    
    private func startVideoRecording(result: @escaping FlutterResult) {
        // Video recording implementation would go here
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
        photoOutput = nil
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

// MARK: - Photo Capture Delegate
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Data?, Error?) -> Void
    
    init(completion: @escaping (Data?, Error?) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completion(nil, error)
        } else if let imageData = photo.fileDataRepresentation() {
            completion(imageData, nil)
        } else {
            completion(nil, NSError(domain: "PhotoCaptureDelegate", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to get image data"]))
        }
    }
}
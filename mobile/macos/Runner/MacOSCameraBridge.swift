import Cocoa
import FlutterMacOS
import AVFoundation
import CoreImage

/// macOS camera bridge that provides built-in camera functionality
/// This addresses the limitation where Flutter's camera plugin doesn't work on macOS
class MacOSCameraBridge: NSObject, FlutterPlugin, AVCaptureVideoDataOutputSampleBufferDelegate {
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
            print("MacOSCameraBridge: Requesting camera permissions...")
            
            // Add timeout for permission request
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
                print("MacOSCameraBridge: Camera permission request timed out")
                completion(false)
            }
            
            AVCaptureDevice.requestAccess(for: .video) { granted in
                timeoutTimer.invalidate()
                DispatchQueue.main.async {
                    print("MacOSCameraBridge: Camera permission granted: \(granted)")
                    completion(granted)
                }
            }
        case .denied, .restricted:
            print("MacOSCameraBridge: Camera permission denied or restricted")
            completion(false)
        @unknown default:
            print("MacOSCameraBridge: Unknown camera permission status")
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
        print("MacOSCameraBridge: Initializing camera with ID: \(cameraId)")
        
        // Clean up existing session
        cleanupCaptureSession()
        
        // Find the requested camera
        guard let device = availableCameras.first(where: { $0.uniqueID == cameraId }) else {
            result(FlutterError(code: "CAMERA_NOT_FOUND", message: "Camera with ID \(cameraId) not found", details: nil))
            return
        }
        
        // Add timeout for camera initialization
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { _ in
            print("MacOSCameraBridge: Camera initialization timed out")
            self.cleanupCaptureSession()
            result(FlutterError(code: "CAMERA_TIMEOUT", message: "Camera initialization timed out after 15 seconds", details: nil))
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                guard let self = self else { return }
                
                print("MacOSCameraBridge: Creating capture session...")
                
                // Create capture session
                self.captureSession = AVCaptureSession()
                self.captureSession?.sessionPreset = .high
                
                // Create device input
                self.videoDeviceInput = try AVCaptureDeviceInput(device: device)
                guard let videoInput = self.videoDeviceInput else {
                    throw NSError(domain: "MacOSCameraBridge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create video input"])
                }
                
                if self.captureSession?.canAddInput(videoInput) == true {
                    self.captureSession?.addInput(videoInput)
                    self.videoDevice = device
                    print("MacOSCameraBridge: Video input added successfully")
                } else {
                    throw NSError(domain: "MacOSCameraBridge", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input to session"])
                }
                
                // Create video output for live stream
                self.videoOutput = AVCaptureVideoDataOutput()
                
                if self.captureSession?.canAddOutput(self.videoOutput!) == true {
                    self.captureSession?.addOutput(self.videoOutput!)
                    print("MacOSCameraBridge: Video output added successfully")
                }
                
                // Create photo output
                self.photoOutput = AVCapturePhotoOutput()
                if self.captureSession?.canAddOutput(self.photoOutput!) == true {
                    self.captureSession?.addOutput(self.photoOutput!)
                    print("MacOSCameraBridge: Photo output added successfully")
                }
                
                // Start the session with timeout protection
                print("MacOSCameraBridge: Starting capture session...")
                self.captureSession?.startRunning()
                
                // Wait a moment for session to stabilize
                Thread.sleep(forTimeInterval: 0.5)
                
                DispatchQueue.main.async {
                    timeoutTimer.invalidate()
                    
                    if self.captureSession?.isRunning == true {
                        self.isInitialized = true
                        print("MacOSCameraBridge: Camera initialized successfully")
                        
                        let cameraInfo = [
                            "textureId": 0, // Not used for macOS implementation
                            "previewWidth": 1920.0,
                            "previewHeight": 1080.0
                        ]
                        
                        result(cameraInfo)
                    } else {
                        print("MacOSCameraBridge: Capture session failed to start")
                        self.cleanupCaptureSession()
                        result(FlutterError(code: "CAMERA_ERROR", message: "Capture session failed to start", details: nil))
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    timeoutTimer.invalidate()
                    print("MacOSCameraBridge: Camera initialization error: \(error.localizedDescription)")
                    self.cleanupCaptureSession()
                    result(FlutterError(code: "CAMERA_ERROR", message: "Failed to initialize camera: \(error.localizedDescription)", details: nil))
                }
            }
        }
    }
    
    private func startImageStream(result: @escaping FlutterResult) {
        print("MacOSCameraBridge: Starting image stream...")
        
        guard isInitialized else {
            print("MacOSCameraBridge: Camera not initialized for image stream")
            result(FlutterError(code: "NOT_INITIALIZED", message: "Camera not initialized", details: nil))
            return
        }
        
        guard let videoOutput = videoOutput else {
            print("MacOSCameraBridge: Video output not configured")
            result(FlutterError(code: "NO_VIDEO_OUTPUT", message: "Video output not configured", details: nil))
            return
        }
        
        guard eventSink != nil else {
            print("MacOSCameraBridge: Event sink not ready")
            result(FlutterError(code: "EVENT_SINK_NOT_READY", message: "Event sink not initialized", details: nil))
            return
        }
        
        // Add timeout for stream start
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            print("MacOSCameraBridge: Image stream start timed out")
            result(FlutterError(code: "STREAM_TIMEOUT", message: "Image stream failed to start within 10 seconds", details: nil))
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Configure video output for live streaming
                let videoSettings: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                videoOutput.videoSettings = videoSettings
                
                // Set up delegate for receiving frames
                let queue = DispatchQueue(label: "camera_frames", qos: .userInitiated)
                videoOutput.setSampleBufferDelegate(self, queue: queue)
                
                // Ensure capture session is running
                if let session = self.captureSession {
                    if !session.isRunning {
                        print("MacOSCameraBridge: Starting capture session for image stream...")
                        session.startRunning()
                        
                        // Wait for session to stabilize
                        Thread.sleep(forTimeInterval: 1.0)
                    }
                    
                    DispatchQueue.main.async {
                        timeoutTimer.invalidate()
                        
                        if session.isRunning {
                            print("MacOSCameraBridge: Image stream started successfully")
                            result(nil)
                        } else {
                            print("MacOSCameraBridge: Failed to start capture session for image stream")
                            result(FlutterError(code: "STREAM_ERROR", message: "Failed to start capture session", details: nil))
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        timeoutTimer.invalidate()
                        print("MacOSCameraBridge: No capture session available")
                        result(FlutterError(code: "NO_SESSION", message: "No capture session available", details: nil))
                    }
                }
            }
        }
    }
    
    private func stopImageStream(result: @escaping FlutterResult) {
        // Stop the delegate
        videoOutput?.setSampleBufferDelegate(nil, queue: nil)
        result(nil)
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let eventSink = eventSink,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Convert CVImageBuffer to CGImage
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        
        // Convert CGImage to JPEG data
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return
        }
        
        // Send frame data to Flutter
        DispatchQueue.main.async {
            eventSink(FlutterStandardTypedData(bytes: jpegData))
        }
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
        print("MacOSCameraBridge: Cleaning up capture session...")
        
        // Stop video output delegate first
        videoOutput?.setSampleBufferDelegate(nil, queue: nil)
        
        // Stop the capture session
        if let session = captureSession {
            if session.isRunning {
                print("MacOSCameraBridge: Stopping capture session...")
                session.stopRunning()
            }
            
            // Remove all inputs
            if let inputs = session.inputs {
                for input in inputs {
                    session.removeInput(input)
                }
            }
            
            // Remove all outputs
            if let outputs = session.outputs {
                for output in outputs {
                    session.removeOutput(output)
                }
            }
        }
        
        // Clear all references
        captureSession = nil
        videoDevice = nil
        videoDeviceInput = nil
        videoOutput = nil
        photoOutput = nil
        previewLayer = nil
        isInitialized = false
        
        print("MacOSCameraBridge: Capture session cleanup completed")
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
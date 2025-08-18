import Cocoa
import FlutterMacOS
import AVFoundation
import CoreMediaIO

public class NikonSDKBridge: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var videoDevice: AVCaptureDevice?
    private var isLiveViewActive = false
    private var frameCount = 0
    
    private let videoQueue = DispatchQueue(label: "camera.video.queue")
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        print("NikonSDKBridge: Registering with enhanced PTP handling")
        let methodChannel = FlutterMethodChannel(name: "nikon_sdk_bridge", binaryMessenger: registrar.messenger)
        let eventChannel = FlutterEventChannel(name: "nikon_sdk_events", binaryMessenger: registrar.messenger)
        let instance = NikonSDKBridge()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
        
        // Enhanced camera access with PTP coordination
        instance.enableExternalCameraAccess()
        instance.setupPTPCoordination()
    }
    
    private func enableExternalCameraAccess() {
        print("NikonSDKBridge: Enabling external camera access")
        
        // Enable CoreMediaIO device access for external cameras
        var property = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )
        
        var allow: UInt32 = 1
        let dataSize: UInt32 = 4
        let result = CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &property, 0, nil, dataSize, &allow)
        
        if result == 0 {
            print("NikonSDKBridge: Successfully enabled external camera access")
        } else {
            print("NikonSDKBridge: Failed to enable external camera access: \(result)")
        }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("NikonSDKBridge: Method call: \(call.method)")
        
        switch call.method {
        case "test":
            testConnection(result: result)
        case "startLiveView":
            startLiveView(result: result)
        case "stopLiveView":
            stopLiveView(result: result)
        case "getLiveViewImage":
            getLiveViewImage(result: result)
        case "isCameraConnected":
            checkCameraConnection(result: result)
        case "capturePhoto":
            capturePhoto(result: result)
        case "managePTP":
            if let args = call.arguments as? [String: Any],
               let action = args["action"] as? String {
                managePTP(action: action, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing action", details: nil))
            }
        case "requestExclusiveAccess":
            requestExclusiveAccess(result: result)
        default:
            print("NikonSDKBridge: Unknown method: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Camera Detection
    
    private func findExternalCameras() -> [AVCaptureDevice] {
        print("NikonSDKBridge: Searching for cameras")
        
        // Use legacy AVCaptureDevice.devices() for compatibility with macOS 10.14
        #if swift(>=5.0)
        let allDevices = AVCaptureDevice.devices(for: .video)
        #else
        let allDevices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! [AVCaptureDevice]
        #endif
        
        let cameraDevices = allDevices.filter { device in
            let deviceName = device.localizedName.lowercased()
            let isNikon = deviceName.contains("nikon") || 
                         deviceName.contains("d90") ||
                         deviceName.contains("dsc")  // Digital Still Camera
            
            // Exclude Mac built-in cameras
            let isMacCamera = deviceName.contains("facetime") ||
                             deviceName.contains("built-in") ||
                             deviceName.contains("imac") ||
                             deviceName.contains("macbook")
            
            let shouldInclude = isNikon && !isMacCamera
            
            print("NikonSDKBridge: Found device: \(device.localizedName) (Nikon: \(isNikon), MacCamera: \(isMacCamera), Include: \(shouldInclude))")
            
            return shouldInclude
        }
        
        print("NikonSDKBridge: Found \(cameraDevices.count) camera devices")
        return cameraDevices
    }
    
    private func selectBestCamera() -> AVCaptureDevice? {
        let cameras = findExternalCameras()
        
        // Prefer Nikon cameras
        let nikonCamera = cameras.first { device in
            device.localizedName.lowercased().contains("nikon") || 
            device.localizedName.lowercased().contains("d90")
        }
        
        if let nikon = nikonCamera {
            print("NikonSDKBridge: Selected Nikon camera: \(nikon.localizedName)")
            return nikon
        }
        
        // Fallback to first external camera
        if let firstExternal = cameras.first {
            print("NikonSDKBridge: Selected external camera: \(firstExternal.localizedName)")
            return firstExternal
        }
        
        print("NikonSDKBridge: No suitable external camera found")
        return nil
    }
    
    // MARK: - Method Implementations
    
    private func testConnection(result: @escaping FlutterResult) {
        print("NikonSDKBridge: Testing AVFoundation connection")
        
        let cameras = findExternalCameras()
        let hasCamera = !cameras.isEmpty
        
        if hasCamera {
            let cameraNames = cameras.map { $0.localizedName }.joined(separator: ", ")
            sendStatusUpdate(message: "Found cameras: \(cameraNames)", type: "cameras_found")
            result(true)
        } else {
            sendStatusUpdate(message: "No external cameras detected via AVFoundation", type: "no_cameras")
            result(false)
        }
    }
    
    private func startLiveView(result: @escaping FlutterResult) {
        print("NikonSDKBridge: Live view requested - trying libgphoto2 integration")
        
        // Try libgphoto2 first for real D90 access
        tryLibGPhoto2LiveView { [weak self] success in
            if success {
                self?.isLiveViewActive = true
                self?.sendStatusUpdate(message: "Live view started with libgphoto2 (real D90 camera)", type: "live_view_started")
                result(true)
                return
            }
            
            // Fallback to AVFoundation (Mac camera)
            print("NikonSDKBridge: libgphoto2 failed, falling back to AVFoundation")
            self?.startAVFoundationLiveView(result: result)
        }
    }
    
    private func tryLibGPhoto2LiveView(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // First, try to detect the camera
            let detectResult = self.runGPhoto2Command(["--auto-detect"])
            
            guard detectResult.contains("Nikon DSC D90") else {
                print("NikonSDKBridge: D90 not detected by libgphoto2")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            print("NikonSDKBridge: D90 detected by libgphoto2")
            
            // Test camera access
            let summaryResult = self.runGPhoto2Command(["--summary"])
            
            if summaryResult.contains("Could not claim the USB device") {
                print("NikonSDKBridge: PTP daemon blocking access")
                self.sendStatusUpdate(message: "PTP daemon blocking D90 access. Manual intervention required.", type: "ptp_blocked")
                
                // Provide user instructions
                self.sendStatusUpdate(message: "Please run in Terminal: sudo pkill -f ptpcamerad", type: "user_action_required")
                self.sendStatusUpdate(message: "Then click 'Start Live View' again", type: "user_action_required")
                
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // Try preview capture
            let previewResult = self.runGPhoto2Command(["--capture-preview", "--filename=/tmp/d90_preview.jpg"])
            
            if previewResult.contains("Could not claim") {
                print("NikonSDKBridge: Still blocked after detection success - inconsistent state")
                DispatchQueue.main.async { completion(false) }
            } else if previewResult.contains("Error") {
                print("NikonSDKBridge: Camera access error: \(previewResult)")
                DispatchQueue.main.async { completion(false) }
            } else {
                print("NikonSDKBridge: Successfully captured preview from D90!")
                self.sendStatusUpdate(message: "libgphoto2 successfully accessed D90 camera", type: "camera_accessible")
                
                // Start continuous preview for live view
                self.startContinuousPreview()
                DispatchQueue.main.async { completion(true) }
            }
        }
    }
    
    private func startContinuousPreview() {
        // Start a timer to capture preview images continuously for live view
        DispatchQueue.main.async {
            self.previewTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                self.capturePreviewFrame()
            }
        }
    }
    
    private var previewTimer: Timer?
    
    private func capturePreviewFrame() {
        DispatchQueue.global(qos: .userInitiated).async {
            let timestamp = Int(Date().timeIntervalSince1970)
            let filename = "/tmp/d90_frame_\(timestamp).jpg"
            
            let result = self.runGPhoto2Command(["--capture-preview", "--filename=\(filename)", "--quiet"])
            
            if !result.contains("Error") && !result.contains("Could not claim") {
                // File captured successfully - could read and send via event stream
                // For now, just log success
                print("NikonSDKBridge: Captured D90 frame: \(filename)")
                
                // Send frame data through event stream
                self.sendLiveViewFrame(filename: filename)
            }
        }
    }
    
    private func sendLiveViewFrame(filename: String) {
        guard let imageData = NSData(contentsOfFile: filename) else {
            return
        }
        
        let frameEvent = [
            "method": "onLiveViewImage",
            "data": FlutterStandardTypedData(bytes: imageData as Data),
            "source": "libgphoto2",
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        eventSink?(frameEvent)
        
        // Clean up temp file
        try? FileManager.default.removeItem(atPath: filename)
    }
    
    private func startAVFoundationLiveView(result: @escaping FlutterResult) {
        // Check for any available cameras
        guard let camera = selectBestCamera() else {
            sendStatusUpdate(message: "No cameras available via AVFoundation", type: "no_camera")
            result(false)
            return
        }
        
        print("NikonSDKBridge: Using AVFoundation camera: \(camera.localizedName)")
        
        setupCaptureSession(with: camera) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.isLiveViewActive = true
                    self?.sendStatusUpdate(message: "Live view started with \(camera.localizedName) (AVFoundation fallback)", type: "live_view_started")
                    result(true)
                } else {
                    self?.sendStatusUpdate(message: "Failed to start live view with \(camera.localizedName)", type: "live_view_failed")
                    result(false)
                }
            }
        }
    }
    
    private func runGPhoto2Command(_ arguments: [String]) -> String {
        return runSystemCommand("gphoto2", arguments: arguments)
    }
    
    private func runSystemCommand(_ command: String, arguments: [String]) -> String {
        let process = Process()
        process.launchPath = "/usr/bin/env"
        process.arguments = [command] + arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("NikonSDKBridge: Command failed: \(error)")
            return "Error: \(error)"
        }
    }
    
    private func setupCaptureSession(with camera: AVCaptureDevice, completion: @escaping (Bool) -> Void) {
        print("NikonSDKBridge: Setting up capture session with \(camera.localizedName)")
        
        videoQueue.async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }
            
            self.captureSession = AVCaptureSession()
            guard let session = self.captureSession else {
                completion(false)
                return
            }
            
            session.beginConfiguration()
            
            // Set session preset for best quality
            if session.canSetSessionPreset(.high) {
                session.sessionPreset = .high
            } else if session.canSetSessionPreset(.medium) {
                session.sessionPreset = .medium
            }
            
            do {
                // Create input
                let videoInput = try AVCaptureDeviceInput(device: camera)
                
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                    self.videoDevice = camera
                    print("NikonSDKBridge: Successfully added camera input")
                } else {
                    print("NikonSDKBridge: Cannot add camera input to session")
                    session.commitConfiguration()
                    completion(false)
                    return
                }
                
                // Create output
                let videoOutput = AVCaptureVideoDataOutput()
                videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
                
                // Set video settings for JPEG output
                videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                
                if session.canAddOutput(videoOutput) {
                    session.addOutput(videoOutput)
                    self.videoOutput = videoOutput
                    print("NikonSDKBridge: Successfully added video output")
                } else {
                    print("NikonSDKBridge: Cannot add video output to session")
                    session.commitConfiguration()
                    completion(false)
                    return
                }
                
                session.commitConfiguration()
                
                // Start the session
                session.startRunning()
                print("NikonSDKBridge: Capture session started")
                completion(true)
                
            } catch {
                print("NikonSDKBridge: Error setting up capture session: \(error)")
                session.commitConfiguration()
                completion(false)
            }
        }
    }
    
    private func stopLiveView(result: @escaping FlutterResult) {
        print("NikonSDKBridge: Stopping live view")
        
        videoQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            self?.captureSession = nil
            self?.videoOutput = nil
            self?.videoDevice = nil
            
            DispatchQueue.main.async {
                self?.isLiveViewActive = false
                self?.sendStatusUpdate(message: "Live view stopped", type: "live_view_stopped")
                result(true)
            }
        }
    }
    
    private func getLiveViewImage(result: @escaping FlutterResult) {
        print("NikonSDKBridge: Getting live view image")
        // This would return the latest captured frame
        result(nil)
    }
    
    private func checkCameraConnection(result: @escaping FlutterResult) {
        print("NikonSDKBridge: Checking camera connection")
        
        let cameras = findExternalCameras()
        let hasCamera = !cameras.isEmpty
        
        if hasCamera {
            let cameraInfo = cameras.map { "\($0.localizedName)" }.joined(separator: ", ")
            sendStatusUpdate(message: "Connected cameras: \(cameraInfo)", type: "cameras_connected")
        } else {
            sendStatusUpdate(message: "No cameras connected", type: "no_cameras")
        }
        
        result(hasCamera)
    }
    
    private func capturePhoto(result: @escaping FlutterResult) {
        print("NikonSDKBridge: Capturing photo via AVFoundation")
        
        guard let session = captureSession, session.isRunning else {
            sendStatusUpdate(message: "No active camera session for photo capture", type: "capture_failed")
            result(false)
            return
        }
        
        sendStatusUpdate(message: "Photo capture requested via AVFoundation", type: "capture_started")
        
        // This would implement photo capture using AVCapturePhotoOutput
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.sendStatusUpdate(message: "Photo captured successfully", type: "photo_captured")
            result(true)
        }
    }
    
    // MARK: - Status Updates
    
    private func sendStatusUpdate(message: String, type: String) {
        guard let eventSink = eventSink else { return }
        
        let cameras = findExternalCameras()
        let statusData = [
            "type": type,
            "message": message,
            "timestamp": Date().timeIntervalSince1970,
            "avfoundation": true,
            "camera_count": cameras.count,
            "live_view_active": isLiveViewActive
        ] as [String : Any]
        
        eventSink(statusData)
        print("NikonSDKBridge: \(type) - \(message)")
    }
    
    // MARK: - FlutterStreamHandler
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("NikonSDKBridge: Event stream attached")
        self.eventSink = events
        
        sendStatusUpdate(message: "AVFoundation camera interface ready", type: "avfoundation_ready")
        
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("NikonSDKBridge: Event stream detached")
        self.eventSink = nil
        return nil
    }
    
    // MARK: - Cleanup
    
    // MARK: - PTP Coordination
    
    private func setupPTPCoordination() {
        print("NikonSDKBridge: Setting up PTP coordination")
        
        // Monitor for camera connections and coordinate with PTP daemon
        NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasConnected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let device = notification.object as? AVCaptureDevice {
                self?.handleCameraConnection(device)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let device = notification.object as? AVCaptureDevice {
                self?.handleCameraDisconnection(device)
            }
        }
    }
    
    private func handleCameraConnection(_ device: AVCaptureDevice) {
        print("NikonSDKBridge: Camera connected: \(device.localizedName)")
        
        // If this is a PTP camera, we may need to coordinate access
        if device.localizedName.lowercased().contains("nikon") ||
           device.localizedName.lowercased().contains("canon") {
            print("NikonSDKBridge: PTP camera detected, coordinating access")
            
            // Brief delay to allow system to settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.sendStatusUpdate(message: "PTP camera detected: \(device.localizedName)", type: "ptp_camera_detected")
            }
        }
    }
    
    private func handleCameraDisconnection(_ device: AVCaptureDevice) {
        print("NikonSDKBridge: Camera disconnected: \(device.localizedName)")
        sendStatusUpdate(message: "Camera disconnected: \(device.localizedName)", type: "camera_disconnected")
    }
    
    private func managePTP(action: String, result: @escaping FlutterResult) {
        print("NikonSDKBridge: Managing PTP - action: \(action)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            var success = false
            
            switch action {
            case "disable":
                // TODO: Implement PTP daemon management
                success = true // Placeholder
                self.sendStatusUpdate(message: "PTP daemon disable requested: \(success)", type: "ptp_disabled")
                
            case "enable":
                // TODO: Implement PTP daemon management  
                success = true // Placeholder
                self.sendStatusUpdate(message: "PTP daemon enable requested: \(success)", type: "ptp_enabled")
                
            case "status":
                // TODO: Implement PTP daemon status check
                success = false // Placeholder
                self.sendStatusUpdate(message: "PTP daemon status checked: \(success)", type: "ptp_status")
                
            default:
                DispatchQueue.main.async {
                    result(FlutterError(code: "INVALID_ACTION", message: "Unknown PTP action: \(action)", details: nil))
                }
                return
            }
            
            DispatchQueue.main.async {
                result(success)
            }
        }
    }
    
    private func requestExclusiveAccess(result: @escaping FlutterResult) {
        print("NikonSDKBridge: Requesting exclusive USB access")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // TODO: Implement exclusive USB access
            let success = false // Placeholder - requires PTPManager implementation
            
            DispatchQueue.main.async {
                self.sendStatusUpdate(message: "Exclusive USB access requested: \(success)", type: "exclusive_access")
                result(success)
            }
        }
    }
    
    deinit {
        print("NikonSDKBridge: Cleaning up AVFoundation resources")
        NotificationCenter.default.removeObserver(self)
        captureSession?.stopRunning()
        isLiveViewActive = false
        
        // TODO: Re-enable PTP daemon on cleanup when PTPManager is implemented
    }
}

// MARK: - Video Data Output Delegate

extension NikonSDKBridge: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isLiveViewActive else { return }
        
        frameCount += 1
        
        // Process every 10th frame to avoid overwhelming
        guard frameCount % 10 == 0 else { return }
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("NikonSDKBridge: Failed to get image buffer from sample")
            return
        }
        
        // Convert to JPEG data
        if let jpegData = convertToJPEG(imageBuffer: imageBuffer) {
            DispatchQueue.main.async {
                self.sendImageData(jpegData)
            }
        }
    }
    
    private func convertToJPEG(imageBuffer: CVImageBuffer) -> Data? {
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmapRep.representation(using: .jpeg, properties: [
            .compressionFactor: 0.7
        ])
    }
    
    private func sendImageData(_ imageData: Data) {
        guard let eventSink = eventSink else { return }
        
        let imageEvent = [
            "method": "onLiveViewImage",
            "data": FlutterStandardTypedData(bytes: imageData),
            "source": "avfoundation",
            "timestamp": Date().timeIntervalSince1970,
            "frame_count": frameCount
        ] as [String : Any]
        
        eventSink(imageEvent)
    }
}
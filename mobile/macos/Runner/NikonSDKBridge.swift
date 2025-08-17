import Cocoa
import FlutterMacOS

/// Direct libgphoto2 integration for real camera control
class NikonSDKBridge: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    private var liveViewTimer: Timer?
    private var isLiveViewActive = false
    
    // libgphoto2 camera handle
    private var cameraHandle = GPhoto2Camera()
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "nikon_sdk_bridge", binaryMessenger: registrar.messenger)
        let eventChannel = FlutterEventChannel(name: "nikon_sdk_events", binaryMessenger: registrar.messenger)
        
        let instance = NikonSDKBridge()
        instance.methodChannel = methodChannel
        instance.eventChannel = eventChannel
        
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("NikonSDKBridge: Received method call: \(call.method)")
        
        switch call.method {
        case "test":
            print("NikonSDKBridge: Test method called successfully")
            result(true)
        case "startLiveView":
            startLiveView(result: result)
        case "stopLiveView":
            stopLiveView(result: result)
        case "getLiveViewImage":
            getLiveViewImage(result: result)
        case "isCameraConnected":
            checkCameraConnection(result: result)
        default:
            print("NikonSDKBridge: Unknown method: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startLiveView(result: @escaping FlutterResult) {
        print("NikonSDKBridge: Starting D90 live view with libgphoto2 library")
        
        // Initialize camera connection if not already connected
        if cameraHandle.is_connected == 0 {
            let initResult = gp2_init_camera(&cameraHandle)
            if initResult != 0 {
                print("NikonSDKBridge: Failed to initialize camera: \(initResult)")
                result(false)
                return
            }
            print("NikonSDKBridge: Camera initialized successfully")
        }
        
        // Start live view
        let liveViewResult = gp2_start_liveview(&cameraHandle)
        if liveViewResult != 0 {
            print("NikonSDKBridge: Failed to start live view: \(liveViewResult)")
            result(false)
            return
        }
        
        print("NikonSDKBridge: D90 live view started, beginning frame streaming")
        isLiveViewActive = true
        
        // Start periodic live view image streaming from libgphoto2
        liveViewTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.streamRealLiveViewImage()
        }
        
        result(true)
    }
    
    private func stopLiveView(result: @escaping FlutterResult) {
        print("NikonSDKBridge: Stopping live view")
        
        isLiveViewActive = false
        liveViewTimer?.invalidate()
        liveViewTimer = nil
        
        let stopResult = gp2_stop_liveview(&cameraHandle)
        if stopResult != 0 {
            print("NikonSDKBridge: Warning - failed to stop live view cleanly: \(stopResult)")
        }
        
        result(true)
    }
    
    private func getLiveViewImage(result: @escaping FlutterResult) {
        // For streaming, we use the event channel instead
        let mockImageData = generateMockJPEGData()
        result(mockImageData)
    }
    
    private func checkCameraConnection(result: @escaping FlutterResult) {
        print("NikonSDKBridge: Testing Swift-to-C bridge...")
        
        // First test the bridge without any libgphoto2 calls
        let testResult = gp2_test_bridge()
        print("NikonSDKBridge: Bridge test result: \(testResult)")
        
        if testResult == 42 {
            print("NikonSDKBridge: Swift-to-C bridge works! Now testing libgphoto2...")
            
            // Test camera detection using libgphoto2 library
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            
            let detectResult = gp2_detect_cameras(buffer, Int32(bufferSize))
            let cameraList = String(cString: buffer)
            
            print("NikonSDKBridge: Camera detection result: \(detectResult), cameras: \(cameraList)")
            
            let isConnected = detectResult > 0 && (cameraList.contains("Nikon") || cameraList.contains("usb:detected"))
            result(isConnected)
        } else {
            print("NikonSDKBridge: Swift-to-C bridge FAILED! Expected 42, got \(testResult)")
            result(false)
        }
    }
    
    // MARK: - FlutterStreamHandler
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("NikonSDKBridge: Event stream listener attached")
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("NikonSDKBridge: Event stream listener cancelled")
        self.eventSink = nil
        return nil
    }
    
    /// Stream REAL live view image from Nikon D90 using libgphoto2 library
    private func streamRealLiveViewImage() {
        guard isLiveViewActive, let eventSink = eventSink else { return }
        
        // Capture preview from real camera using libgphoto2 library
        var imageData: UnsafeMutablePointer<UInt8>?
        var imageSize: UInt = 0
        
        let captureResult = gp2_capture_preview(&cameraHandle, &imageData, &imageSize)
        
        if captureResult == 0, let data = imageData, imageSize > 0 {
            // Successfully captured real image from D90
            let imageBytes = Data(bytes: data, count: Int(imageSize))
            print("NikonSDKBridge: Captured REAL D90 frame (\(imageSize) bytes)")
            
            // Send real camera data to Flutter
            eventSink([
                "method": "onLiveViewImage",
                "data": FlutterStandardTypedData(bytes: imageBytes)
            ])
            
            // Free the allocated image data
            free(data)
        } else {
            // Failed to capture real image - report error instead of fallback
            print("NikonSDKBridge: FAILED to capture real D90 frame (error: \(captureResult))")
            eventSink([
                "method": "onLiveViewError",
                "error": "Failed to capture preview from D90 (error: \(captureResult))"
            ])
        }
    }
    
    /// Generate mock JPEG data as fallback
    private func generateMockJPEGData() -> FlutterStandardTypedData {
        // Create a simple but valid mock image (320x240 for better performance)
        let width = 320
        let height = 240
        let bytesPerPixel = 4 // RGBA
        
        let imageSize = CGSize(width: width, height: height)  
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            print("NikonSDKBridge: Failed to create CGContext")
            return FlutterStandardTypedData(bytes: Data())
        }
        
        // Create a simple animated background
        let time = Date().timeIntervalSince1970
        let phase = Int(time) % 3
        
        // Set background color based on phase
        let bgColor: CGColor
        switch phase {
        case 0:
            bgColor = CGColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 1.0) // Blue-ish
        case 1:
            bgColor = CGColor(red: 0.4, green: 0.3, blue: 0.3, alpha: 1.0) // Red-ish  
        default:
            bgColor = CGColor(red: 0.3, green: 0.4, blue: 0.3, alpha: 1.0) // Green-ish
        }
        
        context.setFillColor(bgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Add a moving focus indicator
        context.setStrokeColor(CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.8))
        context.setLineWidth(2.0)
        
        let focusX = width/2 + Int(30 * sin(time * 1.5))
        let focusY = height/2 + Int(20 * cos(time * 1.2))
        let focusSize = 30
        
        context.strokeEllipse(in: CGRect(
            x: focusX - focusSize/2,
            y: focusY - focusSize/2,
            width: focusSize,
            height: focusSize
        ))
        
        // Add "ENHANCED MOCK" text
        let textAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 12)
        ]
        let text = "ENHANCED MOCK LIVE VIEW"
        let textSize = text.size(withAttributes: textAttrs)
        let textRect = CGRect(x: (width - Int(textSize.width))/2, y: 20, width: Int(textSize.width), height: Int(textSize.height))
        
        // Convert to JPEG
        guard let cgImage = context.makeImage() else {
            print("NikonSDKBridge: Failed to create CGImage") 
            return FlutterStandardTypedData(bytes: Data())
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: imageSize)
        
        // Draw text on NSImage
        nsImage.lockFocus()
        text.draw(in: textRect, withAttributes: textAttrs)
        nsImage.unlockFocus()
        
        guard let tiffData = nsImage.tiffRepresentation,
              let imageRep = NSBitmapImageRep(data: tiffData),
              let jpegData = imageRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            print("NikonSDKBridge: Failed to create JPEG data")
            return FlutterStandardTypedData(bytes: Data())
        }
        
        print("NikonSDKBridge: Generated mock JPEG frame (\(jpegData.count) bytes, phase: \(phase))")
        return FlutterStandardTypedData(bytes: jpegData)
    }
    
    deinit {
        // Clean up camera resources
        if cameraHandle.is_connected != 0 {
            gp2_cleanup_camera(&cameraHandle)
        }
        print("NikonSDKBridge: Cleanup completed")
    }
}
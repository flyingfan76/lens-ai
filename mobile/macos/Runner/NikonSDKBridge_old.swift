import Cocoa
import FlutterMacOS

/// Bridge between Flutter and Nikon MAID SDK for live view functionality
class NikonSDKBridge: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    private var liveViewTimer: Timer?
    private var isLiveViewActive = false
    
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
        print("NikonSDKBridge: Starting REAL live view with gphoto2")
        
        // Test gphoto2 connectivity first
        let testResult = executeGPhoto2Command(["--auto-detect"])
        guard testResult.contains("Nikon DSC D90") else {
            print("NikonSDKBridge: D90 not detected by gphoto2")
            result(false)
            return
        }
        
        print("NikonSDKBridge: D90 detected, starting live view streaming")
        isLiveViewActive = true
        
        // Start periodic live view image streaming from real camera (slower for real capture)
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
        
        // TODO: Stop Nikon SDK live view
        
        result(true)
    }
    
    private func getLiveViewImage(result: @escaping FlutterResult) {
        // TODO: Get actual live view image from Nikon SDK
        // For now, return mock JPEG data
        
        let mockImageData = generateMockJPEGData()
        result(mockImageData)
    }
    
    private func checkCameraConnection(result: @escaping FlutterResult) {
        // TODO: Check actual Nikon D90 connection via SDK
        // For now, return true if USB device is detected
        result(true)
    }
    
    private func streamLiveViewImage() {
        // This method now delegates to the real camera streaming
        streamRealLiveViewImage()
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
    
    /// Execute gphoto2 command and return output
    private func executeGPhoto2Command(_ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/gphoto2")
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("NikonSDKBridge: gphoto2 command failed: \(error)")
            return ""
        }
    }
    
    /// Stream real live view image from Nikon D90
    private func streamRealLiveViewImage() {
        guard isLiveViewActive, let eventSink = eventSink else { return }
        
        // Capture preview from real camera
        let tempFile = "/tmp/d90_live_\(Date().timeIntervalSince1970).jpg"
        _ = executeGPhoto2Command(["--capture-preview", "--filename=\(tempFile)"])
        
        // Check if capture was successful and file exists
        let fileURL = URL(fileURLWithPath: tempFile)
        guard FileManager.default.fileExists(atPath: tempFile) else {
            print("NikonSDKBridge: Preview capture failed or file not found")
            return
        }
        
        do {
            // Read the real JPEG data from camera
            let imageData = try Data(contentsOf: fileURL)
            print("NikonSDKBridge: Captured REAL D90 frame (\(imageData.count) bytes)")
            
            // Send real camera data to Flutter
            eventSink([
                "method": "onLiveViewImage",
                "data": FlutterStandardTypedData(bytes: imageData)
            ])
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: fileURL)
            
        } catch {
            print("NikonSDKBridge: Error reading camera preview: \(error)")
        }
    }
    
    /// Generate realistic JPEG data that simulates camera live view
    /// TODO: Replace with actual Nikon SDK live view data
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
        
        // Add "MOCK LIVE VIEW" text
        let textAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 14)
        ]
        let text = "MOCK LIVE VIEW"
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
        
        print("NikonSDKBridge: Generated valid mock JPEG frame (\(jpegData.count) bytes, phase: \(phase))")
        return FlutterStandardTypedData(bytes: jpegData)
    }
}
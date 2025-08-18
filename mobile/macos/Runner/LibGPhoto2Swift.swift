import Cocoa
import FlutterMacOS
import Foundation

/// Complete Swift bridge for libgphoto2 C library
public class LibGPhoto2Swift: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var liveViewTimer: Timer?
    
    // C functions are now available via bridging header
    
    // Plugin registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        print("LibGPhoto2Swift: Registering complete libgphoto2 bridge")
        let methodChannel = FlutterMethodChannel(name: "libgphoto2_bridge", binaryMessenger: registrar.messenger)
        let eventChannel = FlutterEventChannel(name: "libgphoto2_events", binaryMessenger: registrar.messenger)
        let instance = LibGPhoto2Swift()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }
    
    // Method call handling
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("LibGPhoto2Swift: Method call: \(call.method)")
        
        switch call.method {
        case "initialize":
            initialize(result: result)
        case "detectCameras":
            detectCameras(result: result)
        case "connect":
            connect(result: result)
        case "disconnect":
            disconnect(result: result)
        case "isConnected":
            checkConnection(result: result)
        case "startLiveView":
            startLiveView(result: result)
        case "stopLiveView":
            stopLiveView(result: result)
        case "capturePhoto":
            capturePhoto(result: result)
        case "setSetting":
            if let args = call.arguments as? [String: Any],
               let settingName = args["settingName"] as? String,
               let value = args["value"] as? String {
                setSetting(settingName: settingName, value: value, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing settingName or value", details: nil))
            }
        case "getSetting":
            if let args = call.arguments as? [String: Any],
               let settingName = args["settingName"] as? String {
                getSetting(settingName: settingName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing settingName", details: nil))
            }
        case "getSettingChoices":
            if let args = call.arguments as? [String: Any],
               let settingName = args["settingName"] as? String {
                getSettingChoices(settingName: settingName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing settingName", details: nil))
            }
        case "downloadFile":
            if let args = call.arguments as? [String: Any],
               let folder = args["folder"] as? String,
               let filename = args["filename"] as? String {
                downloadFile(folder: folder, filename: filename, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing folder or filename", details: nil))
            }
        default:
            print("LibGPhoto2Swift: Unknown method: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Implementation Methods
    
    private func initialize(result: @escaping FlutterResult) {
        print("LibGPhoto2Swift: Initializing libgphoto2")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let ret = gphoto2_init()
            
            DispatchQueue.main.async {
                if ret == 0 {
                    self.sendStatusUpdate(message: "libgphoto2 initialized successfully", type: "initialized")
                    result(true)
                } else {
                    let error = String(cString: gphoto2_get_last_error())
                    self.sendStatusUpdate(message: "Initialization failed: \(error)", type: "init_failed")
                    result(FlutterError(code: "INIT_FAILED", message: error, details: nil))
                }
            }
        }
    }
    
    private func detectCameras(result: @escaping FlutterResult) {
        print("LibGPhoto2Swift: Detecting cameras")
        
        DispatchQueue.global(qos: .userInitiated).async {
            var camera_list: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
            var count: Int32 = 0
            
            let ret = gphoto2_detect_cameras(&camera_list, &count)
            
            DispatchQueue.main.async {
                if ret >= 0 && count > 0 {
                    var cameras: [[String: Any]] = []
                    
                    for i in 0..<Int(count) {
                        if let cameraInfo = camera_list?[i] {
                            let cameraString = String(cString: cameraInfo)
                            cameras.append([
                                "id": "gphoto2_\(i)",
                                "name": cameraString,
                                "port": "detected",
                                "driver": "libgphoto2"
                            ])
                        }
                    }
                    
                    // Cleanup
                    gphoto2_free_string_array(camera_list, count)
                    
                    self.sendStatusUpdate(message: "Found \(count) cameras", type: "cameras_detected")
                    result(cameras)
                } else {
                    let error = String(cString: gphoto2_get_last_error())
                    self.sendStatusUpdate(message: "No cameras detected: \(error)", type: "no_cameras")
                    result([])
                }
            }
        }
    }
    
    private func connect(result: @escaping FlutterResult) {
        print("LibGPhoto2Swift: Connecting to camera")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let ret = gphoto2_connect()
            
            DispatchQueue.main.async {
                if ret == 0 {
                    self.sendStatusUpdate(message: "Camera connected successfully", type: "connected")
                    result(true)
                } else {
                    let error = String(cString: gphoto2_get_last_error())
                    self.sendStatusUpdate(message: "Connection failed: \(error)", type: "connection_failed")
                    result(FlutterError(code: "CONNECTION_FAILED", message: error, details: nil))
                }
            }
        }
    }
    
    private func disconnect(result: @escaping FlutterResult) {
        print("LibGPhoto2Swift: Disconnecting from camera")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let ret = gphoto2_disconnect()
            
            DispatchQueue.main.async {
                if ret == 0 {
                    self.sendStatusUpdate(message: "Camera disconnected", type: "disconnected")
                    result(true)
                } else {
                    let error = String(cString: gphoto2_get_last_error())
                    result(FlutterError(code: "DISCONNECT_FAILED", message: error, details: nil))
                }
            }
        }
    }
    
    private func checkConnection(result: @escaping FlutterResult) {
        let connected = gphoto2_is_connected() != 0
        result(connected)
    }
    
    private func startLiveView(result: @escaping FlutterResult) {
        print("LibGPhoto2Swift: Starting live view")
        
        // Set up live view callback
        let callback: @convention(c) (UnsafeMutablePointer<UInt8>?, UInt) -> Void = { data, size in
            guard let data = data, size > 0 else { 
                print("LibGPhoto2Swift: Live view callback - no data or zero size")
                return 
            }
            
            print("LibGPhoto2Swift: Live view callback - received \(size) bytes")
            
            // Convert to Data and send via event sink
            let imageData = Data(bytes: data, count: Int(size))
            
            DispatchQueue.main.async {
                if let instance = LibGPhoto2Swift.shared {
                    print("LibGPhoto2Swift: Sending live view frame to Flutter")
                    instance.sendLiveViewFrame(imageData)
                } else {
                    print("LibGPhoto2Swift: No instance available for live view frame")
                }
            }
            
            // Free the data (C library allocated it for us)
            // Note: C code handles memory management
        }
        
        gphoto2_set_live_view_callback(callback)
        
        DispatchQueue.global(qos: .userInitiated).async {
            let ret = gphoto2_start_live_view()
            
            DispatchQueue.main.async {
                if ret == 0 {
                    self.sendStatusUpdate(message: "Live view started", type: "live_view_started")
                    result(true)
                } else {
                    let error = String(cString: gphoto2_get_last_error())
                    self.sendStatusUpdate(message: "Live view failed: \(error)", type: "live_view_failed")
                    result(FlutterError(code: "LIVE_VIEW_FAILED", message: error, details: nil))
                }
            }
        }
    }
    
    private func stopLiveView(result: @escaping FlutterResult) {
        print("LibGPhoto2Swift: Stopping live view")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let ret = gphoto2_stop_live_view()
            
            DispatchQueue.main.async {
                if ret == 0 {
                    self.sendStatusUpdate(message: "Live view stopped", type: "live_view_stopped")
                    result(true)
                } else {
                    let error = String(cString: gphoto2_get_last_error())
                    result(FlutterError(code: "STOP_LIVE_VIEW_FAILED", message: error, details: nil))
                }
            }
        }
    }
    
    private func capturePhoto(result: @escaping FlutterResult) {
        print("LibGPhoto2Swift: Capturing photo")
        
        DispatchQueue.global(qos: .userInitiated).async {
            var filename: UnsafeMutablePointer<CChar>?
            var filepath: UnsafeMutablePointer<CChar>?
            
            let ret = gphoto2_capture_photo(&filename, &filepath)
            
            DispatchQueue.main.async {
                if ret == 0, let filename = filename, let filepath = filepath {
                    let filenameStr = String(cString: filename)
                    let filepathStr = String(cString: filepath)
                    
                    // Free C strings
                    gphoto2_free_string(filename)
                    gphoto2_free_string(filepath)
                    
                    let photoInfo = [
                        "filename": filenameStr,
                        "filepath": filepathStr
                    ]
                    
                    self.sendStatusUpdate(message: "Photo captured: \(filenameStr)", type: "photo_captured")
                    result(photoInfo)
                } else {
                    let error = String(cString: gphoto2_get_last_error())
                    self.sendStatusUpdate(message: "Capture failed: \(error)", type: "capture_failed")
                    result(FlutterError(code: "CAPTURE_FAILED", message: error, details: nil))
                }
            }
        }
    }
    
    private func setSetting(settingName: String, value: String, result: @escaping FlutterResult) {
        print("LibGPhoto2Swift: Setting \(settingName) = \(value)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let ret = settingName.withCString { namePtr in
                value.withCString { valuePtr in
                    gphoto2_set_setting(namePtr, valuePtr)
                }
            }
            
            DispatchQueue.main.async {
                if ret == 0 {
                    self.sendStatusUpdate(message: "Setting \(settingName) applied", type: "setting_applied")
                    result(true)
                } else {
                    let error = String(cString: gphoto2_get_last_error())
                    result(FlutterError(code: "SET_SETTING_FAILED", message: error, details: nil))
                }
            }
        }
    }
    
    private func getSetting(settingName: String, result: @escaping FlutterResult) {
        print("LibGPhoto2Swift: Getting setting \(settingName)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            var value: UnsafeMutablePointer<CChar>?
            
            let ret = settingName.withCString { namePtr in
                gphoto2_get_setting(namePtr, &value)
            }
            
            DispatchQueue.main.async {
                if ret == 0, let value = value {
                    let valueStr = String(cString: value)
                    gphoto2_free_string(value)
                    result(valueStr)
                } else {
                    let error = String(cString: gphoto2_get_last_error())
                    result(FlutterError(code: "GET_SETTING_FAILED", message: error, details: nil))
                }
            }
        }
    }
    
    private func getSettingChoices(settingName: String, result: @escaping FlutterResult) {
        print("LibGPhoto2Swift: Getting setting choices for \(settingName)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            var choices: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
            var choiceCount: Int32 = 0
            
            let ret = settingName.withCString { namePtr in
                gphoto2_get_setting_choices(namePtr, &choices, &choiceCount)
            }
            
            DispatchQueue.main.async {
                if ret >= 0 && choiceCount > 0 {
                    var choiceArray: [String] = []
                    
                    for i in 0..<Int(choiceCount) {
                        if let choice = choices?[i] {
                            choiceArray.append(String(cString: choice))
                        }
                    }
                    
                    // Cleanup
                    gphoto2_free_string_array(choices, choiceCount)
                    
                    result(choiceArray)
                } else {
                    result([])
                }
            }
        }
    }
    
    private func downloadFile(folder: String, filename: String, result: @escaping FlutterResult) {
        print("LibGPhoto2Swift: Downloading file \(folder)/\(filename)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            var data: UnsafeMutablePointer<UInt8>?
            var size: UInt = 0
            
            let ret = folder.withCString { folderPtr in
                filename.withCString { filenamePtr in
                    gphoto2_download_file(folderPtr, filenamePtr, &data, &size)
                }
            }
            
            DispatchQueue.main.async {
                if ret == 0, let data = data, size > 0 {
                    let imageData = Data(bytes: data, count: Int(size))
                    gphoto2_free_data(data)
                    
                    let flutterData = FlutterStandardTypedData(bytes: imageData)
                    result(flutterData)
                } else {
                    let error = String(cString: gphoto2_get_last_error())
                    result(FlutterError(code: "DOWNLOAD_FAILED", message: error, details: nil))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private static var shared: LibGPhoto2Swift?
    
    override init() {
        super.init()
        LibGPhoto2Swift.shared = self
    }
    
    private func sendStatusUpdate(message: String, type: String) {
        guard let eventSink = eventSink else { return }
        
        let statusData = [
            "type": type,
            "message": message,
            "timestamp": Date().timeIntervalSince1970,
            "driver": "libgphoto2",
            "connected": gphoto2_is_connected() != 0,
            "live_view_active": gphoto2_is_live_view_active() != 0
        ] as [String : Any]
        
        eventSink(statusData)
        print("LibGPhoto2Swift: \(type) - \(message)")
    }
    
    private func sendLiveViewFrame(_ imageData: Data) {
        guard let eventSink = eventSink else { return }
        
        let frameEvent = [
            "method": "onLiveViewImage",
            "data": FlutterStandardTypedData(bytes: imageData),
            "source": "libgphoto2",
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        eventSink(frameEvent)
    }
    
    // MARK: - FlutterStreamHandler
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("LibGPhoto2Swift: Event stream attached")
        self.eventSink = events
        sendStatusUpdate(message: "libgphoto2 bridge ready", type: "bridge_ready")
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("LibGPhoto2Swift: Event stream detached")
        self.eventSink = nil
        return nil
    }
    
    // MARK: - Cleanup
    
    deinit {
        print("LibGPhoto2Swift: Cleaning up")
        gphoto2_cleanup()
        LibGPhoto2Swift.shared = nil
    }
}
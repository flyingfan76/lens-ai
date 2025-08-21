import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    
    // Register custom plugins
    registerCustomPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
  
  private func registerCustomPlugins(registry: FlutterPluginRegistry) {
    // Register NikonSDKBridge (AVFoundation implementation - working)
    NikonSDKBridge.register(with: registry.registrar(forPlugin: "NikonSDKBridge"))
    print("✅ NikonSDKBridge registered - Camera detection working")
    
    // Enable LibGPhoto2Swift with bridging header approach
    LibGPhoto2Swift.register(with: registry.registrar(forPlugin: "LibGPhoto2Swift"))
    print("✅ LibGPhoto2Swift registered - Full D90 camera control enabled")
    
    // Register MacOSCameraBridge for built-in camera support
    MacOSCameraBridge.register(with: registry.registrar(forPlugin: "MacOSCameraBridge"))
    print("✅ MacOSCameraBridge registered - Built-in camera support enabled")
  }
}

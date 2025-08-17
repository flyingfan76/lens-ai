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
    // Register NikonSDKBridge
    NikonSDKBridge.register(with: registry.registrar(forPlugin: "NikonSDKBridge"))
    print("🚀 NikonSDKBridge registered in MainFlutterWindow")
  }
}

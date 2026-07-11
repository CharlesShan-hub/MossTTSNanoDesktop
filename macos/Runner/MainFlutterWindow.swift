import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 标题栏暗黑模式切换通道
    let channel = FlutterMethodChannel(
      name: "com.example.mossTtsNano/titlebar",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, _ in
      if call.method == "setAppearance",
         let args = call.arguments as? [String: Any],
         let dark = args["dark"] as? Bool {
        DispatchQueue.main.async {
          self?.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        }
      }
    }

    super.awakeFromNib()
  }
}

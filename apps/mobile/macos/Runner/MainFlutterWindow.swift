import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var privacyChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "app.letterwithin/privacy",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setScreenCoverEnabled",
            let enabled = call.arguments as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }
      UserDefaults.standard.set(enabled, forKey: "letter.screenCoverEnabled")
      result(nil)
    }
    privacyChannel = channel

    super.awakeFromNib()
  }
}

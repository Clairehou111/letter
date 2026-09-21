import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var privacyChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "LetterPrivacyBridge"
    ) else { return }
    let channel = FlutterMethodChannel(
      name: "app.letterwithin/privacy",
      binaryMessenger: registrar.messenger()
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
  }
}

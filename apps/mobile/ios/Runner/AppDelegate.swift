import Flutter
import UIKit

/// Owns the native privacy cover used for app-switcher snapshots and for the
/// TestFlight iOS app running on macOS. On macOS an iOS app can lose key-window
/// focus without transitioning to the iOS background, so scene lifecycle
/// callbacks alone are not sufficient.
final class LetterPrivacyCover {
  static let shared = LetterPrivacyCover()

  private let coverTag = 0x4C_57_43

  private init() {}

  private var isEnabled: Bool {
    let defaults = UserDefaults.standard
    return defaults.object(forKey: "letter.screenCoverEnabled") == nil
      ? true
      : defaults.bool(forKey: "letter.screenCoverEnabled")
  }

  func install(on window: UIWindow) {
    guard isEnabled else { return }
    guard window.viewWithTag(coverTag) == nil else {
      if let cover = window.viewWithTag(coverTag) {
        window.bringSubviewToFront(cover)
      }
      return
    }

    let cover = UIView(frame: window.bounds)
    cover.tag = coverTag
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.backgroundColor = UIColor(
      red: 247.0 / 255.0,
      green: 246.0 / 255.0,
      blue: 242.0 / 255.0,
      alpha: 1.0
    )
    cover.accessibilityLabel = "Letter Within privacy cover"

    let title = UILabel()
    title.translatesAutoresizingMaskIntoConstraints = false
    title.text = "Letter Within"
    title.textColor = UIColor(
      red: 37.0 / 255.0,
      green: 40.0 / 255.0,
      blue: 39.0 / 255.0,
      alpha: 1.0
    )
    title.font = UIFont.systemFont(ofSize: 30, weight: .semibold)
    cover.addSubview(title)
    NSLayoutConstraint.activate([
      title.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
      title.centerYAnchor.constraint(equalTo: cover.centerYAnchor),
    ])

    window.addSubview(cover)
    window.bringSubviewToFront(cover)
  }

  func remove(from window: UIWindow) {
    window.viewWithTag(coverTag)?.removeFromSuperview()
  }

  func install(in application: UIApplication) {
    for window in application.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap(\.windows)
    {
      install(on: window)
    }
  }

  func remove(in application: UIApplication) {
    for window in application.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap(\.windows)
    {
      remove(from: window)
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var privacyChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidResignKey(_:)),
      name: UIWindow.didResignKeyNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidBecomeKey(_:)),
      name: UIWindow.didBecomeKeyNotification,
      object: nil
    )
    return launched
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    LetterPrivacyCover.shared.install(in: application)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    LetterPrivacyCover.shared.remove(in: application)
  }

  @objc private func windowDidResignKey(_ notification: Notification) {
    guard let window = notification.object as? UIWindow else { return }
    LetterPrivacyCover.shared.install(on: window)
  }

  @objc private func windowDidBecomeKey(_ notification: Notification) {
    guard let window = notification.object as? UIWindow else { return }
    LetterPrivacyCover.shared.remove(from: window)
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

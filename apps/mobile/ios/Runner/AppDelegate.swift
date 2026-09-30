import Flutter
import Security
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
      switch call.method {
      case "setScreenCoverEnabled":
        guard let enabled = call.arguments as? Bool else {
          result(FlutterError(code: "invalid_argument", message: "Expected a boolean.", details: nil))
          return
        }
        UserDefaults.standard.set(enabled, forKey: "letter.screenCoverEnabled")
        result(nil)
      case "clearPosthogQueues":
        guard let projectToken = call.arguments as? String,
              projectToken.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else {
          result(FlutterError(code: "invalid_argument", message: "Invalid analytics project token.", details: nil))
          return
        }
        do {
          try self.clearPosthogStorage(projectToken: projectToken)
          result(nil)
        } catch {
          result(FlutterError(code: "analytics_cleanup_failed", message: "Could not clear pending analytics.", details: nil))
        }
      case "protectHealthStorage":
        do {
          try self.protectHealthStorage()
          result(nil)
        } catch {
          result(FlutterError(code: "health_storage_protection_failed", message: "Could not protect local health storage.", details: nil))
        }
      case "migrateHealthDatabaseKeyAccessibility":
        do {
          result(try self.migrateHealthDatabaseKeyAccessibility())
        } catch {
          result(FlutterError(code: "health_key_migration_failed", message: "Could not protect the local database key.", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    privacyChannel = channel
  }

  /// posthog-ios keeps event queues under Application Support even after
  /// optOut(), reset(), and close(). The Dart side closes the SDK first; this
  /// then removes only the exact project-token directory so queued events and
  /// cached analytics identity cannot reappear after a later opt-in.
  private func clearPosthogStorage(projectToken: String) throws {
    let fileManager = FileManager.default
    guard let support = fileManager.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first,
      let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
    let appDirectory = support.appendingPathComponent(
      bundleIdentifier,
      isDirectory: true
    ).standardizedFileURL
    let projectDirectory = appDirectory.appendingPathComponent(
      projectToken,
      isDirectory: true
    ).standardizedFileURL
    guard projectDirectory.deletingLastPathComponent() == appDirectory else {
      throw CocoaError(.fileWriteInvalidFileName)
    }
    if fileManager.fileExists(atPath: projectDirectory.path) {
      try fileManager.removeItem(at: projectDirectory)
    }
  }

  /// Health records are an encrypted local store, not an implicit iCloud or
  /// Finder backup. User-created encrypted backup/export files remain under
  /// the user's explicit control in Documents.
  private func protectHealthStorage() throws {
    let fileManager = FileManager.default
    guard let support = fileManager.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else { return }
    try fileManager.createDirectory(
      at: support,
      withIntermediateDirectories: true
    )
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var protectedURL = support
    try protectedURL.setResourceValues(values)
    try fileManager.setAttributes(
      [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
      ofItemAtPath: support.path
    )
  }

  /// Atomically upgrades the pre-2.0 database-key item so it cannot migrate
  /// to another device. Updating the accessibility attribute in place keeps
  /// the existing SQLCipher key and avoids a delete/recreate data-loss window.
  private func migrateHealthDatabaseKeyAccessibility() throws -> Bool {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrAccount: "letter.health_database.key.v1",
      kSecAttrService: "flutter_secure_storage_service",
    ]
    let attributes: [CFString: Any] = [
      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let status = SecItemUpdate(
      query as CFDictionary,
      attributes as CFDictionary
    )
    switch status {
    case errSecSuccess:
      return true
    case errSecItemNotFound:
      return false
    default:
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
  }
}

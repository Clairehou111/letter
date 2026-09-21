import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var privacyCovers: [ObjectIdentifier: NSView] = [:]

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidResignActive(_ notification: Notification) {
    super.applicationDidResignActive(notification)
    let defaults = UserDefaults.standard
    let enabled = defaults.object(forKey: "letter.screenCoverEnabled") == nil
      ? true
      : defaults.bool(forKey: "letter.screenCoverEnabled")
    guard enabled else { return }

    for window in NSApplication.shared.windows {
      guard let content = window.contentView else { continue }
      let id = ObjectIdentifier(window)
      guard privacyCovers[id] == nil else { continue }

      let cover = NSView(frame: content.bounds)
      cover.autoresizingMask = [.width, .height]
      cover.wantsLayer = true
      cover.layer?.backgroundColor = NSColor(
        red: 247.0 / 255.0,
        green: 246.0 / 255.0,
        blue: 242.0 / 255.0,
        alpha: 1.0
      ).cgColor

      let title = NSTextField(labelWithString: "Letter Within")
      title.translatesAutoresizingMaskIntoConstraints = false
      title.font = NSFont.systemFont(ofSize: 30, weight: .semibold)
      title.textColor = NSColor(
        red: 37.0 / 255.0,
        green: 40.0 / 255.0,
        blue: 39.0 / 255.0,
        alpha: 1.0
      )
      cover.addSubview(title)
      NSLayoutConstraint.activate([
        title.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
        title.centerYAnchor.constraint(equalTo: cover.centerYAnchor),
      ])

      content.addSubview(cover)
      privacyCovers[id] = cover
    }
  }

  override func applicationDidBecomeActive(_ notification: Notification) {
    super.applicationDidBecomeActive(notification)
    for cover in privacyCovers.values {
      cover.removeFromSuperview()
    }
    privacyCovers.removeAll()
  }
}

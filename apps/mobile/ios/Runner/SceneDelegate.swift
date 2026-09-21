import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var privacyCover: UIView?

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    let defaults = UserDefaults.standard
    let enabled = defaults.object(forKey: "letter.screenCoverEnabled") == nil
      ? true
      : defaults.bool(forKey: "letter.screenCoverEnabled")
    guard enabled else { return }
    guard privacyCover == nil, let window else { return }

    let cover = UIView(frame: window.bounds)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.backgroundColor = UIColor(
      red: 247.0 / 255.0,
      green: 246.0 / 255.0,
      blue: 242.0 / 255.0,
      alpha: 1.0
    )

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
    privacyCover = cover
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }

}

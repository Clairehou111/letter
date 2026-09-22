import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    guard let window else { return }
    LetterPrivacyCover.shared.install(on: window)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    guard let window else { return }
    LetterPrivacyCover.shared.remove(from: window)
  }
}

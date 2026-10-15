import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var privacyView: UIView?

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    guard privacyView == nil, let window = window else { return }
    let shield = UIView(frame: window.bounds)
    shield.backgroundColor = .systemBackground
    shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(shield)
    privacyView = shield
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    privacyView?.removeFromSuperview()
    privacyView = nil
  }
}

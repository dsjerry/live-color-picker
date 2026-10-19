import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "live_color_picker/share",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "sharePng" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard
          let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String
        else {
          result(
            FlutterError(
              code: "INVALID_PATH",
              message: "Missing PNG path",
              details: nil
            )
          )
          return
        }

        DispatchQueue.main.async {
          guard
            let self,
            let root = self.window?.rootViewController
          else {
            result(
              FlutterError(
                code: "NO_VIEW_CONTROLLER",
                message: "Unable to present the share sheet",
                details: nil
              )
            )
            return
          }
          var presenter = root
          while let presented = presenter.presentedViewController {
            presenter = presented
          }

          let shareController = UIActivityViewController(
            activityItems: [URL(fileURLWithPath: path)],
            applicationActivities: nil
          )
          if let popover = shareController.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
              x: presenter.view.bounds.midX,
              y: presenter.view.bounds.midY,
              width: 0,
              height: 0
            )
          }
          presenter.present(shareController, animated: true)
          result(nil)
        }
      }
    }

    return launched
  }
}

import Flutter
import UIKit
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    LiveActivityPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "LiveActivityPlugin")!)
  }
}

public class LiveActivityPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.realizealpha.live_activity",
      binaryMessenger: registrar.messenger()
    )
    let instance = LiveActivityPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if #available(iOS 16.1, *) {
      let manager = LiveActivityManager.shared
      switch call.method {
      case "areActivitiesEnabled":
        result(manager.areActivitiesEnabled())
      case "startLiveActivity":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Arguments must be a Map", details: nil))
          return
        }
        do {
          let activityId = try manager.startActivity(data: args)
          result(activityId)
        } catch {
          result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
        }
      case "updateLiveActivity":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Arguments must be a Map", details: nil))
          return
        }
        Task {
          await manager.updateActivity(data: args)
          result(nil)
        }
      case "endLiveActivity":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Arguments must be a Map", details: nil))
          return
        }
        let positionId = args["positionId"] as? String ?? ""
        let activityId = args["activityId"] as? String
        Task {
          await manager.endActivity(positionId: positionId, activityId: activityId)
          result(nil)
        }
      case "getActiveActivities":
        result(manager.getActiveActivities())
      default:
        result(FlutterMethodNotImplemented)
      }
    } else {
      if call.method == "areActivitiesEnabled" {
        result(false)
      } else {
        result(FlutterError(code: "UNSUPPORTED_OS", message: "iOS 16.1+ is required for Live Activities", details: nil))
      }
    }
  }
}

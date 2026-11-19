import Flutter
import UIKit
import ActivityKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    WorkmanagerPlugin.registerLaunchHandlers()
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.cidevelop.robinhoodOptionsMobile.agenticTrading"
    )
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    LiveActivityPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "LiveActivityPlugin")!)
    BackgroundExecutionPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "BackgroundExecutionPlugin")!)
  }
}

public class BackgroundExecutionPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.realizealpha.background_execution",
      binaryMessenger: registrar.messenger()
    )
    let instance = BackgroundExecutionPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformReadiness":
      let permittedIdentifiers = Bundle.main.object(
        forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers"
      ) as? [String] ?? []
      let backgroundModes = Bundle.main.object(
        forInfoDictionaryKey: "UIBackgroundModes"
      ) as? [String] ?? []
      let refreshStatus: String
      switch UIApplication.shared.backgroundRefreshStatus {
      case .available:
        refreshStatus = "available"
      case .denied:
        refreshStatus = "denied"
      case .restricted:
        refreshStatus = "restricted"
      @unknown default:
        refreshStatus = "unknown"
      }
      result([
        "platform": "ios",
        "bgTaskIdentifierRegistered": permittedIdentifiers.contains(
          "com.cidevelop.robinhoodOptionsMobile.agenticTrading"
        ),
        "fetchModeEnabled": backgroundModes.contains("fetch"),
        "backgroundRefreshStatus": refreshStatus,
        "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
        "canOpenSettings": true,
      ])
    case "openBackgroundSettings":
      DispatchQueue.main.async {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { success in
          result(success)
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
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

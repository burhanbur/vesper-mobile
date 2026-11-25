import Flutter
import UIKit

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
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VesperStorageProtection") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "vesper/storage-protection", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "protect", let path = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        let manager = FileManager.default
        let support = try manager.url(
          for: .applicationSupportDirectory, in: .userDomainMask,
          appropriateFor: nil, create: true).resolvingSymlinksInPath()
        var directory = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        guard directory.standardizedFileURL == support.standardizedFileURL else {
          result(FlutterError(code: "invalid_path", message: "Invalid storage path", details: nil))
          return
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: path)
        for var file in try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
          where file.lastPathComponent.hasPrefix("vesper-") {
          try file.setResourceValues(values)
          try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path)
        }
        result(nil)
      } catch {
        result(FlutterError(code: "protection_failed", message: "Local data protection unavailable", details: nil))
      }
    }

    if let deviceRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "VesperDeviceInfo") {
      let deviceChannel = FlutterMethodChannel(
        name: "vesper/device_info", binaryMessenger: deviceRegistrar.messenger())
      deviceChannel.setMethodCallHandler { call, result in
        guard call.method == "getDeviceInfo" else {
          result(FlutterMethodNotImplemented)
          return
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
          $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(validatingUTF8: $0) ?? ""
          }
        }
        let device = UIDevice.current
        result([
          "deviceName": device.name,
          "manufacturer": "Apple",
          "brand": "Apple",
          "model": machine.isEmpty ? device.model : machine,
          "fallbackModel": device.model,
          "osVersion": device.systemVersion,
          "isEmulator": machine == "x86_64" || machine == "arm64",
        ])
      }
    }
  }
}

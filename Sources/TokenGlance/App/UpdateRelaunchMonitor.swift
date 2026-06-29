import AppKit
import Foundation
import TokenGlanceCore

@MainActor
final class UpdateRelaunchMonitor {
  private let bundle: Bundle
  private let checkInterval: TimeInterval
  private let launchedVersion: String
  private let detector = BundleUpdateDetector()
  private var monitorTask: Task<Void, Never>?
  private var isRelaunching = false

  init(
    bundle: Bundle = .main,
    checkInterval: TimeInterval = 30,
    launchedVersion: String = AppIdentity.version
  ) {
    self.bundle = bundle
    self.checkInterval = checkInterval
    self.launchedVersion = launchedVersion
  }

  func start() {
    guard monitorTask == nil, bundle.bundleURL.pathExtension == "app" else { return }
    monitorTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { break }
        self.checkForUpdate()
        do {
          try await Task.sleep(for: .seconds(self.checkInterval))
        } catch {
          break
        }
      }
    }
  }

  func stop() {
    monitorTask?.cancel()
    monitorTask = nil
  }

  private func checkForUpdate() {
    guard !isRelaunching,
      detector.shouldRelaunch(launchedVersion: launchedVersion, diskVersion: diskVersion())
    else { return }
    relaunchFromUpdatedBundle()
  }

  private func diskVersion() -> String? {
    let infoPlistURL = bundle.bundleURL
      .appendingPathComponent("Contents", isDirectory: true)
      .appendingPathComponent("Info.plist", isDirectory: false)
    guard let data = try? Data(contentsOf: infoPlistURL),
      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
      let info = plist as? [String: Any]
    else { return nil }
    return (info["CFBundleShortVersionString"] as? String)
      ?? (info["CFBundleVersion"] as? String)
  }

  private func relaunchFromUpdatedBundle() {
    isRelaunching = true
    stop()

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    configuration.createsNewApplicationInstance = true

    NSWorkspace.shared.openApplication(at: bundle.bundleURL, configuration: configuration) {
      _, error in
      Task { @MainActor in
        if error == nil {
          NSApp.terminate(nil)
        } else {
          self.isRelaunching = false
          self.start()
        }
      }
    }
  }
}

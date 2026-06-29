import Foundation

public struct BundleUpdateDetector: Sendable {
  public init() {}

  public func shouldRelaunch(launchedVersion: String, diskVersion: String?) -> Bool {
    let launched = launchedVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    let disk = diskVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return !launched.isEmpty && !disk.isEmpty && launched != disk
  }
}

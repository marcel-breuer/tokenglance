import Foundation

public enum AppIdentity {
  public static let productName = "TokenGlance"
  public static let executableName = "TokenGlance"
  public static let bundleIdentifier = "dev.marcelbreuer.tokenglance"
  public static let repository = "marcel-breuer/tokenglance"
  public static let homebrewTap = "marcel-breuer/homebrew-tap"
  public static let homebrewCaskToken = "tokenglance"
  public static var version: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.1"
  }
  public static let license = "MIT"

  public static var applicationSupportDirectory: URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first!
    return base.appendingPathComponent(productName, isDirectory: true)
  }
}

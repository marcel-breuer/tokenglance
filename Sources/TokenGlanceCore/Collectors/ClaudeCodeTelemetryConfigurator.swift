import Foundation

/// Writes the OTLP env vars Claude Code needs into its own `~/.claude/settings.json`
/// (the documented `env` block Claude Code applies to every session), so a user
/// doesn't have to export them by hand before TokenGlance can see Claude Code usage.
///
/// Never overwrites values a user (or another tool) already put there: if any of
/// the four required keys is already present, the whole block is left untouched.
public struct ClaudeCodeTelemetryConfigurator: Sendable {
  public enum Outcome: Equatable, Sendable {
    /// All four keys are present and match what TokenGlance would write —
    /// either just written, or already there from a previous run.
    case configured
    /// At least one of the four keys already exists with a different setup
    /// (the user's own OTel config); left untouched.
    case leftUserManaged
  }

  public static var defaultSettingsURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".claude", isDirectory: true)
      .appendingPathComponent("settings.json")
  }

  static func requiredEnv(receiverPort: UInt16) -> [String: String] {
    [
      "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
      "OTEL_METRICS_EXPORTER": "otlp",
      "OTEL_EXPORTER_OTLP_PROTOCOL": "http/json",
      "OTEL_EXPORTER_OTLP_ENDPOINT": "http://127.0.0.1:\(receiverPort)",
    ]
  }

  private let settingsURL: URL
  private let receiverPort: UInt16

  public init(
    settingsURL: URL = Self.defaultSettingsURL,
    receiverPort: UInt16 = ClaudeTelemetryReceiver.defaultPort
  ) {
    self.settingsURL = settingsURL
    self.receiverPort = receiverPort
  }

  @discardableResult
  public func ensureConfigured() throws -> Outcome {
    var root: [String: Any] = [:]
    let data = try? Data(contentsOf: settingsURL)
    if let data, !data.isEmpty {
      guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw CocoaError(.fileReadCorruptFile)
      }
      root = parsed
    }

    var env = root["env"] as? [String: String] ?? [:]
    let required = Self.requiredEnv(receiverPort: receiverPort)

    if required.allSatisfy({ env[$0.key] == $0.value }) {
      return .configured
    }
    if required.keys.contains(where: { env[$0] != nil }) {
      return .leftUserManaged
    }

    for (key, value) in required {
      env[key] = value
    }
    root["env"] = env

    try FileManager.default.createDirectory(
      at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoded = try JSONSerialization.data(
      withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    try encoded.write(to: settingsURL, options: [.atomic])
    return .configured
  }
}

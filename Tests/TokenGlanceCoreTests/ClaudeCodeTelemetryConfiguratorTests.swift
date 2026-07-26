import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Claude Code telemetry configurator")
struct ClaudeCodeTelemetryConfiguratorTests {
  @Test("Writes the env block when settings.json does not exist yet")
  func writesWhenMissing() throws {
    let settingsURL = try temporaryDirectory().appendingPathComponent("settings.json")
    let configurator = ClaudeCodeTelemetryConfigurator(settingsURL: settingsURL, receiverPort: 4319)

    let outcome = try configurator.ensureConfigured()

    #expect(outcome == .configured)
    let env = try readEnv(settingsURL)
    #expect(env?["CLAUDE_CODE_ENABLE_TELEMETRY"] == "1")
    #expect(env?["OTEL_METRICS_EXPORTER"] == "otlp")
    #expect(env?["OTEL_EXPORTER_OTLP_PROTOCOL"] == "http/json")
    #expect(env?["OTEL_EXPORTER_OTLP_ENDPOINT"] == "http://127.0.0.1:4319")
  }

  @Test("Preserves unrelated top-level keys and unrelated env vars")
  func preservesUnrelatedKeys() throws {
    let settingsURL = try temporaryDirectory().appendingPathComponent("settings.json")
    let existing: [String: Any] = [
      "model": "sonnet",
      "env": ["SOME_OTHER_VAR": "keep-me"],
    ]
    try JSONSerialization.data(withJSONObject: existing).write(to: settingsURL)
    let configurator = ClaudeCodeTelemetryConfigurator(settingsURL: settingsURL, receiverPort: 4319)

    let outcome = try configurator.ensureConfigured()

    #expect(outcome == .configured)
    let json = try JSONSerialization.jsonObject(with: Data(contentsOf: settingsURL)) as? [String: Any]
    #expect(json?["model"] as? String == "sonnet")
    let env = json?["env"] as? [String: String]
    #expect(env?["SOME_OTHER_VAR"] == "keep-me")
    #expect(env?["CLAUDE_CODE_ENABLE_TELEMETRY"] == "1")
  }

  @Test("Leaves settings alone when any required key already has a different value")
  func leavesUserManagedConfigAlone() throws {
    let settingsURL = try temporaryDirectory().appendingPathComponent("settings.json")
    let existing: [String: Any] = [
      "env": ["OTEL_METRICS_EXPORTER": "console"]
    ]
    try JSONSerialization.data(withJSONObject: existing).write(to: settingsURL)
    let configurator = ClaudeCodeTelemetryConfigurator(settingsURL: settingsURL, receiverPort: 4319)

    let outcome = try configurator.ensureConfigured()

    #expect(outcome == .leftUserManaged)
    let env = try readEnv(settingsURL)
    #expect(env?["OTEL_METRICS_EXPORTER"] == "console")
    #expect(env?["CLAUDE_CODE_ENABLE_TELEMETRY"] == nil)
  }

  @Test("Is idempotent once already configured")
  func idempotentOnceConfigured() throws {
    let settingsURL = try temporaryDirectory().appendingPathComponent("settings.json")
    let configurator = ClaudeCodeTelemetryConfigurator(settingsURL: settingsURL, receiverPort: 4319)
    try configurator.ensureConfigured()

    let outcome = try configurator.ensureConfigured()

    #expect(outcome == .configured)
  }

  @Test("Throws instead of clobbering an unparseable settings.json")
  func throwsOnCorruptFile() throws {
    let settingsURL = try temporaryDirectory().appendingPathComponent("settings.json")
    try Data("not json".utf8).write(to: settingsURL)
    let configurator = ClaudeCodeTelemetryConfigurator(settingsURL: settingsURL, receiverPort: 4319)

    #expect(throws: (any Error).self) { try configurator.ensureConfigured() }
    #expect(try Data(contentsOf: settingsURL) == Data("not json".utf8))
  }

  private func readEnv(_ url: URL) throws -> [String: String]? {
    let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    return json?["env"] as? [String: String]
  }

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}

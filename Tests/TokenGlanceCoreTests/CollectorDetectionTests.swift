import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Command-line tool detection")
struct CollectorDetectionTests {
  @Test("Detector includes Homebrew paths when GUI PATH is sparse")
  func detectorFindsToolsOutsideSparsePath() throws {
    let root = try temporaryDirectory()
    let sparse = root.appendingPathComponent("sparse", isDirectory: true)
    let homebrew = root.appendingPathComponent("homebrew", isDirectory: true)
    try FileManager.default.createDirectory(at: sparse, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: homebrew, withIntermediateDirectories: true)

    let executable = homebrew.appendingPathComponent("codex")
    try "#!/bin/sh\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: executable.path
    )

    let detector = CommandLineToolDetector(
      pathOverride: "\(sparse.path):\(homebrew.path)"
    )
    #expect(detector.locate("codex") == executable.path)
  }

  @Test("Antigravity collector detects agy executable")
  func antigravityCollectorDetectsAgy() async throws {
    let root = try temporaryDirectory()
    let bin = root.appendingPathComponent("bin", isDirectory: true)
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)

    let executable = bin.appendingPathComponent("agy")
    try "#!/bin/sh\necho 1.0.13\n".write(to: executable, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: executable.path
    )

    let collector = AntigravityCollector(
      detector: CommandLineToolDetector(pathOverride: bin.path)
    )
    let detection = await collector.detect()
    #expect(detection.status == .setupRequired)
    #expect(detection.version == "1.0.13")
    #expect(detection.explanation.contains("Antigravity CLI is installed"))
  }

  @Test("Claude Code collector reports setup required with env var instructions when no telemetry received")
  func claudeCodeCollectorReportsSetupRequired() async throws {
    let (detector, sourceDirectory) = try claudeCodeFixture()

    let collector = ClaudeCodeCollector(detector: detector, sourceDirectories: [sourceDirectory])
    let detection = await collector.detect()

    #expect(detection.status == .setupRequired)
    #expect(detection.explanation.contains("CLAUDE_CODE_ENABLE_TELEMETRY=1"))
    #expect(detection.explanation.contains("OTEL_EXPORTER_OTLP_ENDPOINT"))
  }

  @Test("Claude Code collector auto-configures settings.json and reports waiting for data")
  func claudeCodeCollectorAutoConfigures() async throws {
    let (detector, sourceDirectory) = try claudeCodeFixture()
    let root = try temporaryDirectory()
    let settingsURL = root.appendingPathComponent("claude-settings.json")
    let configurator = ClaudeCodeTelemetryConfigurator(
      settingsURL: settingsURL, receiverPort: 4319)

    let collector = ClaudeCodeCollector(
      detector: detector, sourceDirectories: [sourceDirectory], configurator: configurator)
    let detection = await collector.detect()

    #expect(detection.status == .waitingForData)
    #expect(detection.explanation.contains("automatically configured"))

    let written = try Data(contentsOf: settingsURL)
    let json = try JSONSerialization.jsonObject(with: written) as? [String: Any]
    let env = json?["env"] as? [String: String]
    #expect(env?["CLAUDE_CODE_ENABLE_TELEMETRY"] == "1")
    #expect(env?["OTEL_EXPORTER_OTLP_ENDPOINT"] == "http://127.0.0.1:4319")
  }

  @Test("Claude Code collector leaves existing user OTel settings untouched")
  func claudeCodeCollectorLeavesUserManagedSettingsAlone() async throws {
    let (detector, sourceDirectory) = try claudeCodeFixture()
    let root = try temporaryDirectory()
    let settingsURL = root.appendingPathComponent("claude-settings.json")
    let existing: [String: Any] = [
      "env": ["OTEL_EXPORTER_OTLP_ENDPOINT": "http://example.com:9999"]
    ]
    try JSONSerialization.data(withJSONObject: existing).write(to: settingsURL)
    let configurator = ClaudeCodeTelemetryConfigurator(
      settingsURL: settingsURL, receiverPort: 4319)

    let collector = ClaudeCodeCollector(
      detector: detector, sourceDirectories: [sourceDirectory], configurator: configurator)
    let detection = await collector.detect()

    #expect(detection.status == .setupRequired)
    #expect(detection.explanation.contains("already has its own OpenTelemetry configuration"))

    let written = try Data(contentsOf: settingsURL)
    let json = try JSONSerialization.jsonObject(with: written) as? [String: Any]
    let env = json?["env"] as? [String: String]
    #expect(env?["OTEL_EXPORTER_OTLP_ENDPOINT"] == "http://example.com:9999")
  }

  @Test("Claude Code collector reports waiting for data when receiver directory has only empty files")
  func claudeCodeCollectorReportsWaitingForData() async throws {
    let (detector, sourceDirectory) = try claudeCodeFixture()
    try Data().write(to: sourceDirectory.appendingPathComponent("claude-otel-2026-07-27.jsonl"))

    let collector = ClaudeCodeCollector(detector: detector, sourceDirectories: [sourceDirectory])
    let detection = await collector.detect()

    #expect(detection.status == .waitingForData)
  }

  @Test("Claude Code collector reports detected once telemetry data exists")
  func claudeCodeCollectorReportsDetected() async throws {
    let (detector, sourceDirectory) = try claudeCodeFixture()
    let data = try fixture("ClaudeCode/telemetry.jsonl")
    try data.write(to: sourceDirectory.appendingPathComponent("claude-otel-2026-07-27.jsonl"))

    let collector = ClaudeCodeCollector(detector: detector, sourceDirectories: [sourceDirectory])
    let detection = await collector.detect()

    #expect(detection.status == .detected)
  }

  private func claudeCodeFixture() throws -> (CommandLineToolDetector, URL) {
    let root = try temporaryDirectory()
    let bin = root.appendingPathComponent("bin", isDirectory: true)
    let sourceDirectory = root.appendingPathComponent("claude-otel", isDirectory: true)
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)

    let executable = bin.appendingPathComponent("claude")
    try "#!/bin/sh\necho 2.1.212 (Claude Code)\n".write(
      to: executable, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755], ofItemAtPath: executable.path)

    return (CommandLineToolDetector(pathOverride: bin.path), sourceDirectory)
  }

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func fixture(_ path: String) throws -> Data {
    let url = Bundle.module.resourceURL!.appendingPathComponent("Fixtures").appendingPathComponent(
      path)
    return try Data(contentsOf: url)
  }
}

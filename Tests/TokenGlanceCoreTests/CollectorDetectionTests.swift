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

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}

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

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}

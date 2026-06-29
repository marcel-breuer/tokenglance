import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Local report archive")
struct LocalReportArchiveTests {
  @Test("Archives weekly report markdown under configured directory")
  func archivesWeeklyReport() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let archive = LocalReportArchive(directory: directory)
    let now = DateCoding.parseISO8601("2026-06-29T12:00:00Z")!

    let url = try archive.saveWeeklyReport("# Report", now: now)

    #expect(url.lastPathComponent == "TokenGlance-Weekly-2026-06-29.md")
    #expect(try String(contentsOf: url, encoding: .utf8) == "# Report")
  }
}

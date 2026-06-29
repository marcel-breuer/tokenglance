import Foundation

public struct LocalReportArchive: Sendable {
  private let directory: URL

  public init(
    directory: URL = AppIdentity.applicationSupportDirectory.appendingPathComponent(
      "Reports", isDirectory: true)
  ) {
    self.directory = directory
  }

  public func saveWeeklyReport(_ markdown: String, now: Date = Date()) throws -> URL {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fileURL = directory.appendingPathComponent(
      "TokenGlance-Weekly-\(dateStamp(now)).md", isDirectory: false)
    try Data(markdown.utf8).write(to: fileURL, options: [.atomic])
    return fileURL
  }

  private func dateStamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
}

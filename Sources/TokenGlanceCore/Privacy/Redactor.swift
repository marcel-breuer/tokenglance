import Foundation

public struct Redactor: Sendable {
  public init() {}

  public func redact(_ text: String) -> String {
    var result = text
    let home = NSRegularExpression.escapedPattern(
      for: FileManager.default.homeDirectoryForCurrentUser.path)
    result = replacing(result, pattern: home + #"(/[^\s,;)]*)?"#, with: "~/<redacted>")
    result = replacing(
      result, pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, with: "<redacted-email>",
      options: [.caseInsensitive])
    result = replacing(
      result, pattern: #"(?i)(api[_-]?key|token|password|secret)["'\s:=]+[A-Za-z0-9._\-]{8,}"#,
      with: "$1=<redacted>")
    return result
  }

  private func replacing(
    _ text: String, pattern: String, with replacement: String,
    options: NSRegularExpression.Options = []
  ) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
      return text
    }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
  }
}

import Foundation

public struct Redactor: Sendable {
  public init() {}

  public func redact(_ text: String) -> String {
    var result = text
    result = replacing(
      result,
      pattern: #"(?i)\b(prompt|response|source[_-]?code|session[_-]?(?:id|identifier)|cookie|authorization)\b\s*[:=]\s*(?:"[^"]*"|'[^']*'|[^,\r\n;]+)"#,
      with: "$1=<redacted>"
    )
    result = replacing(
      result,
      pattern: #"(?i)\b(path|file|directory|source[_-]?path)\b\s*[:=]\s*(?:"[^"]*"|'[^']*'|[^,\r\n;]+)"#,
      with: "$1=<redacted>"
    )
    result = replacing(
      result, pattern: #"['"“](/(?:Users|private|Volumes|tmp|var)/[^'"”\r\n]*)['"”]"#,
      with: "<redacted-path>"
    )
    let home = NSRegularExpression.escapedPattern(
      for: FileManager.default.homeDirectoryForCurrentUser.path)
    result = replacing(result, pattern: home + #"(/[^\s,;)]*)?"#, with: "~/<redacted>")
    result = replacing(result, pattern: #"/Users/[^/\s,;)]+(/[^\s,;)]*)?"#, with: "~/<redacted>")
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

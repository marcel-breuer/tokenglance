import Foundation

enum JSONMetadata {
  static func objects(fromJSONLines data: Data) -> [(object: [String: Any], offset: UInt64)] {
    guard let text = String(data: data, encoding: .utf8) else { return [] }
    var offset: UInt64 = 0
    var result: [(object: [String: Any], offset: UInt64)] = []

    for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
      defer { offset += UInt64(line.utf8.count + 1) }
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, trimmed.last == "}" else { continue }
      guard
        let lineData = trimmed.data(using: .utf8),
        let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
      else {
        continue
      }
      result.append((object, offset))
    }

    return result
  }

  static func dictionary(_ object: [String: Any], at path: [String]) -> [String: Any]? {
    var current: Any = object
    for key in path {
      guard let next = (current as? [String: Any])?[key] else { return nil }
      current = next
    }
    return current as? [String: Any]
  }

  static func string(_ object: [String: Any], keys: [String]) -> String? {
    for key in keys {
      if let value = object[key] as? String, !value.isEmpty {
        return value
      }
    }
    return nil
  }

  static func int(_ object: [String: Any], keys: [String]) -> Int? {
    for key in keys {
      if let value = object[key] as? Int { return value }
      if let value = object[key] as? Int64 { return Int(value) }
      if let value = object[key] as? Double { return Int(value) }
      if let value = object[key] as? String, let intValue = Int(value) { return intValue }
    }
    return nil
  }

  static func date(_ object: [String: Any], keys: [String]) -> Date? {
    for key in keys {
      guard let value = object[key] else { continue }
      if let seconds = value as? TimeInterval {
        return Date(timeIntervalSince1970: seconds > 10_000_000_000 ? seconds / 1000 : seconds)
      }
      if let string = value as? String {
        if let date = DateCoding.parseISO8601(string) {
          return date
        }
        if let seconds = TimeInterval(string) {
          return Date(timeIntervalSince1970: seconds > 10_000_000_000 ? seconds / 1000 : seconds)
        }
      }
    }
    return nil
  }

  static func nestedString(_ object: [String: Any], candidates: [[String]]) -> String? {
    for path in candidates {
      if path.count == 1 {
        if let value = string(object, keys: [path[0]]) { return value }
      } else {
        let parent = Array(path.dropLast())
        if let dictionary = dictionary(object, at: parent),
          let value = string(dictionary, keys: [path.last!])
        {
          return value
        }
      }
    }
    return nil
  }
}

public enum DateCoding {
  public static func parseISO8601(_ string: String) -> Date? {
    iso8601WithFractionalSeconds().date(from: string)
      ?? iso8601NoFractionalSeconds().date(from: string)
  }

  public static func iso8601String(_ date: Date) -> String {
    iso8601NoFractionalSeconds().string(from: date)
  }

  private static func iso8601WithFractionalSeconds() -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }

  private static func iso8601NoFractionalSeconds() -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }
}

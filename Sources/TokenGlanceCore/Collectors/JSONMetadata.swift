import Foundation

enum JSONMetadata {
  struct DateParser {
    private let fractionalFormatter: ISO8601DateFormatter
    private let standardFormatter: ISO8601DateFormatter

    init() {
      fractionalFormatter = ISO8601DateFormatter()
      fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      standardFormatter = ISO8601DateFormatter()
      standardFormatter.formatOptions = [.withInternetDateTime]
    }

    func parse(_ string: String) -> Date? {
      Self.parseCommonISO8601(string)
        ?? fractionalFormatter.date(from: string)
        ?? standardFormatter.date(from: string)
    }

    private static func parseCommonISO8601(_ string: String) -> Date? {
      let bytes = Array(string.utf8)
      guard bytes.count >= 20,
        bytes[4] == 45,
        bytes[7] == 45,
        bytes[10] == 84 || bytes[10] == 116 || bytes[10] == 32,
        bytes[13] == 58,
        bytes[16] == 58,
        let year = digits(bytes, from: 0, count: 4),
        let month = digits(bytes, from: 5, count: 2),
        let day = digits(bytes, from: 8, count: 2),
        let hour = digits(bytes, from: 11, count: 2),
        let minute = digits(bytes, from: 14, count: 2),
        let second = digits(bytes, from: 17, count: 2),
        year > 0,
        month >= 1,
        month <= 12,
        hour <= 23,
        minute <= 59,
        second <= 59
      else { return nil }

      let leapYear =
        year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
      let monthLengths = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
      guard day >= 1, day <= monthLengths[month - 1] else { return nil }

      var cursor = 19
      var fractionalSecond = 0.0
      if cursor < bytes.count, bytes[cursor] == 46 || bytes[cursor] == 44 {
        cursor += 1
        var place = 0.1
        let fractionStart = cursor
        while cursor < bytes.count, (48...57).contains(bytes[cursor]) {
          fractionalSecond += Double(bytes[cursor] - 48) * place
          place *= 0.1
          cursor += 1
        }
        guard cursor > fractionStart else { return nil }
      }

      var offsetSeconds = 0
      if cursor < bytes.count, bytes[cursor] == 90 || bytes[cursor] == 122 {
        cursor += 1
      } else if cursor < bytes.count, bytes[cursor] == 43 || bytes[cursor] == 45 {
        let sign = bytes[cursor] == 43 ? 1 : -1
        cursor += 1
        guard let offsetHours = digits(bytes, from: cursor, count: 2) else { return nil }
        cursor += 2
        if cursor < bytes.count, bytes[cursor] == 58 { cursor += 1 }
        guard let offsetMinutes = digits(bytes, from: cursor, count: 2),
          offsetHours <= 23,
          offsetMinutes <= 59
        else { return nil }
        cursor += 2
        offsetSeconds = sign * (offsetHours * 3_600 + offsetMinutes * 60)
      } else {
        return nil
      }
      guard cursor == bytes.count else { return nil }

      let days = daysSinceUnixEpoch(year: year, month: month, day: day)
      let localSeconds = days * 86_400 + hour * 3_600 + minute * 60 + second
      return Date(timeIntervalSince1970: Double(localSeconds - offsetSeconds) + fractionalSecond)
    }

    private static func digits(_ bytes: [UInt8], from start: Int, count: Int) -> Int? {
      guard start >= 0, count > 0, start + count <= bytes.count else { return nil }
      var value = 0
      for byte in bytes[start..<(start + count)] {
        guard (48...57).contains(byte) else { return nil }
        value = value * 10 + Int(byte - 48)
      }
      return value
    }

    private static func daysSinceUnixEpoch(year: Int, month: Int, day: Int) -> Int {
      let adjustedYear = year - (month <= 2 ? 1 : 0)
      let era = adjustedYear / 400
      let yearOfEra = adjustedYear - era * 400
      let adjustedMonth = month + (month > 2 ? -3 : 9)
      let dayOfYear = (153 * adjustedMonth + 2) / 5 + day - 1
      let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
      return era * 146_097 + dayOfEra - 719_468
    }
  }

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

  static func date(
    _ object: [String: Any], keys: [String], using parser: DateParser? = nil
  ) -> Date? {
    for key in keys {
      guard let value = object[key] else { continue }
      if let seconds = value as? TimeInterval {
        return Date(timeIntervalSince1970: seconds > 10_000_000_000 ? seconds / 1000 : seconds)
      }
      if let string = value as? String {
        if let parser {
          if let date = parser.parse(string) { return date }
        } else if let date = DateCoding.parseISO8601(string) {
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

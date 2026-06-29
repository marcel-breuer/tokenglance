import Foundation

public struct ManualUsageImportParser: Sendable {
  public static let parserVersion = "manual-usage-import-v1"

  public init() {}

  public func parse(
    _ data: Data,
    sourceName: String,
    importedAt: Date = Date()
  ) throws -> CollectionBatch {
    let sourceFingerprint = Hashing.sha256(
      "manual|\(sourceName)|\(data.count)|\(String(decoding: data, as: UTF8.self))")

    if let jsonBatch = try parseJSON(
      data, sourceFingerprint: sourceFingerprint, importedAt: importedAt)
    {
      return jsonBatch
    }

    guard let text = String(data: data, encoding: .utf8) else {
      throw ManualUsageImportError.unreadableText
    }
    return parseCSV(text, sourceFingerprint: sourceFingerprint, importedAt: importedAt)
  }

  private func parseJSON(
    _ data: Data,
    sourceFingerprint: String,
    importedAt: Date
  ) throws -> CollectionBatch? {
    let root = try? JSONSerialization.jsonObject(with: data)
    let objects: [[String: Any]]
    if let array = root as? [[String: Any]] {
      objects = array
    } else if let object = root as? [String: Any],
      let events = object["events"] as? [[String: Any]]
    {
      objects = events
    } else if root != nil {
      throw ManualUsageImportError.unsupportedJSONShape
    } else {
      return nil
    }

    var events: [UsageEvent] = []
    var invalid = 0
    for (index, object) in objects.enumerated() {
      if let event = makeEvent(
        fields: ManualUsageFields(object),
        sourceFingerprint: sourceFingerprint,
        ordinal: index,
        importedAt: importedAt)
      {
        events.append(event)
      } else {
        invalid += 1
      }
    }

    return CollectionBatch(events: events, importedRecords: events.count, invalidRecords: invalid)
  }

  private func parseCSV(
    _ text: String,
    sourceFingerprint: String,
    importedAt: Date
  ) -> CollectionBatch {
    let rows = CSVRows.parse(text)
    guard let header = rows.first, !header.isEmpty else {
      return CollectionBatch(events: [], invalidRecords: 1)
    }

    var events: [UsageEvent] = []
    var invalid = 0
    let keys = header.map { ManualUsageFields.normalize($0) }
    for (index, row) in rows.dropFirst().enumerated() {
      guard row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
      else {
        continue
      }
      let fields = ManualUsageFields(keys: keys, values: row)
      if let event = makeEvent(
        fields: fields,
        sourceFingerprint: sourceFingerprint,
        ordinal: index,
        importedAt: importedAt)
      {
        events.append(event)
      } else {
        invalid += 1
      }
    }

    return CollectionBatch(events: events, importedRecords: events.count, invalidRecords: invalid)
  }

  private func makeEvent(
    fields: ManualUsageFields,
    sourceFingerprint: String,
    ordinal: Int,
    importedAt: Date
  ) -> UsageEvent? {
    guard let timestamp = fields.date(["timestamp", "time", "created_at", "date"]) else {
      return nil
    }
    let tool = Self.toolIdentifier(
      fields.string(["tool", "app", "application", "service", "source", "provider"]))
    let provider = Self.providerIdentifier(
      fields.string(["provider", "vendor", "company"]), inferredFrom: tool)
    let tokens = TokenBreakdown(
      inputTokens: fields.int(["input_tokens", "input", "prompt_tokens"]),
      outputTokens: fields.int(["output_tokens", "output", "completion_tokens"]),
      cachedInputTokens: fields.int(["cached_input_tokens", "cache_read_tokens", "cached_tokens"]),
      cacheCreationTokens: fields.int(["cache_creation_tokens", "cache_write_tokens"]),
      reasoningTokens: fields.int(["reasoning_tokens", "thinking_tokens"]),
      otherTokens: fields.int(["other_tokens", "tool_tokens"]),
      totalTokens: fields.int(["total_tokens", "total"])
    )
    guard tokens.calculatedTotal > 0 else { return nil }

    let model = fields.string(["model", "model_id", "model_name"])
    let eventID = Hashing.sha256(
      [
        "manual",
        sourceFingerprint,
        String(ordinal),
        DateCoding.iso8601String(timestamp),
        tool.rawValue,
        provider.rawValue,
        model ?? "",
        String(tokens.calculatedTotal),
      ].joined(separator: "|"))

    return UsageEvent(
      id: eventID,
      collector: .manualImport,
      tool: tool,
      provider: provider,
      model: model,
      timestamp: timestamp,
      tokens: tokens,
      sessionIdentifierHash: nil,
      projectIdentifierHash: nil,
      sourceKind: .manualImport,
      sourceFingerprint: sourceFingerprint,
      accuracy: .exact,
      parserVersion: Self.parserVersion,
      importedAt: importedAt
    )
  }

  private static func toolIdentifier(_ value: String?) -> ToolIdentifier {
    let normalized = ManualUsageFields.normalize(value ?? "")
    if ["chatgpt", "chat_gpt", "chat-gpt"].contains(normalized) { return .chatGPT }
    if normalized == "claude" { return .claude }
    if normalized == "gemini" || normalized == "google_gemini" { return .gemini }
    if normalized == "openai" || normalized == "openai_api" { return .openAIAPI }
    if normalized == "anthropic" || normalized == "anthropic_api" { return .anthropicAPI }
    if normalized == "google" || normalized == "google_ai" || normalized == "google_ai_api" {
      return .googleAIAPI
    }
    if normalized == "codex" || normalized == "codex_cli" { return .codexCLI }
    if normalized == "claude_code" { return .claudeCode }
    if normalized == "antigravity" { return .antigravity }
    if normalized == "gemini_cli" { return .geminiCLI }
    return .openAIAPI
  }

  private static func providerIdentifier(
    _ value: String?,
    inferredFrom tool: ToolIdentifier
  ) -> ProviderIdentifier {
    let normalized = ManualUsageFields.normalize(value ?? "")
    if normalized == "anthropic" { return .anthropic }
    if normalized == "google" || normalized == "google_ai" { return .google }
    if normalized == "openai" { return .openAI }

    switch tool {
    case .claude, .claudeCode, .anthropicAPI:
      return .anthropic
    case .antigravity, .geminiCLI, .gemini, .googleAIAPI:
      return .google
    case .codexCLI, .chatGPT, .openAIAPI:
      return .openAI
    }
  }
}

public enum ManualUsageImportError: Error, LocalizedError {
  case unreadableText
  case unsupportedJSONShape

  public var errorDescription: String? {
    switch self {
    case .unreadableText:
      "The usage import file must be UTF-8 CSV or JSON."
    case .unsupportedJSONShape:
      "JSON usage import must be an array of events or an object with an events array."
    }
  }
}

private struct ManualUsageFields {
  private let values: [String: Any]

  init(_ object: [String: Any]) {
    var normalized: [String: Any] = [:]
    for (key, value) in object {
      normalized[Self.normalize(key)] = value
    }
    values = normalized
  }

  init(keys: [String], values row: [String]) {
    var normalized: [String: Any] = [:]
    for (index, key) in keys.enumerated() where index < row.count {
      normalized[key] = row[index]
    }
    values = normalized
  }

  func string(_ keys: [String]) -> String? {
    for key in keys.map(Self.normalize) {
      guard let value = values[key] else { continue }
      if let string = value as? String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
      } else if let number = value as? NSNumber {
        return number.stringValue
      }
    }
    return nil
  }

  func int(_ keys: [String]) -> Int? {
    for key in keys.map(Self.normalize) {
      guard let value = values[key] else { continue }
      if let int = value as? Int { return max(0, int) }
      if let double = value as? Double { return max(0, Int(double)) }
      if let number = value as? NSNumber { return max(0, number.intValue) }
      if let string = value as? String {
        let clean = string.trimmingCharacters(in: .whitespacesAndNewlines)
          .replacingOccurrences(of: ",", with: "")
        if let int = Int(clean) { return max(0, int) }
        if let double = Double(clean) { return max(0, Int(double)) }
      }
    }
    return nil
  }

  func date(_ keys: [String]) -> Date? {
    for key in keys.map(Self.normalize) {
      guard let value = values[key] else { continue }
      if let date = value as? Date { return date }
      if let number = value as? NSNumber {
        return dateFromSeconds(number.doubleValue)
      }
      if let string = value as? String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let date = DateCoding.parseISO8601(trimmed) { return date }
        if let seconds = Double(trimmed) { return dateFromSeconds(seconds) }
      }
    }
    return nil
  }

  static func normalize(_ value: String) -> String {
    value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(of: " ", with: "_")
      .replacingOccurrences(of: "-", with: "_")
      .replacingOccurrences(of: ".", with: "_")
  }

  private func dateFromSeconds(_ value: Double) -> Date {
    Date(timeIntervalSince1970: value > 10_000_000_000 ? value / 1000 : value)
  }
}

private enum CSVRows {
  static func parse(_ text: String) -> [[String]] {
    var rows: [[String]] = []
    var row: [String] = []
    var field = ""
    var isQuoted = false
    var iterator = text.makeIterator()

    while let character = iterator.next() {
      switch character {
      case "\"":
        if isQuoted {
          if let next = iterator.next() {
            if next == "\"" {
              field.append("\"")
            } else {
              isQuoted = false
              process(next, row: &row, rows: &rows, field: &field, isQuoted: &isQuoted)
            }
          } else {
            isQuoted = false
          }
        } else if field.isEmpty {
          isQuoted = true
        } else {
          field.append(character)
        }
      default:
        process(character, row: &row, rows: &rows, field: &field, isQuoted: &isQuoted)
      }
    }

    if !field.isEmpty || !row.isEmpty {
      row.append(field)
      rows.append(row)
    }
    return rows
  }

  private static func process(
    _ character: Character,
    row: inout [String],
    rows: inout [[String]],
    field: inout String,
    isQuoted: inout Bool
  ) {
    if character == "," && !isQuoted {
      row.append(field)
      field = ""
    } else if character == "\n" && !isQuoted {
      row.append(field)
      rows.append(row)
      row = []
      field = ""
    } else if character != "\r" || isQuoted {
      field.append(character)
    }
  }
}

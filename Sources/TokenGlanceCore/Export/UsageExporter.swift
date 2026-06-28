import Foundation

public struct UsageExporter: Sendable {
  public init() {}

  public func jsonData(events: [UsageEvent]) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(events)
  }

  public func csvData(events: [UsageEvent]) -> Data {
    var rows = [
      "id,collector,tool,provider,model,timestamp,input_tokens,output_tokens,cached_input_tokens,cache_creation_tokens,reasoning_tokens,other_tokens,total_tokens,source_kind,accuracy,parser_version"
    ]
    for event in events {
      let fields: [String] = [
        event.id,
        event.collector.rawValue,
        event.tool.rawValue,
        event.provider.rawValue,
        event.model ?? "",
        DateCoding.iso8601String(event.timestamp),
        event.tokens.inputTokens.map(String.init) ?? "",
        event.tokens.outputTokens.map(String.init) ?? "",
        event.tokens.cachedInputTokens.map(String.init) ?? "",
        event.tokens.cacheCreationTokens.map(String.init) ?? "",
        event.tokens.reasoningTokens.map(String.init) ?? "",
        event.tokens.otherTokens.map(String.init) ?? "",
        event.tokens.totalTokens.map(String.init) ?? "",
        event.sourceKind.rawValue,
        event.accuracy.rawValue,
        event.parserVersion,
      ]
      rows.append(fields.map(escapeCSV).joined(separator: ","))
    }
    return Data(rows.joined(separator: "\n").utf8)
  }

  private func escapeCSV(_ value: String) -> String {
    if value.contains(",") || value.contains("\"") || value.contains("\n") {
      return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
    return value
  }
}

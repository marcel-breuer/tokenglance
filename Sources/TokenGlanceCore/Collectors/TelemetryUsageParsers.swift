import Foundation

public struct ClaudeTelemetryParser: Sendable {
  public static let parserVersion = "claude-code-otel-token-usage-v1"

  public init() {}

  public func parseJSONLines(
    _ data: Data,
    sourceFingerprint: String,
    privacySalt: String = "tokenglance-local",
    importedAt: Date = Date()
  ) -> CollectionBatch {
    parse(
      data, collector: .claudeCode, tool: .claudeCode, provider: .anthropic,
      sourceFingerprint: sourceFingerprint, privacySalt: privacySalt, importedAt: importedAt)
  }

  private func parse(
    _ data: Data, collector: CollectorIdentifier, tool: ToolIdentifier,
    provider: ProviderIdentifier, sourceFingerprint: String, privacySalt: String, importedAt: Date
  ) -> CollectionBatch {
    var events: [UsageEvent] = []
    var invalid = 0

    for record in JSONMetadata.objects(fromJSONLines: data) {
      let object = record.object
      let name = JSONMetadata.string(object, keys: ["name", "metric", "event.name"]) ?? ""
      guard name.contains("token.usage") || name.contains("cost.usage") else {
        invalid += 1
        continue
      }
      let attributes =
        (object["attributes"] as? [String: Any])
        ?? (object["resource"] as? [String: Any])
        ?? object
      let tokens = TokenBreakdown(
        inputTokens: JSONMetadata.int(attributes, keys: ["input_tokens", "input_token_count"]),
        outputTokens: JSONMetadata.int(attributes, keys: ["output_tokens", "output_token_count"]),
        cachedInputTokens: JSONMetadata.int(
          attributes, keys: ["cache_read_input_tokens", "cache_read_tokens", "cache_read"]),
        cacheCreationTokens: JSONMetadata.int(
          attributes,
          keys: ["cache_creation_input_tokens", "cache_creation_tokens", "cache_creation"]),
        reasoningTokens: JSONMetadata.int(
          attributes, keys: ["reasoning_output_tokens", "reasoning_tokens"]),
        totalTokens: JSONMetadata.int(attributes, keys: ["total_tokens", "total_token_count"])
      )
      guard tokens.calculatedTotal > 0 else { continue }
      let model = JSONMetadata.string(
        attributes, keys: ["model", "gen_ai.request.model", "gen_ai.response.model"])
      let session = JSONMetadata.string(attributes, keys: ["session_id", "session.id"])
      let timestamp =
        JSONMetadata.date(object, keys: ["timestamp", "time_unix_nano", "time"]) ?? importedAt
      let id = Hashing.sha256(
        "\(collector.rawValue)|\(sourceFingerprint)|\(record.offset)|\(tokens.calculatedTotal)")

      events.append(
        UsageEvent(
          id: id,
          collector: collector,
          tool: tool,
          provider: provider,
          model: model,
          timestamp: timestamp,
          tokens: tokens,
          sessionIdentifierHash: session.map { Hashing.privacyHash($0, salt: privacySalt) },
          projectIdentifierHash: nil,
          sourceKind: .localTelemetry,
          sourceFingerprint: sourceFingerprint,
          accuracy: .exact,
          parserVersion: Self.parserVersion,
          importedAt: importedAt
        ))
    }

    return CollectionBatch(events: events, importedRecords: events.count, invalidRecords: invalid)
  }
}

public struct GeminiTelemetryParser: Sendable {
  public static let parserVersion = "gemini-cli-telemetry-token-usage-v1"

  public init() {}

  public func parseJSONLines(
    _ data: Data,
    sourceFingerprint: String,
    privacySalt: String = "tokenglance-local",
    importedAt: Date = Date()
  ) -> CollectionBatch {
    var events: [UsageEvent] = []
    var invalid = 0

    for record in JSONMetadata.objects(fromJSONLines: data) {
      let object = record.object
      let name = JSONMetadata.string(object, keys: ["name", "eventName", "metric"]) ?? ""
      guard
        name.contains("gemini_cli.api_response") || name.contains("gemini_cli.token.usage")
          || name.contains("gen_ai.client.token.usage")
      else {
        invalid += 1
        continue
      }
      let attributes = (object["attributes"] as? [String: Any]) ?? object
      let tokens = TokenBreakdown(
        inputTokens: JSONMetadata.int(
          attributes, keys: ["input_token_count", "gen_ai.usage.input_tokens", "input_tokens"]),
        outputTokens: JSONMetadata.int(
          attributes, keys: ["output_token_count", "gen_ai.usage.output_tokens", "output_tokens"]),
        cachedInputTokens: JSONMetadata.int(
          attributes, keys: ["cached_content_token_count", "cached_input_tokens"]),
        reasoningTokens: JSONMetadata.int(
          attributes, keys: ["thoughts_token_count", "reasoning_tokens"]),
        otherTokens: JSONMetadata.int(attributes, keys: ["tool_token_count"]),
        totalTokens: JSONMetadata.int(attributes, keys: ["total_token_count", "total_tokens"])
      )
      guard tokens.calculatedTotal > 0 else { continue }
      let model = JSONMetadata.string(
        attributes, keys: ["model", "gen_ai.request.model", "gen_ai.response.model"])
      let session = JSONMetadata.string(attributes, keys: ["session_id", "session.id"])
      let timestamp = JSONMetadata.date(object, keys: ["timestamp", "time"]) ?? importedAt
      let id = Hashing.sha256(
        "gemini|\(sourceFingerprint)|\(record.offset)|\(tokens.calculatedTotal)")

      events.append(
        UsageEvent(
          id: id,
          collector: .antigravity,
          tool: .antigravity,
          provider: .google,
          model: model,
          timestamp: timestamp,
          tokens: tokens,
          sessionIdentifierHash: session.map { Hashing.privacyHash($0, salt: privacySalt) },
          projectIdentifierHash: nil,
          sourceKind: .localTelemetry,
          sourceFingerprint: sourceFingerprint,
          accuracy: .exact,
          parserVersion: Self.parserVersion,
          importedAt: importedAt
        ))
    }

    return CollectionBatch(events: events, importedRecords: events.count, invalidRecords: invalid)
  }
}

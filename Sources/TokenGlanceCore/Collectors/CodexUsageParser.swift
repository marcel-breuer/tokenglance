import Foundation

public struct CodexUsageParser: Sendable {
  public static let parserVersion = "codex-jsonl-token-count-v1"

  public init() {}

  public func parseJSONLines(
    _ data: Data,
    sourceFingerprint: String,
    privacySalt: String = "tokenglance-local",
    importedAt: Date = Date()
  ) -> CollectionBatch {
    var previousCumulative: [String: TokenBreakdown] = [:]
    var events: [UsageEvent] = []
    var invalid = 0

    for record in JSONMetadata.objects(fromJSONLines: data) {
      guard let usage = usageRecord(from: record.object) else {
        invalid += 1
        continue
      }

      let timestamp =
        JSONMetadata.date(record.object, keys: ["timestamp", "ts", "time", "created_at"])
        ?? importedAt
      let model = JSONMetadata.nestedString(
        record.object,
        candidates: [
          ["model"],
          ["msg", "model"],
          ["message", "model"],
          ["payload", "model"],
        ])
      let sessionID = JSONMetadata.nestedString(
        record.object,
        candidates: [
          ["session_id"],
          ["conversation_id"],
          ["thread_id"],
          ["msg", "session_id"],
          ["message", "session_id"],
        ])

      let key = [sessionID ?? "session", model ?? "model", sourceFingerprint].joined(separator: "|")
      let normalized: TokenBreakdown?
      switch usage.kind {
      case .perTurn:
        normalized = usage.tokens
      case .cumulative:
        normalized = delta(from: previousCumulative[key], to: usage.tokens)
        previousCumulative[key] = usage.tokens
      }

      guard let tokens = normalized, tokens.calculatedTotal > 0 else { continue }

      let id = Hashing.sha256(
        "codex|\(sourceFingerprint)|\(record.offset)|\(timestamp.timeIntervalSince1970)|\(tokens.calculatedTotal)"
      )
      events.append(
        UsageEvent(
          id: id,
          collector: .codexCLI,
          tool: .codexCLI,
          provider: .openAI,
          model: model,
          timestamp: timestamp,
          tokens: tokens,
          sessionIdentifierHash: sessionID.map { Hashing.privacyHash($0, salt: privacySalt) },
          projectIdentifierHash: nil,
          sourceKind: .localJSONL,
          sourceFingerprint: sourceFingerprint,
          accuracy: .exact,
          parserVersion: Self.parserVersion,
          importedAt: importedAt
        )
      )
    }

    return CollectionBatch(
      events: events,
      importedRecords: events.count,
      invalidRecords: invalid
    )
  }

  private enum UsageKind {
    case perTurn
    case cumulative
  }

  private struct ParsedUsage {
    let kind: UsageKind
    let tokens: TokenBreakdown
  }

  private func usageRecord(from object: [String: Any]) -> ParsedUsage? {
    let type = JSONMetadata.nestedString(
      object,
      candidates: [
        ["type"],
        ["msg", "type"],
        ["message", "type"],
        ["event", "type"],
      ])

    let topLevelUsage = ["usage", "token_usage", "last_token_usage"].compactMap {
      object[$0] as? [String: Any]
    }.first
    let msgUsage =
      JSONMetadata.dictionary(object, at: ["msg", "last_token_usage"])
      ?? JSONMetadata.dictionary(object, at: ["message", "last_token_usage"])
      ?? JSONMetadata.dictionary(object, at: ["payload", "last_token_usage"])
    let cumulativeUsage =
      JSONMetadata.dictionary(object, at: ["total_token_usage"])
      ?? JSONMetadata.dictionary(object, at: ["msg", "total_token_usage"])
      ?? JSONMetadata.dictionary(object, at: ["message", "total_token_usage"])
      ?? JSONMetadata.dictionary(object, at: ["payload", "total_token_usage"])

    if let cumulativeUsage, let tokens = tokens(from: cumulativeUsage) {
      return ParsedUsage(kind: .cumulative, tokens: tokens)
    }

    if type == "token_count" || topLevelUsage != nil || msgUsage != nil {
      let source = msgUsage ?? topLevelUsage ?? object
      if let tokens = tokens(from: source) {
        return ParsedUsage(kind: .perTurn, tokens: tokens)
      }
    }

    return nil
  }

  private func tokens(from object: [String: Any]) -> TokenBreakdown? {
    let input = JSONMetadata.int(object, keys: ["input_tokens", "prompt_tokens"])
    let cached =
      JSONMetadata.int(
        object, keys: ["cached_input_tokens", "cache_read_input_tokens", "cached_tokens"])
      ?? JSONMetadata.int(
        object["input_tokens_details"] as? [String: Any] ?? [:], keys: ["cached_tokens"])
    let output = JSONMetadata.int(object, keys: ["output_tokens", "completion_tokens"])
    let reasoning =
      JSONMetadata.int(object, keys: ["reasoning_output_tokens", "reasoning_tokens"])
      ?? JSONMetadata.int(
        object["output_tokens_details"] as? [String: Any] ?? [:], keys: ["reasoning_tokens"])
    let total = JSONMetadata.int(object, keys: ["total_tokens", "total_token_count"])

    let tokens = TokenBreakdown(
      inputTokens: input,
      outputTokens: output,
      cachedInputTokens: cached,
      reasoningTokens: reasoning,
      totalTokens: total
    )
    return tokens.calculatedTotal > 0 ? tokens : nil
  }

  private func delta(from previous: TokenBreakdown?, to current: TokenBreakdown) -> TokenBreakdown?
  {
    guard let previous else { return current }

    func subtract(_ current: Int?, _ previous: Int?) -> Int? {
      guard let current else { return nil }
      let value = current - (previous ?? 0)
      return value > 0 ? value : nil
    }

    if let currentTotal = current.totalTokens,
      let previousTotal = previous.totalTokens,
      currentTotal <= previousTotal
    {
      return nil
    }

    let result = TokenBreakdown(
      inputTokens: subtract(current.inputTokens, previous.inputTokens),
      outputTokens: subtract(current.outputTokens, previous.outputTokens),
      cachedInputTokens: subtract(current.cachedInputTokens, previous.cachedInputTokens),
      cacheCreationTokens: subtract(current.cacheCreationTokens, previous.cacheCreationTokens),
      reasoningTokens: subtract(current.reasoningTokens, previous.reasoningTokens),
      otherTokens: subtract(current.otherTokens, previous.otherTokens),
      totalTokens: subtract(current.totalTokens, previous.totalTokens)
    )

    return result.calculatedTotal > 0 ? result : nil
  }
}

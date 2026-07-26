import Foundation

/// Parses OTLP/HTTP JSON `ExportMetricsServiceRequest` bodies captured by
/// `ClaudeTelemetryReceiver`. Each JSONL line is one full export request:
/// `resourceMetrics[].scopeMetrics[].metrics[]` where a metric named
/// `claude_code.token.usage` carries `sum.dataPoints[]`, each tagged with a
/// `type` attribute (`input`/`output`/`cacheRead`/`cacheCreation`) and an
/// `asInt`/`asDouble` count. See https://code.claude.com/docs/en/monitoring-usage.
public struct ClaudeTelemetryParser: Sendable {
  public static let parserVersion = "claude-code-otel-token-usage-otlp-v3"

  private static let tokenUsageMetricName = "claude_code.token.usage"

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
      let resourceMetrics = record.object["resourceMetrics"] as? [[String: Any]] ?? []
      guard !resourceMetrics.isEmpty else {
        invalid += 1
        continue
      }

      for (resourceIndex, resourceMetric) in resourceMetrics.enumerated() {
        let scopeMetrics = resourceMetric["scopeMetrics"] as? [[String: Any]] ?? []
        for (scopeIndex, scopeMetric) in scopeMetrics.enumerated() {
          let metrics = scopeMetric["metrics"] as? [[String: Any]] ?? []
          for (metricIndex, metric) in metrics.enumerated() {
            guard metric["name"] as? String == Self.tokenUsageMetricName else { continue }
            let dataPoints =
              (metric["sum"] as? [String: Any])?["dataPoints"] as? [[String: Any]] ?? []
            for (pointIndex, dataPoint) in dataPoints.enumerated() {
              guard
                let event = makeEvent(
                  dataPoint: dataPoint,
                  sourceFingerprint: sourceFingerprint,
                  privacySalt: privacySalt,
                  importedAt: importedAt,
                  idComponents: [
                    sourceFingerprint, "\(record.offset)", "\(resourceIndex)", "\(scopeIndex)",
                    "\(metricIndex)", "\(pointIndex)",
                  ])
              else {
                invalid += 1
                continue
              }
              events.append(event)
            }
          }
        }
      }
    }

    return CollectionBatch(events: events, importedRecords: events.count, invalidRecords: invalid)
  }

  private func makeEvent(
    dataPoint: [String: Any],
    sourceFingerprint: String,
    privacySalt: String,
    importedAt: Date,
    idComponents: [String]
  ) -> UsageEvent? {
    let attributes = Self.attributeDictionary(dataPoint["attributes"] as? [[String: Any]] ?? [])
    guard let count = Self.dataPointValue(dataPoint), count > 0 else { return nil }

    var tokens = TokenBreakdown()
    switch attributes["type"] {
    case "input": tokens.inputTokens = count
    case "output": tokens.outputTokens = count
    case "cacheRead": tokens.cachedInputTokens = count
    case "cacheCreation": tokens.cacheCreationTokens = count
    default: tokens.otherTokens = count
    }

    let model = attributes["model"]
    let session = attributes["session.id"]
    let timestamp =
      Self.date(fromUnixNanoString: dataPoint["timeUnixNano"] as? String) ?? importedAt
    let id = Hashing.sha256(
      "\(CollectorIdentifier.claudeCode.rawValue)|\(idComponents.joined(separator: "|"))")

    return UsageEvent(
      id: id,
      collector: .claudeCode,
      tool: .claudeCode,
      provider: .anthropic,
      model: model,
      timestamp: timestamp,
      tokens: tokens,
      sessionIdentifierHash: session.map { Hashing.privacyHash($0, salt: privacySalt) },
      projectIdentifierHash: nil,
      sourceKind: .otlpHTTP,
      sourceFingerprint: sourceFingerprint,
      accuracy: .exact,
      parserVersion: Self.parserVersion,
      importedAt: importedAt
    )
  }

  /// OTLP JSON encodes attributes as `[{key, value: {stringValue|intValue|...}}]`.
  private static func attributeDictionary(_ attributes: [[String: Any]]) -> [String: String] {
    var result: [String: String] = [:]
    for attribute in attributes {
      guard let key = attribute["key"] as? String,
        let value = attribute["value"] as? [String: Any]
      else { continue }
      if let string = value["stringValue"] as? String {
        result[key] = string
      } else if let intValue = value["intValue"] {
        result[key] = "\(intValue)"
      } else if let boolValue = value["boolValue"] as? Bool {
        result[key] = boolValue ? "true" : "false"
      }
    }
    return result
  }

  /// int64 sum data point counts (`asInt`) are protobuf-JSON encoded as strings;
  /// `asDouble` is a plain number for non-integer counters.
  private static func dataPointValue(_ dataPoint: [String: Any]) -> Int? {
    if let raw = dataPoint["asInt"] as? String, let value = Int(raw) { return value }
    if let value = dataPoint["asInt"] as? Int { return value }
    if let value = dataPoint["asDouble"] as? Double { return Int(value) }
    return nil
  }

  /// `timeUnixNano` is a protobuf-JSON string of nanoseconds since the epoch.
  private static func date(fromUnixNanoString value: String?) -> Date? {
    guard let value, let nanos = UInt64(value) else { return nil }
    return Date(timeIntervalSince1970: TimeInterval(nanos) / 1_000_000_000)
  }
}

public struct GeminiTelemetryParser: Sendable {
  public static let parserVersion = "gemini-cli-telemetry-token-usage-v2"

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
      let project = JSONMetadata.string(
        attributes,
        keys: [
          "project", "project_id", "workspace", "workspace_id", "cwd", "working_directory",
          "git_root",
        ])
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
          projectIdentifierHash: project.map { Hashing.privacyHash($0, salt: privacySalt) },
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

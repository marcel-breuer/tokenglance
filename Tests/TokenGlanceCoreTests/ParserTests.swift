import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Usage parsers")
struct ParserTests {
  @Test("Codex parser reads per-turn token metadata")
  func codexPerTurn() throws {
    let data = try fixture("Codex/normal.jsonl")
    let batch = CodexUsageParser().parseJSONLines(data, sourceFingerprint: "source")
    #expect(batch.events.count == 2)
    #expect(batch.events[0].tokens.inputTokens == 100)
    #expect(batch.events[0].tokens.cachedInputTokens == 20)
    #expect(batch.events[0].tokens.reasoningTokens == 10)
    #expect(batch.events[0].model == "gpt-5")
  }

  @Test("Codex parser converts cumulative counters to deltas and skips repeats/resets")
  func codexCumulative() throws {
    let data = try fixture("Codex/cumulative.jsonl")
    let batch = CodexUsageParser().parseJSONLines(data, sourceFingerprint: "source")
    #expect(batch.events.count == 2)
    #expect(batch.events[0].tokens.totalTokens == 160)
    #expect(batch.events[1].tokens.totalTokens == 52)
    #expect(batch.events[1].tokens.inputTokens == 30)
  }

  @Test("Codex parser reads nested payload info token metadata")
  func codexPayloadInfo() throws {
    let data = try fixture("Codex/payload-info.jsonl")
    let batch = CodexUsageParser().parseJSONLines(data, sourceFingerprint: "source")
    #expect(batch.events.count == 2)
    #expect(batch.invalidRecords == 1)
    #expect(batch.events[0].tokens.inputTokens == 100)
    #expect(batch.events[0].tokens.cachedInputTokens == 20)
    #expect(batch.events[0].tokens.reasoningTokens == 10)
    #expect(batch.events[1].tokens.totalTokens == 100)
    #expect(batch.events[1].tokens.inputTokens == 60)
  }

  @Test("Codex parser ignores partial JSON and does not persist text fields")
  func codexPartialPrivacy() throws {
    let data = try fixture("Codex/partial.jsonl")
    let batch = CodexUsageParser().parseJSONLines(data, sourceFingerprint: "source")
    #expect(batch.events.count == 1)
    let encoded = String(data: try JSONEncoder().encode(batch.events), encoding: .utf8) ?? ""
    #expect(!encoded.contains("SYNTHETIC_SECRET_PROMPT_SHOULD_NOT_APPEAR"))
  }

  @Test("Claude telemetry parser extracts supported token categories")
  func claudeTelemetry() throws {
    let data = try fixture("ClaudeCode/telemetry.jsonl")
    let batch = ClaudeTelemetryParser().parseJSONLines(data, sourceFingerprint: "claude")
    #expect(batch.events.count == 1)
    #expect(batch.events[0].tokens.inputTokens == 80)
    #expect(batch.events[0].tokens.cacheCreationTokens == 6)
    #expect(batch.events[0].provider == .anthropic)
  }

  @Test("Google telemetry parser extracts token categories")
  func googleTelemetry() throws {
    let data = try fixture("GeminiCLI/telemetry.jsonl")
    let batch = GeminiTelemetryParser().parseJSONLines(data, sourceFingerprint: "gemini")
    #expect(batch.events.count == 1)
    #expect(batch.events[0].tokens.outputTokens == 40)
    #expect(batch.events[0].tokens.reasoningTokens == 7)
    #expect(batch.events[0].provider == .google)
    #expect(batch.events[0].tool == .antigravity)
  }
}

private func fixture(_ path: String) throws -> Data {
  let url = Bundle.module.resourceURL!.appendingPathComponent("Fixtures").appendingPathComponent(
    path)
  return try Data(contentsOf: url)
}

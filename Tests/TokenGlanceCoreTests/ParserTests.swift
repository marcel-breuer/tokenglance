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
    #expect(batch.invalidRecords == 2)
    #expect(batch.events[0].model == "gpt-5.4")
    #expect(batch.events[1].model == "gpt-5.4")
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

  @Test("Manual CSV import accepts general AI tool metadata")
  func manualCSVImport() throws {
    let csv = """
      timestamp,tool,provider,model,input_tokens,output_tokens,cached_input_tokens,reasoning_tokens,total_tokens
      2026-06-29T08:00:00Z,ChatGPT,openai,gpt-4o,120,40,10,0,170
      2026-06-29T09:00:00Z,Claude,anthropic,claude-3.7-sonnet,90,55,0,12,157
      2026-06-29T10:00:00Z,Gemini,google,gemini-2.5-pro,80,60,5,20,165
      """
    let batch = try ManualUsageImportParser().parse(
      Data(csv.utf8), sourceName: "general-ai.csv")

    #expect(batch.events.count == 3)
    #expect(batch.invalidRecords == 0)
    #expect(batch.events.map(\.tool) == [.chatGPT, .claude, .gemini])
    #expect(batch.events.map(\.provider) == [.openAI, .anthropic, .google])
    #expect(batch.events[0].collector == .manualImport)
    #expect(batch.events[0].sourceKind == .manualImport)
    #expect(batch.events[2].tokens.reasoningTokens == 20)
  }

  @Test("Manual JSON import ignores raw conversation fields")
  func manualJSONImportPrivacy() throws {
    let json = """
      {
        "events": [
          {
            "timestamp": "2026-06-29T11:00:00Z",
            "tool": "openai-api",
            "model": "gpt-4.1",
            "input_tokens": 20,
            "output_tokens": 30,
            "prompt": "SYNTHETIC_SECRET_PROMPT_SHOULD_NOT_APPEAR",
            "response": "SYNTHETIC_SECRET_RESPONSE_SHOULD_NOT_APPEAR"
          }
        ]
      }
      """
    let batch = try ManualUsageImportParser().parse(
      Data(json.utf8), sourceName: "api-usage.json")

    #expect(batch.events.count == 1)
    #expect(batch.events[0].tool == .openAIAPI)
    #expect(batch.events[0].provider == .openAI)
    let encoded = String(data: try JSONEncoder().encode(batch.events), encoding: .utf8) ?? ""
    #expect(!encoded.contains("SYNTHETIC_SECRET_PROMPT_SHOULD_NOT_APPEAR"))
    #expect(!encoded.contains("SYNTHETIC_SECRET_RESPONSE_SHOULD_NOT_APPEAR"))
  }

  @Test("General AI tools are available for filtering")
  func generalAIToolsAreFilterable() {
    #expect(ToolIdentifier.allCases.contains(.chatGPT))
    #expect(ToolIdentifier.allCases.contains(.claude))
    #expect(ToolIdentifier.allCases.contains(.gemini))
    #expect(ToolIdentifier.allCases.contains(.openAIAPI))
    #expect(ToolIdentifier.allCases.contains(.anthropicAPI))
    #expect(ToolIdentifier.allCases.contains(.googleAIAPI))
  }
}

private func fixture(_ path: String) throws -> Data {
  let url = Bundle.module.resourceURL!.appendingPathComponent("Fixtures").appendingPathComponent(
    path)
  return try Data(contentsOf: url)
}

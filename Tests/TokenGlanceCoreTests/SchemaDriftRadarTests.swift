import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Schema drift radar")
struct SchemaDriftRadarTests {
  @Test("Marks diagnostics as unsupported schema when invalid metadata is found without events")
  func marksUnsupportedSchema() {
    let base = CollectorDiagnostic(
      identifier: .codexCLI,
      status: .detected,
      sourceKind: .localJSONL,
      parserVersion: "test",
      explanation: "Detected.",
      detectedVersion: "1.0")
    let batch = CollectionBatch(events: [], invalidRecords: 3)

    let diagnostic = SchemaDriftRadar().diagnose(base: base, batch: batch)

    #expect(diagnostic.status == .unsupportedSchema)
    #expect(diagnostic.lastNonSensitiveError == "3 unsupported metadata records were skipped.")
  }

  @Test("Keeps base diagnostics when events are imported")
  func keepsBaseDiagnosticWhenEventsImport() {
    let base = CollectorDiagnostic(
      identifier: .codexCLI,
      status: .detected,
      sourceKind: .localJSONL,
      parserVersion: "test",
      explanation: "Detected.",
      detectedVersion: "1.0")
    let event = UsageEvent(
      id: "event",
      collector: .codexCLI,
      tool: .codexCLI,
      provider: .openAI,
      model: "gpt",
      timestamp: Date(),
      tokens: TokenBreakdown(totalTokens: 1),
      sessionIdentifierHash: nil,
      projectIdentifierHash: nil,
      sourceKind: .localJSONL,
      sourceFingerprint: "fixture",
      accuracy: .exact,
      parserVersion: "test")
    let batch = CollectionBatch(events: [event], invalidRecords: 3)

    #expect(SchemaDriftRadar().diagnose(base: base, batch: batch) == base)
  }
}

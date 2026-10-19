import Testing

@testable import TokenGlanceCore

@Suite("Privacy redaction")
struct PrivacyTests {
  @Test("Redactor removes home paths and secrets")
  func redactsSensitiveDiagnostics() {
    let input = "/Users/marcel/project token=abc123456789 email person@example.com"
    let output = Redactor().redact(input)
    #expect(!output.contains("/Users/marcel"))
    #expect(!output.contains("abc123456789"))
    #expect(!output.contains("person@example.com"))
  }

  @Test("Diagnostics redact labelled conversation data, paths, and identifiers")
  func diagnosticsRedactSensitiveFields() {
    let diagnostic = CollectorDiagnostic(
      identifier: .codexCLI,
      status: .parserError,
      sourceKind: .localJSONL,
      parserVersion: "test-parser",
      explanation:
        """
        path="/Users/marcel/private project/session.jsonl"; prompt="SYNTHETIC_PROMPT_TEXT";
        response='SYNTHETIC_RESPONSE_TEXT'; source_code="SYNTHETIC_SOURCE_TEXT";
        session_id=synthetic-session-123; cookie=synthetic-cookie-123
        """,
      detectedVersion: nil
    )
    let report = DiagnosticsReport(
      appVersion: "test",
      macOSVersion: "test OS",
      architecture: "arm64",
      databaseSchemaVersion: 1,
      collectors: [diagnostic]
    )

    let output = report.text()

    #expect(!output.contains("/Users/marcel"))
    #expect(!output.contains("private project"))
    #expect(!output.contains("SYNTHETIC_PROMPT_TEXT"))
    #expect(!output.contains("SYNTHETIC_RESPONSE_TEXT"))
    #expect(!output.contains("SYNTHETIC_SOURCE_TEXT"))
    #expect(!output.contains("synthetic-session-123"))
    #expect(!output.contains("synthetic-cookie-123"))
  }
}

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
}

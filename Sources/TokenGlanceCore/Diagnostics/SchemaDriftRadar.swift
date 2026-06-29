import Foundation

public struct SchemaDriftRadar: Sendable {
  public init() {}

  public func diagnose(base: CollectorDiagnostic, batch: CollectionBatch) -> CollectorDiagnostic {
    guard batch.events.isEmpty, batch.invalidRecords > 0 else { return base }
    return CollectorDiagnostic(
      identifier: base.identifier,
      status: .unsupportedSchema,
      sourceKind: base.sourceKind,
      parserVersion: base.parserVersion,
      explanation:
        "Local metadata was found, but no supported token schema was recognized. The tool may have changed its local metadata format.",
      detectedVersion: base.detectedVersion,
      lastNonSensitiveError: "\(batch.invalidRecords) unsupported metadata records were skipped."
    )
  }
}

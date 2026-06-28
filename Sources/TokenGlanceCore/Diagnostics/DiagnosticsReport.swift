import Foundation

public struct DiagnosticsReport: Sendable {
  public let appVersion: String
  public let macOSVersion: String
  public let architecture: String
  public let databaseSchemaVersion: Int
  public let collectors: [CollectorDiagnostic]

  public init(
    appVersion: String, macOSVersion: String, architecture: String, databaseSchemaVersion: Int,
    collectors: [CollectorDiagnostic]
  ) {
    self.appVersion = appVersion
    self.macOSVersion = macOSVersion
    self.architecture = architecture
    self.databaseSchemaVersion = databaseSchemaVersion
    self.collectors = collectors
  }

  public func text(redactor: Redactor = Redactor()) -> String {
    var lines = [
      "TokenGlance \(appVersion)",
      "macOS: \(macOSVersion)",
      "Architecture: \(architecture)",
      "Database schema: \(databaseSchemaVersion)",
    ]
    for collector in collectors {
      lines.append(
        "\(collector.identifier.displayName): \(collector.status.rawValue), parser \(collector.parserVersion), version \(collector.detectedVersion ?? "unknown")"
      )
      lines.append("  \(collector.explanation)")
    }
    return redactor.redact(lines.joined(separator: "\n"))
  }
}

public struct DiagnosticsBuilder: Sendable {
  public init() {}

  public func build(database: UsageDatabase, collectors: [any UsageCollector]) async
    -> DiagnosticsReport
  {
    let schema = (try? await database.schemaVersion()) ?? 0
    var diagnostics: [CollectorDiagnostic] = []
    for collector in collectors {
      diagnostics.append(await collector.diagnose())
    }
    return DiagnosticsReport(
      appVersion: AppIdentity.version,
      macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
      architecture: ProcessInfo.processInfo.machineHardwareName,
      databaseSchemaVersion: schema,
      collectors: diagnostics
    )
  }
}

extension ProcessInfo {
  fileprivate var machineHardwareName: String {
    #if arch(arm64)
      return "arm64"
    #else
      return "unsupported"
    #endif
  }
}

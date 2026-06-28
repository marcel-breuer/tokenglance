import Foundation

public struct CodexCLICollector: UsageCollector {
  public let identifier: CollectorIdentifier = .codexCLI
  public let displayName = "Codex CLI"
  public let capabilities: CollectorCapabilities = [
    .inputTokens,
    .outputTokens,
    .cachedInputTokens,
    .reasoningTokens,
    .modelIdentifier,
    .sessionIdentifier,
    .exactTimestamp,
    .historicalImport,
    .incrementalUpdates,
  ]

  private let detector: CommandLineToolDetector
  private let sourceDirectory: URL
  private let parser: CodexUsageParser

  public init(
    detector: CommandLineToolDetector = CommandLineToolDetector(),
    sourceDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
      ".codex/sessions", isDirectory: true),
    parser: CodexUsageParser = CodexUsageParser()
  ) {
    self.detector = detector
    self.sourceDirectory = sourceDirectory
    self.parser = parser
  }

  public func detect() async -> CollectorDetectionResult {
    guard let path = detector.locate("codex") else {
      return CollectorDetectionResult(
        identifier: identifier, status: .notInstalled, executablePath: nil, version: nil,
        explanation: "Codex CLI executable was not found on PATH.")
    }
    return CollectorDetectionResult(
      identifier: identifier,
      status: .detected,
      executablePath: path,
      version: detector.version(executablePath: path),
      explanation:
        "Codex CLI is installed. TokenGlance reads token metadata from local Codex session JSONL files only."
    )
  }

  public func collect(since cursor: CollectionCursor?) async throws -> CollectionBatch {
    try Task.checkCancellation()
    let files = try sourceFiles()
    var allEvents: [UsageEvent] = []
    var cursors: [CollectionCursor] = []
    var invalid = 0

    for file in files {
      try Task.checkCancellation()
      guard let resolved = try? safeResolvedFile(file) else { continue }
      let fingerprint = Hashing.sha256(resolved.path)
      let handle = try FileHandle(forReadingFrom: resolved)
      defer { try? handle.close() }

      let startOffset = cursor?.sourceFingerprint == fingerprint ? cursor?.offset ?? 0 : 0
      try handle.seek(toOffset: startOffset)
      let data = try handle.readToEnd() ?? Data()
      let batch = parser.parseJSONLines(data, sourceFingerprint: fingerprint)
      allEvents.append(contentsOf: batch.events)
      invalid += batch.invalidRecords
      let endOffset = try handle.offset()
      cursors.append(CollectionCursor(sourceFingerprint: fingerprint, offset: endOffset))
    }

    return CollectionBatch(
      events: allEvents, cursors: cursors, importedRecords: allEvents.count, invalidRecords: invalid
    )
  }

  public func diagnose() async -> CollectorDiagnostic {
    let detection = await detect()
    return CollectorDiagnostic(
      identifier: identifier,
      status: detection.status,
      sourceKind: .localJSONL,
      parserVersion: CodexUsageParser.parserVersion,
      explanation: detection.explanation,
      detectedVersion: detection.version
    )
  }

  private func sourceFiles() throws -> [URL] {
    guard FileManager.default.fileExists(atPath: sourceDirectory.path) else { return [] }
    let enumerator = FileManager.default.enumerator(
      at: sourceDirectory,
      includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
      options: [.skipsHiddenFiles, .skipsPackageDescendants]
    )
    var files: [URL] = []
    while let url = enumerator?.nextObject() as? URL {
      guard url.pathExtension == "jsonl" else { continue }
      let values = try url.resourceValues(forKeys: [
        .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
      ])
      guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
      if let size = values.fileSize, size > 50 * 1024 * 1024 { continue }
      files.append(url)
    }
    return files.sorted { $0.path < $1.path }
  }

  private func safeResolvedFile(_ url: URL) throws -> URL {
    let root = sourceDirectory.standardizedFileURL.resolvingSymlinksInPath().path
    let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
    guard resolved.path.hasPrefix(root + "/") else {
      throw CocoaError(.fileReadNoPermission)
    }
    return resolved
  }
}

public struct ClaudeCodeCollector: UsageCollector {
  public let identifier: CollectorIdentifier = .claudeCode
  public let displayName = "Claude Code"
  public let capabilities: CollectorCapabilities = [
    .inputTokens,
    .outputTokens,
    .cachedInputTokens,
    .cacheCreationTokens,
    .modelIdentifier,
    .sessionIdentifier,
    .exactTimestamp,
    .liveUpdates,
  ]

  private let detector: CommandLineToolDetector

  public init(detector: CommandLineToolDetector = CommandLineToolDetector()) {
    self.detector = detector
  }

  public func detect() async -> CollectorDetectionResult {
    guard let path = detector.locate("claude") else {
      return CollectorDetectionResult(
        identifier: identifier, status: .notInstalled, executablePath: nil, version: nil,
        explanation: "Claude Code executable was not found on PATH.")
    }
    return CollectorDetectionResult(
      identifier: identifier,
      status: .setupRequired,
      executablePath: path,
      version: detector.version(executablePath: path),
      explanation:
        "Claude Code is installed. TokenGlance requires local OpenTelemetry token usage output to be explicitly configured; it will not edit Claude settings automatically."
    )
  }

  public func collect(since cursor: CollectionCursor?) async throws -> CollectionBatch {
    _ = cursor
    return CollectionBatch(events: [], importedRecords: 0)
  }

  public func diagnose() async -> CollectorDiagnostic {
    let detection = await detect()
    return CollectorDiagnostic(
      identifier: identifier,
      status: detection.status,
      sourceKind: .localTelemetry,
      parserVersion: ClaudeTelemetryParser.parserVersion,
      explanation: detection.explanation,
      detectedVersion: detection.version
    )
  }
}

public struct AntigravityCollector: UsageCollector {
  public let identifier: CollectorIdentifier = .antigravity
  public let displayName = "Antigravity"
  public let capabilities: CollectorCapabilities = [
    .inputTokens,
    .outputTokens,
    .cachedInputTokens,
    .reasoningTokens,
    .modelIdentifier,
    .sessionIdentifier,
    .exactTimestamp,
    .liveUpdates,
  ]

  private let detector: CommandLineToolDetector

  public init(detector: CommandLineToolDetector = CommandLineToolDetector()) {
    self.detector = detector
  }

  public func detect() async -> CollectorDetectionResult {
    guard let path = detector.locate("agy") else {
      return CollectorDetectionResult(
        identifier: identifier, status: .notInstalled, executablePath: nil, version: nil,
        explanation:
          "Antigravity CLI executable 'agy' was not found on PATH or standard Homebrew paths."
      )
    }
    return CollectorDetectionResult(
      identifier: identifier,
      status: .setupRequired,
      executablePath: path,
      version: detector.version(executablePath: path),
      explanation:
        "Antigravity CLI is installed. TokenGlance has not yet verified a documented local token metadata source, so it will not read Antigravity conversations, logs, or browser-style storage."
    )
  }

  public func collect(since cursor: CollectionCursor?) async throws -> CollectionBatch {
    _ = cursor
    return CollectionBatch(events: [], importedRecords: 0)
  }

  public func diagnose() async -> CollectorDiagnostic {
    let detection = await detect()
    return CollectorDiagnostic(
      identifier: identifier,
      status: detection.status,
      sourceKind: .unsupported,
      parserVersion: "antigravity-detection-v1",
      explanation: detection.explanation,
      detectedVersion: detection.version
    )
  }
}

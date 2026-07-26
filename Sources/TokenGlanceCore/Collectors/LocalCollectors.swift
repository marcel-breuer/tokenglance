import Foundation

/// Scans a set of directories for `.jsonl` files a collector should read, shared
/// between collectors that read local session/telemetry logs from disk. Rejects
/// symlinks and files above `maxFileSizeBytes`, and confines resolved reads to
/// the configured directories to avoid following a crafted path outside them.
struct JSONLDirectoryScanner: Sendable {
  let sourceDirectories: [URL]
  let maxFileSizeBytes: Int

  init(sourceDirectories: [URL], maxFileSizeBytes: Int = 50 * 1024 * 1024) {
    self.sourceDirectories = sourceDirectories
    self.maxFileSizeBytes = maxFileSizeBytes
  }

  func files() throws -> [URL] {
    var files: [URL] = []
    var visitedRoots: Set<String> = []

    for sourceDirectory in sourceDirectories {
      let root = sourceDirectory.standardizedFileURL.resolvingSymlinksInPath().path
      guard visitedRoots.insert(root).inserted else { continue }
      guard FileManager.default.fileExists(atPath: sourceDirectory.path) else { continue }
      let enumerator = FileManager.default.enumerator(
        at: sourceDirectory,
        includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
      )
      while let url = enumerator?.nextObject() as? URL {
        guard url.pathExtension == "jsonl" else { continue }
        let values = try url.resourceValues(forKeys: [
          .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
        ])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
        if let size = values.fileSize, size > maxFileSizeBytes { continue }
        files.append(url)
      }
    }

    return files.sorted { $0.path < $1.path }
  }

  func safeResolvedFile(_ url: URL) throws -> URL {
    let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
    let isAllowed = sourceDirectories.contains { sourceDirectory in
      let root = sourceDirectory.standardizedFileURL.resolvingSymlinksInPath().path
      return resolved.path.hasPrefix(root + "/")
    }
    guard isAllowed else {
      throw CocoaError(.fileReadNoPermission)
    }
    return resolved
  }
}

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
  private let scanner: JSONLDirectoryScanner
  private let parser: CodexUsageParser

  public static var defaultSourceDirectories: [URL] {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return [
      home.appendingPathComponent(".codex/sessions", isDirectory: true),
      home.appendingPathComponent(".codex/archived_sessions", isDirectory: true),
    ]
  }

  public init(
    detector: CommandLineToolDetector = CommandLineToolDetector(),
    sourceDirectories: [URL] = Self.defaultSourceDirectories,
    parser: CodexUsageParser = CodexUsageParser()
  ) {
    self.detector = detector
    self.scanner = JSONLDirectoryScanner(sourceDirectories: sourceDirectories)
    self.parser = parser
  }

  public init(
    detector: CommandLineToolDetector = CommandLineToolDetector(),
    sourceDirectory: URL,
    parser: CodexUsageParser = CodexUsageParser()
  ) {
    self.detector = detector
    self.scanner = JSONLDirectoryScanner(sourceDirectories: [sourceDirectory])
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

  public func collect(since cursors: [CollectionCursor]) async throws -> CollectionBatch {
    try Task.checkCancellation()
    let files = try scanner.files()
    let knownOffsets = Dictionary(uniqueKeysWithValues: cursors.map { ($0.sourceFingerprint, $0) })
    var allEvents: [UsageEvent] = []
    var nextCursors: [CollectionCursor] = []
    var invalid = 0

    for file in files {
      try Task.checkCancellation()
      guard let resolved = try? scanner.safeResolvedFile(file) else { continue }
      let fingerprint = Hashing.sha256(resolved.path)
      let fileSize = try resolved.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      if let cursor = knownOffsets[fingerprint], cursor.offset == UInt64(fileSize) {
        nextCursors.append(cursor)
        continue
      }
      let handle = try FileHandle(forReadingFrom: resolved)
      defer { try? handle.close() }

      let data = try handle.readToEnd() ?? Data()
      let batch = parser.parseJSONLines(data, sourceFingerprint: fingerprint)
      allEvents.append(contentsOf: batch.events)
      invalid += batch.invalidRecords
      let endOffset = try handle.offset()
      nextCursors.append(CollectionCursor(sourceFingerprint: fingerprint, offset: endOffset))
    }

    return CollectionBatch(
      events: allEvents, cursors: nextCursors, importedRecords: allEvents.count,
      invalidRecords: invalid
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
  private let scanner: JSONLDirectoryScanner
  private let parser: ClaudeTelemetryParser

  /// TokenGlance's own local OTLP receiver writes here; see `ClaudeTelemetryReceiver`.
  public static var defaultSourceDirectories: [URL] {
    [AppIdentity.applicationSupportDirectory.appendingPathComponent("claude-otel", isDirectory: true)]
  }

  static let setupInstructions = """
    export CLAUDE_CODE_ENABLE_TELEMETRY=1
    export OTEL_METRICS_EXPORTER=otlp
    export OTEL_EXPORTER_OTLP_PROTOCOL=http/json
    export OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:\(ClaudeTelemetryReceiver.defaultPort)
    """

  public init(
    detector: CommandLineToolDetector = CommandLineToolDetector(),
    sourceDirectories: [URL] = Self.defaultSourceDirectories,
    parser: ClaudeTelemetryParser = ClaudeTelemetryParser()
  ) {
    self.detector = detector
    self.scanner = JSONLDirectoryScanner(sourceDirectories: sourceDirectories)
    self.parser = parser
  }

  public func detect() async -> CollectorDetectionResult {
    guard let path = detector.locate("claude") else {
      return CollectorDetectionResult(
        identifier: identifier, status: .notInstalled, executablePath: nil, version: nil,
        explanation: "Claude Code executable was not found on PATH.")
    }
    let version = detector.version(executablePath: path)
    let files = (try? scanner.files()) ?? []
    guard !files.isEmpty else {
      return CollectorDetectionResult(
        identifier: identifier,
        status: .setupRequired,
        executablePath: path,
        version: version,
        explanation:
          """
          Claude Code is installed. TokenGlance will not edit Claude settings automatically \
          — set these in your shell profile so Claude Code sends token usage to TokenGlance's \
          local receiver, then restart Claude Code:

          \(Self.setupInstructions)
          """
      )
    }
    let hasData = files.contains { url in
      (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { $0 } ?? 0 > 0
    }
    guard hasData else {
      return CollectorDetectionResult(
        identifier: identifier,
        status: .waitingForData,
        executablePath: path,
        version: version,
        explanation:
          "TokenGlance's local telemetry receiver is ready but hasn't received any Claude Code token usage yet. Start a Claude Code session after configuring telemetry."
      )
    }
    return CollectorDetectionResult(
      identifier: identifier,
      status: .detected,
      executablePath: path,
      version: version,
      explanation: "TokenGlance is receiving Claude Code OpenTelemetry token usage locally."
    )
  }

  public func collect(since cursors: [CollectionCursor]) async throws -> CollectionBatch {
    try Task.checkCancellation()
    let files = try scanner.files()
    let knownOffsets = Dictionary(uniqueKeysWithValues: cursors.map { ($0.sourceFingerprint, $0) })
    var allEvents: [UsageEvent] = []
    var nextCursors: [CollectionCursor] = []
    var invalid = 0

    for file in files {
      try Task.checkCancellation()
      guard let resolved = try? scanner.safeResolvedFile(file) else { continue }
      let fingerprint = Hashing.sha256(resolved.path)
      let fileSize = try resolved.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      if let cursor = knownOffsets[fingerprint], cursor.offset == UInt64(fileSize) {
        nextCursors.append(cursor)
        continue
      }
      let handle = try FileHandle(forReadingFrom: resolved)
      defer { try? handle.close() }

      let data = try handle.readToEnd() ?? Data()
      let batch = parser.parseJSONLines(data, sourceFingerprint: fingerprint)
      allEvents.append(contentsOf: batch.events)
      invalid += batch.invalidRecords
      let endOffset = try handle.offset()
      nextCursors.append(CollectionCursor(sourceFingerprint: fingerprint, offset: endOffset))
    }

    return CollectionBatch(
      events: allEvents, cursors: nextCursors, importedRecords: allEvents.count,
      invalidRecords: invalid
    )
  }

  public func diagnose() async -> CollectorDiagnostic {
    let detection = await detect()
    return CollectorDiagnostic(
      identifier: identifier,
      status: detection.status,
      sourceKind: .otlpHTTP,
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

  public func collect(since cursors: [CollectionCursor]) async throws -> CollectionBatch {
    _ = cursors
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

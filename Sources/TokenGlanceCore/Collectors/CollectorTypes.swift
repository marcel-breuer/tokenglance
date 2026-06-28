import Foundation

public struct CollectorCapabilities: OptionSet, Sendable, Codable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static let inputTokens = CollectorCapabilities(rawValue: 1 << 0)
  public static let outputTokens = CollectorCapabilities(rawValue: 1 << 1)
  public static let cachedInputTokens = CollectorCapabilities(rawValue: 1 << 2)
  public static let cacheCreationTokens = CollectorCapabilities(rawValue: 1 << 3)
  public static let reasoningTokens = CollectorCapabilities(rawValue: 1 << 4)
  public static let modelIdentifier = CollectorCapabilities(rawValue: 1 << 5)
  public static let sessionIdentifier = CollectorCapabilities(rawValue: 1 << 6)
  public static let exactTimestamp = CollectorCapabilities(rawValue: 1 << 7)
  public static let historicalImport = CollectorCapabilities(rawValue: 1 << 8)
  public static let incrementalUpdates = CollectorCapabilities(rawValue: 1 << 9)
  public static let liveUpdates = CollectorCapabilities(rawValue: 1 << 10)
}

public enum CollectorStatus: String, Codable, Sendable {
  case detected
  case active
  case disabled
  case notInstalled
  case waitingForData
  case setupRequired
  case permissionDenied
  case unsupportedVersion
  case unsupportedSchema
  case partialSupport
  case parserError
  case sourceUnavailable
}

public struct CollectorDetectionResult: Codable, Equatable, Sendable {
  public let identifier: CollectorIdentifier
  public let status: CollectorStatus
  public let executablePath: String?
  public let version: String?
  public let explanation: String

  public init(
    identifier: CollectorIdentifier,
    status: CollectorStatus,
    executablePath: String?,
    version: String?,
    explanation: String
  ) {
    self.identifier = identifier
    self.status = status
    self.executablePath = executablePath
    self.version = version
    self.explanation = explanation
  }
}

public struct CollectionCursor: Codable, Equatable, Sendable {
  public let sourceFingerprint: String
  public let offset: UInt64
  public let updatedAt: Date

  public init(sourceFingerprint: String, offset: UInt64, updatedAt: Date = Date()) {
    self.sourceFingerprint = sourceFingerprint
    self.offset = offset
    self.updatedAt = updatedAt
  }
}

public struct CollectionBatch: Codable, Equatable, Sendable {
  public let events: [UsageEvent]
  public let cursors: [CollectionCursor]
  public let importedRecords: Int
  public let skippedDuplicateRecords: Int
  public let invalidRecords: Int

  public init(
    events: [UsageEvent],
    cursors: [CollectionCursor] = [],
    importedRecords: Int = 0,
    skippedDuplicateRecords: Int = 0,
    invalidRecords: Int = 0
  ) {
    self.events = events
    self.cursors = cursors
    self.importedRecords = importedRecords
    self.skippedDuplicateRecords = skippedDuplicateRecords
    self.invalidRecords = invalidRecords
  }
}

public struct CollectorDiagnostic: Codable, Equatable, Sendable {
  public let identifier: CollectorIdentifier
  public let status: CollectorStatus
  public let sourceKind: SourceKind
  public let parserVersion: String
  public let explanation: String
  public let detectedVersion: String?
  public let lastNonSensitiveError: String?

  public init(
    identifier: CollectorIdentifier,
    status: CollectorStatus,
    sourceKind: SourceKind,
    parserVersion: String,
    explanation: String,
    detectedVersion: String?,
    lastNonSensitiveError: String? = nil
  ) {
    self.identifier = identifier
    self.status = status
    self.sourceKind = sourceKind
    self.parserVersion = parserVersion
    self.explanation = explanation
    self.detectedVersion = detectedVersion
    self.lastNonSensitiveError = lastNonSensitiveError
  }
}

public protocol UsageCollector: Sendable {
  var identifier: CollectorIdentifier { get }
  var displayName: String { get }
  var capabilities: CollectorCapabilities { get }

  func detect() async -> CollectorDetectionResult
  func collect(since cursor: CollectionCursor?) async throws -> CollectionBatch
  func diagnose() async -> CollectorDiagnostic
}

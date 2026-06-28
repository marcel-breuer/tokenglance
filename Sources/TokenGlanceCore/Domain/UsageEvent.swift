import Foundation

public enum CollectorIdentifier: String, Codable, CaseIterable, Sendable {
  case codexCLI = "codex-cli"
  case claudeCode = "claude-code"
  case antigravity = "antigravity"
  case geminiCLI = "gemini-cli"

  public static let allCases: [CollectorIdentifier] = [
    .codexCLI,
    .claudeCode,
    .antigravity,
  ]

  public var displayName: String {
    switch self {
    case .codexCLI: "Codex CLI"
    case .claudeCode: "Claude Code"
    case .antigravity: "Antigravity"
    case .geminiCLI: "Gemini CLI Legacy"
    }
  }
}

public enum ToolIdentifier: String, Codable, CaseIterable, Sendable {
  case codexCLI = "codex-cli"
  case claudeCode = "claude-code"
  case antigravity = "antigravity"
  case geminiCLI = "gemini-cli"

  public static let allCases: [ToolIdentifier] = [
    .codexCLI,
    .claudeCode,
    .antigravity,
  ]
}

public enum ProviderIdentifier: String, Codable, Sendable {
  case openAI = "openai"
  case anthropic = "anthropic"
  case google = "google"
}

public enum SourceKind: String, Codable, Sendable {
  case localJSONL = "local-jsonl"
  case localTelemetry = "local-telemetry"
  case otlpHTTP = "otlp-http"
  case unsupported = "unsupported"
}

public enum UsageAccuracy: String, Codable, Sendable {
  case exact
  case partial
  case unavailable
}

public struct TokenBreakdown: Codable, Equatable, Sendable {
  public var inputTokens: Int?
  public var outputTokens: Int?
  public var cachedInputTokens: Int?
  public var cacheCreationTokens: Int?
  public var reasoningTokens: Int?
  public var otherTokens: Int?
  public var totalTokens: Int?

  public init(
    inputTokens: Int? = nil,
    outputTokens: Int? = nil,
    cachedInputTokens: Int? = nil,
    cacheCreationTokens: Int? = nil,
    reasoningTokens: Int? = nil,
    otherTokens: Int? = nil,
    totalTokens: Int? = nil
  ) {
    self.inputTokens = inputTokens
    self.outputTokens = outputTokens
    self.cachedInputTokens = cachedInputTokens
    self.cacheCreationTokens = cacheCreationTokens
    self.reasoningTokens = reasoningTokens
    self.otherTokens = otherTokens
    self.totalTokens = totalTokens
  }

  public var calculatedTotal: Int {
    if let totalTokens { return totalTokens }
    return [
      inputTokens,
      outputTokens,
      cachedInputTokens,
      cacheCreationTokens,
      reasoningTokens,
      otherTokens,
    ].compactMap(\.self).reduce(0, +)
  }
}

public struct UsageEvent: Codable, Identifiable, Equatable, Sendable {
  public let id: String
  public let collector: CollectorIdentifier
  public let tool: ToolIdentifier
  public let provider: ProviderIdentifier
  public let model: String?
  public let timestamp: Date
  public let tokens: TokenBreakdown
  public let sessionIdentifierHash: String?
  public let projectIdentifierHash: String?
  public let sourceKind: SourceKind
  public let sourceFingerprint: String
  public let accuracy: UsageAccuracy
  public let parserVersion: String
  public let importedAt: Date

  public init(
    id: String,
    collector: CollectorIdentifier,
    tool: ToolIdentifier,
    provider: ProviderIdentifier,
    model: String?,
    timestamp: Date,
    tokens: TokenBreakdown,
    sessionIdentifierHash: String?,
    projectIdentifierHash: String?,
    sourceKind: SourceKind,
    sourceFingerprint: String,
    accuracy: UsageAccuracy,
    parserVersion: String,
    importedAt: Date = Date()
  ) {
    self.id = id
    self.collector = collector
    self.tool = tool
    self.provider = provider
    self.model = model
    self.timestamp = timestamp
    self.tokens = tokens
    self.sessionIdentifierHash = sessionIdentifierHash
    self.projectIdentifierHash = projectIdentifierHash
    self.sourceKind = sourceKind
    self.sourceFingerprint = sourceFingerprint
    self.accuracy = accuracy
    self.parserVersion = parserVersion
    self.importedAt = importedAt
  }
}

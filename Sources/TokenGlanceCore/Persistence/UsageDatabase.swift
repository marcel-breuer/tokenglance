import Foundation
import SQLite3

public actor UsageDatabase {
  private let url: URL
  private var db: OpaquePointer?

  public init(
    url: URL = AppIdentity.applicationSupportDirectory.appendingPathComponent("TokenGlance.sqlite")
  ) {
    self.url = url
  }

  public func open() throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard
      sqlite3_open_v2(
        url.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        == SQLITE_OK
    else {
      throw DatabaseError.openFailed(message: lastError)
    }
    try execute("PRAGMA journal_mode = WAL")
    try execute("PRAGMA foreign_keys = ON")
    try migrate()
  }

  public func importBatch(_ batch: CollectionBatch) throws -> Int {
    try ensureOpen()
    try execute("BEGIN IMMEDIATE TRANSACTION")
    do {
      var inserted = 0
      for event in batch.events {
        inserted += try insert(event) ? 1 : 0
      }
      for cursor in batch.cursors {
        try upsert(cursor)
      }
      try execute("COMMIT")
      return inserted
    } catch {
      try? execute("ROLLBACK")
      throw error
    }
  }

  public func fetchEvents(from start: Date, to end: Date) throws -> [UsageEvent] {
    try ensureOpen()
    let sql = """
      SELECT id, collector, tool, provider, model, timestamp, input_tokens, output_tokens,
             cached_input_tokens, cache_creation_tokens, reasoning_tokens, other_tokens,
             total_tokens, session_hash, project_hash, source_kind, source_fingerprint,
             accuracy, parser_version, imported_at
      FROM usage_events
      WHERE timestamp >= ? AND timestamp < ?
      ORDER BY timestamp ASC
      """
    let statement = try prepare(sql)
    defer { sqlite3_finalize(statement) }
    sqlite3_bind_double(statement, 1, start.timeIntervalSince1970)
    sqlite3_bind_double(statement, 2, end.timeIntervalSince1970)

    var events: [UsageEvent] = []
    while sqlite3_step(statement) == SQLITE_ROW {
      events.append(try rowEvent(statement))
    }
    return events
  }

  public func allModels() throws -> [String] {
    try ensureOpen()
    let statement = try prepare(
      "SELECT DISTINCT model FROM usage_events WHERE model IS NOT NULL ORDER BY model")
    defer { sqlite3_finalize(statement) }
    var models: [String] = []
    while sqlite3_step(statement) == SQLITE_ROW {
      if let value = columnString(statement, 0) {
        models.append(value)
      }
    }
    return models
  }

  public func deleteAllData() throws {
    try ensureOpen()
    try execute("DELETE FROM usage_events")
    try execute("DELETE FROM collection_cursors")
    try execute("VACUUM")
  }

  public func close() {
    if let db {
      sqlite3_close(db)
      self.db = nil
    }
  }

  public func deleteEvents(before cutoff: Date) throws {
    try ensureOpen()
    let statement = try prepare("DELETE FROM usage_events WHERE timestamp < ?")
    defer { sqlite3_finalize(statement) }
    sqlite3_bind_double(statement, 1, cutoff.timeIntervalSince1970)
    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw DatabaseError.statementFailed(message: lastError)
    }
  }

  public func schemaVersion() throws -> Int {
    try ensureOpen()
    let statement = try prepare("PRAGMA user_version")
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
    return Int(sqlite3_column_int(statement, 0))
  }

  private func migrate() throws {
    try execute(
      """
      CREATE TABLE IF NOT EXISTS usage_events (
          id TEXT PRIMARY KEY,
          collector TEXT NOT NULL,
          tool TEXT NOT NULL,
          provider TEXT NOT NULL,
          model TEXT,
          timestamp REAL NOT NULL,
          input_tokens INTEGER,
          output_tokens INTEGER,
          cached_input_tokens INTEGER,
          cache_creation_tokens INTEGER,
          reasoning_tokens INTEGER,
          other_tokens INTEGER,
          total_tokens INTEGER,
          session_hash TEXT,
          project_hash TEXT,
          source_kind TEXT NOT NULL,
          source_fingerprint TEXT NOT NULL,
          accuracy TEXT NOT NULL,
          parser_version TEXT NOT NULL,
          imported_at REAL NOT NULL
      )
      """)
    try execute(
      """
      CREATE TABLE IF NOT EXISTS collection_cursors (
          source_fingerprint TEXT PRIMARY KEY,
          offset INTEGER NOT NULL,
          updated_at REAL NOT NULL
      )
      """)
    try execute("CREATE INDEX IF NOT EXISTS idx_usage_timestamp ON usage_events(timestamp)")
    try execute("CREATE INDEX IF NOT EXISTS idx_usage_collector ON usage_events(collector)")
    try execute("CREATE INDEX IF NOT EXISTS idx_usage_tool ON usage_events(tool)")
    try execute("CREATE INDEX IF NOT EXISTS idx_usage_model ON usage_events(model)")
    try execute("CREATE INDEX IF NOT EXISTS idx_usage_source ON usage_events(source_fingerprint)")
    try execute("PRAGMA user_version = 1")
  }

  private func insert(_ event: UsageEvent) throws -> Bool {
    let sql = """
      INSERT OR IGNORE INTO usage_events (
          id, collector, tool, provider, model, timestamp, input_tokens, output_tokens,
          cached_input_tokens, cache_creation_tokens, reasoning_tokens, other_tokens,
          total_tokens, session_hash, project_hash, source_kind, source_fingerprint,
          accuracy, parser_version, imported_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      """
    let statement = try prepare(sql)
    defer { sqlite3_finalize(statement) }
    bindText(statement, 1, event.id)
    bindText(statement, 2, event.collector.rawValue)
    bindText(statement, 3, event.tool.rawValue)
    bindText(statement, 4, event.provider.rawValue)
    bindText(statement, 5, event.model)
    sqlite3_bind_double(statement, 6, event.timestamp.timeIntervalSince1970)
    bindInt(statement, 7, event.tokens.inputTokens)
    bindInt(statement, 8, event.tokens.outputTokens)
    bindInt(statement, 9, event.tokens.cachedInputTokens)
    bindInt(statement, 10, event.tokens.cacheCreationTokens)
    bindInt(statement, 11, event.tokens.reasoningTokens)
    bindInt(statement, 12, event.tokens.otherTokens)
    bindInt(statement, 13, event.tokens.totalTokens)
    bindText(statement, 14, event.sessionIdentifierHash)
    bindText(statement, 15, event.projectIdentifierHash)
    bindText(statement, 16, event.sourceKind.rawValue)
    bindText(statement, 17, event.sourceFingerprint)
    bindText(statement, 18, event.accuracy.rawValue)
    bindText(statement, 19, event.parserVersion)
    sqlite3_bind_double(statement, 20, event.importedAt.timeIntervalSince1970)

    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw DatabaseError.statementFailed(message: lastError)
    }
    return sqlite3_changes(db) > 0
  }

  private func upsert(_ cursor: CollectionCursor) throws {
    let statement = try prepare(
      """
      INSERT INTO collection_cursors (source_fingerprint, offset, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT(source_fingerprint) DO UPDATE SET offset = excluded.offset, updated_at = excluded.updated_at
      """)
    defer { sqlite3_finalize(statement) }
    bindText(statement, 1, cursor.sourceFingerprint)
    sqlite3_bind_int64(statement, 2, sqlite3_int64(cursor.offset))
    sqlite3_bind_double(statement, 3, cursor.updatedAt.timeIntervalSince1970)
    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw DatabaseError.statementFailed(message: lastError)
    }
  }

  private func execute(_ sql: String) throws {
    guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
      throw DatabaseError.statementFailed(message: lastError)
    }
  }

  private func prepare(_ sql: String) throws -> OpaquePointer? {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      throw DatabaseError.statementFailed(message: lastError)
    }
    return statement
  }

  private func rowEvent(_ statement: OpaquePointer?) throws -> UsageEvent {
    guard
      let collector = CollectorIdentifier(rawValue: columnString(statement, 1) ?? ""),
      let tool = ToolIdentifier(rawValue: columnString(statement, 2) ?? ""),
      let provider = ProviderIdentifier(rawValue: columnString(statement, 3) ?? ""),
      let sourceKind = SourceKind(rawValue: columnString(statement, 15) ?? ""),
      let accuracy = UsageAccuracy(rawValue: columnString(statement, 17) ?? "")
    else {
      throw DatabaseError.statementFailed(message: "Stored event has invalid enum value.")
    }
    return UsageEvent(
      id: columnString(statement, 0) ?? "",
      collector: collector,
      tool: tool,
      provider: provider,
      model: columnString(statement, 4),
      timestamp: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5)),
      tokens: TokenBreakdown(
        inputTokens: columnInt(statement, 6),
        outputTokens: columnInt(statement, 7),
        cachedInputTokens: columnInt(statement, 8),
        cacheCreationTokens: columnInt(statement, 9),
        reasoningTokens: columnInt(statement, 10),
        otherTokens: columnInt(statement, 11),
        totalTokens: columnInt(statement, 12)
      ),
      sessionIdentifierHash: columnString(statement, 13),
      projectIdentifierHash: columnString(statement, 14),
      sourceKind: sourceKind,
      sourceFingerprint: columnString(statement, 16) ?? "",
      accuracy: accuracy,
      parserVersion: columnString(statement, 18) ?? "",
      importedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 19))
    )
  }

  private func ensureOpen() throws {
    if db == nil { try open() }
  }

  private var lastError: String {
    guard let db, let pointer = sqlite3_errmsg(db) else { return "Unknown SQLite error." }
    return String(cString: pointer)
  }

  private func bindText(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
    guard let value else {
      sqlite3_bind_null(statement, index)
      return
    }
    sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
  }

  private func bindInt(_ statement: OpaquePointer?, _ index: Int32, _ value: Int?) {
    guard let value else {
      sqlite3_bind_null(statement, index)
      return
    }
    sqlite3_bind_int64(statement, index, sqlite3_int64(value))
  }

  private func columnString(_ statement: OpaquePointer?, _ index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
      let pointer = sqlite3_column_text(statement, index)
    else { return nil }
    return String(cString: pointer)
  }

  private func columnInt(_ statement: OpaquePointer?, _ index: Int32) -> Int? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
    return Int(sqlite3_column_int64(statement, index))
  }
}

public enum DatabaseError: Error, LocalizedError {
  case openFailed(message: String)
  case statementFailed(message: String)

  public var errorDescription: String? {
    switch self {
    case .openFailed(let message): "Could not open local database: \(message)"
    case .statementFailed(let message): "Local database operation failed: \(message)"
    }
  }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

import Foundation
import Network

/// A minimal, loopback-only OTLP/HTTP JSON receiver for Claude Code metrics.
///
/// Claude Code has no built-in file exporter (see
/// https://code.claude.com/docs/en/monitoring-usage) — the documented way to get
/// local token usage is to point its `otlp` exporter at an HTTP endpoint. This
/// actor runs that endpoint on `127.0.0.1` only, accepts `POST /v1/metrics`
/// bodies, and appends each one as a JSONL line that `ClaudeCodeCollector`
/// scans with `ClaudeTelemetryParser`. It never binds to a non-loopback
/// interface and performs no outbound network activity.
public actor ClaudeTelemetryReceiver {
  public enum ReceiverError: Error, Equatable {
    case alreadyRunning
    case bindFailed(String)
  }

  public static let defaultPort: UInt16 = 4319

  private let requestedPort: UInt16
  private let destinationDirectory: URL
  private var listener: NWListener?

  public init(
    port: UInt16 = ClaudeTelemetryReceiver.defaultPort,
    destinationDirectory: URL = ClaudeCodeCollector.defaultSourceDirectories[0]
  ) {
    self.requestedPort = port
    self.destinationDirectory = destinationDirectory
  }

  public var isRunning: Bool { listener != nil }

  @discardableResult
  public func start() throws -> UInt16 {
    guard listener == nil else { throw ReceiverError.alreadyRunning }
    guard let port = NWEndpoint.Port(rawValue: requestedPort) else {
      throw ReceiverError.bindFailed("Invalid port \(requestedPort)")
    }
    try FileManager.default.createDirectory(
      at: destinationDirectory, withIntermediateDirectories: true)

    let parameters = NWParameters.tcp
    parameters.allowLocalEndpointReuse = true
    parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: port)

    let newListener: NWListener
    do {
      newListener = try NWListener(using: parameters)
    } catch {
      throw ReceiverError.bindFailed(String(describing: error))
    }

    newListener.newConnectionHandler = { [weak self] connection in
      guard let self else { return }
      Task { await self.accept(connection) }
    }
    newListener.start(queue: .main)
    listener = newListener
    return requestedPort
  }

  public func stop() {
    listener?.cancel()
    listener = nil
  }

  private func accept(_ connection: NWConnection) {
    connection.start(queue: .main)
    receive(on: connection, buffer: Data())
  }

  private func receive(on connection: NWConnection, buffer: Data) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) {
      [weak self] data, _, isComplete, error in
      guard let self else { return }
      var next = buffer
      if let data { next.append(data) }
      Task {
        await self.handleReceivedData(next, on: connection, isComplete: isComplete, error: error)
      }
    }
  }

  private func handleReceivedData(
    _ buffer: Data, on connection: NWConnection, isComplete: Bool, error: NWError?
  ) {
    if let request = HTTPRequestParser.parse(buffer) {
      handle(request: request, on: connection)
      return
    }
    guard error == nil, !isComplete else {
      connection.cancel()
      return
    }
    receive(on: connection, buffer: buffer)
  }

  private func handle(request: HTTPRequestParser.Request, on connection: NWConnection) {
    guard request.method == "POST", request.path.hasPrefix("/v1/metrics") else {
      respond(status: "404 Not Found", body: Data(), on: connection)
      return
    }
    persist(body: request.body)
    respond(status: "200 OK", body: Data("{}".utf8), on: connection)
  }

  private func persist(body: Data) {
    guard !body.isEmpty,
      let text = String(data: body, encoding: .utf8),
      (try? JSONSerialization.jsonObject(with: body)) != nil
    else { return }

    let singleLine = text.replacingOccurrences(of: "\n", with: " ")
    guard let lineData = (singleLine + "\n").data(using: .utf8) else { return }

    let fileURL = destinationDirectory.appendingPathComponent(Self.fileName(for: Date()))
    if let handle = try? FileHandle(forWritingTo: fileURL) {
      defer { try? handle.close() }
      do {
        try handle.seekToEnd()
        try handle.write(contentsOf: lineData)
      } catch {}
    } else {
      try? lineData.write(to: fileURL, options: .atomic)
    }
  }

  private func respond(status: String, body: Data, on connection: NWConnection) {
    var response = "HTTP/1.1 \(status)\r\n"
    response += "Content-Type: application/json\r\n"
    response += "Content-Length: \(body.count)\r\n"
    response += "Connection: close\r\n\r\n"
    var responseData = Data(response.utf8)
    responseData.append(body)
    connection.send(
      content: responseData,
      completion: .contentProcessed { _ in
        connection.cancel()
      })
  }

  private static func fileName(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    return "claude-otel-\(formatter.string(from: date)).jsonl"
  }
}

/// Bare-bones HTTP/1.1 request-line + headers + fixed-length body parser.
/// Only what's needed to accept OTLP/HTTP JSON export POSTs from a local process.
enum HTTPRequestParser {
  struct Request {
    let method: String
    let path: String
    let body: Data
  }

  static func parse(_ buffer: Data) -> Request? {
    guard let headerEndRange = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
    let headerData = buffer[buffer.startIndex..<headerEndRange.lowerBound]
    guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }

    let lines = headerText.components(separatedBy: "\r\n")
    guard let requestLine = lines.first else { return nil }
    let requestParts = requestLine.split(separator: " ")
    guard requestParts.count >= 2 else { return nil }
    let method = String(requestParts[0])
    let path = String(requestParts[1])

    var contentLength = 0
    for line in lines.dropFirst() {
      guard let colonIndex = line.firstIndex(of: ":") else { continue }
      let key = line[line.startIndex..<colonIndex].trimmingCharacters(in: .whitespaces)
      let value = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
      if key.caseInsensitiveCompare("Content-Length") == .orderedSame {
        contentLength = Int(value) ?? 0
      }
    }

    let bodyStart = headerEndRange.upperBound
    let availableBody = buffer.distance(from: bodyStart, to: buffer.endIndex)
    guard availableBody >= contentLength else { return nil }
    let bodyEnd = buffer.index(bodyStart, offsetBy: contentLength)
    let body = buffer[bodyStart..<bodyEnd]
    return Request(method: method, path: path, body: Data(body))
  }
}

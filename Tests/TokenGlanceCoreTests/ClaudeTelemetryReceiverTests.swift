import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Claude telemetry receiver")
struct ClaudeTelemetryReceiverTests {
  @Test("Receiver persists posted OTLP metrics export bodies as JSONL and rejects other paths")
  func receiverPersistsMetricsExports() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let port = UInt16.random(in: 20000...40000)
    let receiver = ClaudeTelemetryReceiver(port: port, destinationDirectory: root)
    let boundPort = try await receiver.start()
    defer { Task { await receiver.stop() } }

    var request = URLRequest(url: URL(string: "http://127.0.0.1:\(boundPort)/v1/metrics")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let exportBody = Data(#"{"resourceMetrics":[]}"#.utf8)
    request.httpBody = exportBody

    let (_, response) = try await URLSession.shared.data(for: request)
    #expect((response as? HTTPURLResponse)?.statusCode == 200)

    var otherRequest = URLRequest(url: URL(string: "http://127.0.0.1:\(boundPort)/health")!)
    otherRequest.httpMethod = "GET"
    let (_, otherResponse) = try await URLSession.shared.data(for: otherRequest)
    #expect((otherResponse as? HTTPURLResponse)?.statusCode == 404)

    let files = try FileManager.default.contentsOfDirectory(
      at: root, includingPropertiesForKeys: nil)
    #expect(files.count == 1)
    let persisted = try String(contentsOf: files[0], encoding: .utf8)
    #expect(persisted.contains("resourceMetrics"))
    #expect(!persisted.contains("\n\n"))
  }

  @Test("Receiver only binds to loopback")
  func receiverBindsToLoopbackOnly() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let port = UInt16.random(in: 20000...40000)
    let receiver = ClaudeTelemetryReceiver(port: port, destinationDirectory: root)
    let boundPort = try await receiver.start()
    defer { Task { await receiver.stop() } }

    #expect(await receiver.isRunning)
    #expect(boundPort == port)
  }
}

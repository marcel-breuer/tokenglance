import Foundation

public struct CommandLineToolDetector: Sendable {
  public init() {}

  public func locate(_ executable: String) -> String? {
    let paths =
      (ProcessInfo.processInfo.environment["PATH"]
      ?? "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin")
      .split(separator: ":")
      .map(String.init)

    for path in paths {
      let candidate = URL(fileURLWithPath: path).appendingPathComponent(executable).path
      if FileManager.default.isExecutableFile(atPath: candidate) {
        return candidate
      }
    }
    return nil
  }

  public func version(executablePath: String, arguments: [String] = ["--version"]) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
      process.waitUntilExit()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      return String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: "\n")
        .first
        .map(String.init)
    } catch {
      return nil
    }
  }
}

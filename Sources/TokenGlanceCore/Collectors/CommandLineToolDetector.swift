import Foundation

public struct CommandLineToolDetector: Sendable {
  private let pathOverride: String?

  public init(pathOverride: String? = nil) {
    self.pathOverride = pathOverride
  }

  public func locate(_ executable: String) -> String? {
    let environmentPaths =
      (pathOverride ?? ProcessInfo.processInfo.environment["PATH"] ?? "")
      .split(separator: ":")
      .map(String.init)
    let fallbackPaths = [
      "/opt/homebrew/bin",
      "/opt/homebrew/sbin",
      "/usr/local/bin",
      "/usr/local/sbin",
      "/usr/bin",
      "/bin",
      "/usr/sbin",
      "/sbin",
    ]
    let paths = Array(
      OrderedSet(environmentPaths + fallbackPaths)
    )

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

private struct OrderedSet<Element: Hashable>: Sequence {
  private let values: [Element]

  init(_ input: [Element]) {
    var seen = Set<Element>()
    values = input.filter { seen.insert($0).inserted }
  }

  func makeIterator() -> Array<Element>.Iterator {
    values.makeIterator()
  }
}

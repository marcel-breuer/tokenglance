import Foundation

public struct UsageSparklineSeries: Equatable, Sendable {
  public let values: [Int]

  public init(summary: UsageSummary?, maxPoints: Int = 18) {
    let buckets = Array((summary?.buckets ?? []).suffix(max(maxPoints, 0)))
    self.values = buckets.map { max($0.tokens.calculatedTotal, 0) }
  }

  public var isRenderable: Bool {
    values.contains { $0 > 0 }
  }

  public var normalizedValues: [Double] {
    guard let maximum = values.max(), maximum > 0 else {
      return values.map { _ in 0 }
    }
    return values.map { Double($0) / Double(maximum) }
  }
}

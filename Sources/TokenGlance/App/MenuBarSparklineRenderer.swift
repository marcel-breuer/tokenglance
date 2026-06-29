import AppKit
import TokenGlanceCore

enum MenuBarSparklineRenderer {
  static func image(summary: UsageSummary?) -> NSImage {
    sparklineImage(
      summary: summary,
      size: NSSize(width: 36, height: 18),
      color: .black,
      isTemplate: true)
  }

  static func usageStripImage(summary: UsageSummary?, pulse: UsagePulse) -> NSImage {
    sparklineImage(
      summary: summary,
      size: NSSize(width: 42, height: 18),
      color: color(for: pulse),
      isTemplate: false)
  }

  private static func sparklineImage(
    summary: UsageSummary?,
    size: NSSize,
    color: NSColor,
    isTemplate: Bool
  ) -> NSImage {
    let series = UsageSparklineSeries(summary: summary)
    let image = NSImage(size: size)

    image.lockFocus()
    defer {
      image.unlockFocus()
      image.isTemplate = isTemplate
    }

    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()

    drawBaseline(size: size)

    let path = NSBezierPath()
    path.lineWidth = 2
    path.lineJoinStyle = .round
    path.lineCapStyle = .round
    color.setStroke()

    guard series.isRenderable, series.normalizedValues.count > 1 else {
      path.move(to: NSPoint(x: 3, y: size.height * 0.45))
      path.line(to: NSPoint(x: size.width - 3, y: size.height * 0.45))
      path.stroke()
      return image
    }

    let values = series.normalizedValues
    let inset: CGFloat = 3
    let drawableWidth = size.width - (inset * 2)
    let drawableHeight = size.height - (inset * 2)
    let step = drawableWidth / CGFloat(values.count - 1)

    for (index, value) in values.enumerated() {
      let x = inset + (CGFloat(index) * step)
      let y = inset + (CGFloat(value) * drawableHeight)
      let point = NSPoint(x: x, y: y)
      if index == 0 {
        path.move(to: point)
      } else {
        path.line(to: point)
      }
    }

    path.stroke()
    drawLastPoint(values: values, size: size, color: color)
    return image
  }

  private static func drawBaseline(size: NSSize) {
    let baseline = NSBezierPath()
    baseline.lineWidth = 1
    baseline.move(to: NSPoint(x: 3, y: size.height * 0.25))
    baseline.line(to: NSPoint(x: size.width - 3, y: size.height * 0.25))
    NSColor.quaternaryLabelColor.setStroke()
    baseline.stroke()
  }

  private static func drawLastPoint(values: [Double], size: NSSize, color: NSColor) {
    guard values.count > 1 else { return }
    let inset: CGFloat = 3
    let drawableWidth = size.width - (inset * 2)
    let drawableHeight = size.height - (inset * 2)
    let x = inset + drawableWidth
    let y = inset + (CGFloat(values.last ?? 0) * drawableHeight)
    let rect = NSRect(x: x - 2, y: y - 2, width: 4, height: 4)
    color.setFill()
    NSBezierPath(ovalIn: rect).fill()
  }

  private static func color(for pulse: UsagePulse) -> NSColor {
    switch pulse.weather {
    case .calm:
      .systemGreen
    case .active:
      .systemOrange
    case .stormy:
      .systemRed
    }
  }
}

import AppKit
import TokenGlanceCore

enum MenuBarSparklineRenderer {
  static func image(summary: UsageSummary?) -> NSImage {
    let series = UsageSparklineSeries(summary: summary)
    let size = NSSize(width: 36, height: 18)
    let image = NSImage(size: size)

    image.lockFocus()
    defer {
      image.unlockFocus()
      image.isTemplate = true
    }

    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()

    let path = NSBezierPath()
    path.lineWidth = 2
    path.lineJoinStyle = .round
    path.lineCapStyle = .round
    NSColor.black.setStroke()

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
    return image
  }
}

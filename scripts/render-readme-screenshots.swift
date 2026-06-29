#!/usr/bin/env swift
import AppKit
import Foundation

struct Theme {
  let background: NSColor
  let window: NSColor
  let panel: NSColor
  let text: NSColor
  let secondary: NSColor
  let accent: NSColor
  let green: NSColor
  let orange: NSColor
  let purple: NSColor
  let red: NSColor
}

let light = Theme(
  background: NSColor(calibratedRed: 0.93, green: 0.95, blue: 0.96, alpha: 1),
  window: NSColor(calibratedRed: 0.985, green: 0.99, blue: 0.995, alpha: 1),
  panel: NSColor.white,
  text: NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1),
  secondary: NSColor(calibratedRed: 0.43, green: 0.47, blue: 0.52, alpha: 1),
  accent: NSColor(calibratedRed: 0.12, green: 0.40, blue: 0.95, alpha: 1),
  green: NSColor(calibratedRed: 0.05, green: 0.55, blue: 0.26, alpha: 1),
  orange: NSColor(calibratedRed: 0.86, green: 0.45, blue: 0.08, alpha: 1),
  purple: NSColor(calibratedRed: 0.48, green: 0.25, blue: 0.92, alpha: 1),
  red: NSColor(calibratedRed: 0.82, green: 0.16, blue: 0.20, alpha: 1)
)

let dark = Theme(
  background: NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.09, alpha: 1),
  window: NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.15, alpha: 1),
  panel: NSColor(calibratedRed: 0.17, green: 0.18, blue: 0.20, alpha: 1),
  text: NSColor(calibratedRed: 0.93, green: 0.95, blue: 0.97, alpha: 1),
  secondary: NSColor(calibratedRed: 0.62, green: 0.66, blue: 0.70, alpha: 1),
  accent: NSColor(calibratedRed: 0.36, green: 0.62, blue: 1.00, alpha: 1),
  green: NSColor(calibratedRed: 0.25, green: 0.78, blue: 0.46, alpha: 1),
  orange: NSColor(calibratedRed: 1.00, green: 0.65, blue: 0.22, alpha: 1),
  purple: NSColor(calibratedRed: 0.66, green: 0.48, blue: 1.00, alpha: 1),
  red: NSColor(calibratedRed: 1.00, green: 0.36, blue: 0.38, alpha: 1)
)

func drawText(
  _ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor
) {
  let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: size, weight: weight),
    .foregroundColor: color,
  ]
  text.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
}

func roundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
  color.setFill()
  NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func strokeRoundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
  color.setStroke()
  let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
  path.lineWidth = 1
  path.stroke()
}

func dot(x: CGFloat, y: CGFloat, color: NSColor) {
  color.setFill()
  NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 7, height: 7)).fill()
}

func bar(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: NSColor) {
  roundedRect(NSRect(x: x, y: y, width: width, height: height), radius: 3, color: color)
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
  guard let png = bitmap.representation(using: .png, properties: [:])
  else { throw CocoaError(.fileWriteUnknown) }
  try png.write(to: url)
}

func render(theme: Theme, url: URL) throws {
  let size = NSSize(width: 920, height: 760)
  guard
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: Int(size.width),
      pixelsHigh: Int(size.height),
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0),
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
  else { throw CocoaError(.fileWriteUnknown) }
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  defer { NSGraphicsContext.restoreGraphicsState() }

  theme.background.setFill()
  NSRect(origin: .zero, size: size).fill()
  roundedRect(NSRect(x: 80, y: 50, width: 760, height: 660), radius: 18, color: theme.window)
  strokeRoundedRect(
    NSRect(x: 80, y: 50, width: 760, height: 660), radius: 18,
    color: theme.secondary.withAlphaComponent(0.22))

  drawText("TokenGlance", x: 120, y: 665, size: 24, weight: .semibold, color: theme.text)
  dot(x: 121, y: 642, color: theme.green)
  drawText(
    "Live refresh running", x: 136, y: 636, size: 12, weight: .regular, color: theme.secondary)
  roundedRect(NSRect(x: 630, y: 640, width: 148, height: 32), radius: 8, color: theme.panel)
  drawText("Overview", x: 670, y: 648, size: 13, weight: .medium, color: theme.text)

  roundedRect(NSRect(x: 120, y: 492, width: 285, height: 124), radius: 8, color: theme.panel)
  drawText("2.4M", x: 150, y: 560, size: 34, weight: .semibold, color: theme.text)
  drawText("tokens today", x: 152, y: 536, size: 13, weight: .regular, color: theme.secondary)
  dot(x: 287, y: 576, color: theme.accent)
  drawText("Input 1.4M", x: 302, y: 568, size: 13, weight: .medium, color: theme.text)
  dot(x: 287, y: 548, color: theme.green)
  drawText("Output 820K", x: 302, y: 540, size: 13, weight: .medium, color: theme.text)
  dot(x: 287, y: 520, color: theme.purple)
  drawText("Cache 184K", x: 302, y: 512, size: 13, weight: .medium, color: theme.text)

  roundedRect(NSRect(x: 425, y: 492, width: 355, height: 124), radius: 8, color: theme.panel)
  drawText("Token Weather", x: 450, y: 578, size: 13, weight: .regular, color: theme.secondary)
  drawText("active", x: 450, y: 548, size: 25, weight: .semibold, color: theme.orange)
  drawText("Burn Rate", x: 585, y: 578, size: 13, weight: .regular, color: theme.secondary)
  drawText("180K tokens/h", x: 585, y: 548, size: 20, weight: .semibold, color: theme.text)
  drawText("Projection", x: 585, y: 520, size: 12, weight: .regular, color: theme.secondary)
  drawText("3.2M today", x: 660, y: 520, size: 12, weight: .semibold, color: theme.text)

  roundedRect(NSRect(x: 120, y: 318, width: 660, height: 148), radius: 8, color: theme.panel)
  drawText("Usage", x: 145, y: 430, size: 16, weight: .semibold, color: theme.text)
  for i in 0..<18 {
    let h = CGFloat([24, 36, 30, 52, 42, 78, 64, 48, 88, 104, 70, 54, 95, 116, 86, 62, 44, 68][i])
    bar(
      x: 150 + CGFloat(i) * 33, y: 342, width: 18, height: h,
      color: theme.accent.withAlphaComponent(0.82))
  }

  roundedRect(NSRect(x: 120, y: 190, width: 660, height: 104), radius: 8, color: theme.panel)
  drawText("Model Efficiency", x: 145, y: 262, size: 16, weight: .semibold, color: theme.text)
  drawText("gpt-5", x: 145, y: 232, size: 13, weight: .semibold, color: theme.text)
  drawText(
    "42 events · avg 58K · cache 18.4% · $1.482", x: 232, y: 232, size: 12, weight: .regular,
    color: theme.secondary)
  drawText("claude", x: 145, y: 207, size: 13, weight: .semibold, color: theme.text)
  drawText(
    "17 events · avg 31K · cache 6.2% · n/a", x: 232, y: 207, size: 12, weight: .regular,
    color: theme.secondary)

  roundedRect(NSRect(x: 120, y: 84, width: 315, height: 82), radius: 8, color: theme.panel)
  drawText("Schema Drift Radar", x: 145, y: 132, size: 15, weight: .semibold, color: theme.text)
  dot(x: 147, y: 111, color: theme.green)
  drawText(
    "All active collectors parse known metadata", x: 162, y: 103, size: 12, weight: .regular,
    color: theme.secondary)

  roundedRect(NSRect(x: 465, y: 84, width: 315, height: 82), radius: 8, color: theme.panel)
  drawText("Weekly Report Archive", x: 490, y: 132, size: 15, weight: .semibold, color: theme.text)
  drawText(
    "~/Library/Application Support/TokenGlance/Reports", x: 490, y: 104, size: 11, weight: .regular,
    color: theme.secondary)

  try writePNG(bitmap, to: url)
}

let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  .appendingPathComponent("docs/assets", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
try render(theme: light, url: output.appendingPathComponent("token-glance-light.png"))
try render(theme: dark, url: output.appendingPathComponent("token-glance-dark.png"))

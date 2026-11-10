import AppKit
import SwiftUI

/// Shared glass design: every raised surface in the app takes its fill, blur, specular edge, rim,
/// radius and shadow from this file. Brand colour is the TokenGlance blue (the accent used in the
/// README screenshots); neutrals stay system-tinted.
enum GlassTokens {
  // Radius scale: 20 panels/menus/cards, 16 nested insets, 24 dialogs/sheets, 10 small controls.
  static let panelRadius: CGFloat = 20
  static let insetRadius: CGFloat = 16
  static let dialogRadius: CGFloat = 24
  static let controlRadius: CGFloat = 10
  static let minimumInnerRadius: CGFloat = 4

  /// Inner radius = outer radius minus padding, never below 4.
  static func innerRadius(outer: CGFloat, padding: CGFloat) -> CGFloat {
    max(outer - padding, minimumInnerRadius)
  }

  // Brand blue, taken from the project accent (scripts/render-readme-screenshots.swift).
  static let brand = Color(red: 0.12, green: 0.40, blue: 0.95)
  static let brandLight = Color(red: 0.36, green: 0.62, blue: 1.0)

  static func fillOpacity(_ level: GlassLevel, dark: Bool) -> Double {
    switch (level, dark) {
    case (.inset, false): 0.38
    case (.inset, true): 0.05
    case (_, false): 0.52
    case (_, true): 0.07
    }
  }

  static func fill(_ level: GlassLevel, dark: Bool) -> Color {
    (dark ? Color.white : Color(nsColor: .windowBackgroundColor))
      .opacity(fillOpacity(level, dark: dark))
  }

  static func specular(dark: Bool) -> Color { .white.opacity(dark ? 0.22 : 0.9) }
  static func rim(dark: Bool) -> Color { .white.opacity(dark ? 0.08 : 0.5) }
  static func shadow(dark: Bool) -> Color {
    dark ? .black.opacity(0.35) : brand.opacity(0.10)
  }
  /// Solid fallbacks for reduced transparency and increased contrast.
  static func solid(_ level: GlassLevel) -> Color {
    Color(nsColor: level == .inset ? .controlBackgroundColor : .windowBackgroundColor)
  }
}

enum GlassLevel {
  /// Navigation and toolbars.
  case chrome
  /// Cards and panels.
  case panel
  /// Nested surface inside a panel. No blur, no shadow.
  case inset
  /// Dialogs and sheets.
  case dialog

  var radius: CGFloat {
    switch self {
    case .chrome, .panel: GlassTokens.panelRadius
    case .inset: GlassTokens.insetRadius
    case .dialog: GlassTokens.dialogRadius
    }
  }
}

struct GlassSurface: ViewModifier {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.colorScheme) private var colorScheme
  var level: GlassLevel = .panel
  var radius: CGFloat?

  private var solid: Bool { reduceTransparency || contrast == .increased }

  func body(content: Content) -> some View {
    let dark = colorScheme == .dark
    let shape = RoundedRectangle(cornerRadius: radius ?? level.radius, style: .continuous)
    content
      .background { surface(shape, dark: dark) }
      .overlay {
        if solid {
          shape.strokeBorder(Color.primary.opacity(contrast == .increased ? 0.5 : 0.14), lineWidth: 1)
        } else {
          shape.strokeBorder(GlassTokens.rim(dark: dark), lineWidth: 1)
            .overlay { shape.inset(by: 1).strokeBorder(GlassTokens.rim(dark: dark), lineWidth: 1) }
        }
      }
      .overlay(alignment: .top) {
        if !solid {
          shape
            .strokeBorder(GlassTokens.specular(dark: dark), lineWidth: 1)
            .mask(alignment: .top) {
              LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 18)
            }
            .accessibilityHidden(true)
        }
      }
      .shadow(
        color: solid || level == .inset ? .clear : GlassTokens.shadow(dark: dark),
        radius: 16, x: 0, y: 8)
  }

  @ViewBuilder
  private func surface(_ shape: RoundedRectangle, dark: Bool) -> some View {
    if solid {
      shape.fill(GlassTokens.solid(level))
    } else if level == .inset {
      shape.fill(GlassTokens.fill(level, dark: dark))
    } else if #available(macOS 26.0, *) {
      Color.clear.glassEffect(.regular, in: shape)
    } else {
      shape.fill(.ultraThinMaterial)
        .overlay { shape.fill(GlassTokens.fill(level, dark: dark)) }
    }
  }
}

/// Toolbar glass: one chrome level with a hairline rim on its lower edge, no shadow.
struct GlassChrome: ViewModifier {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    let dark = colorScheme == .dark
    let solid = reduceTransparency || contrast == .increased
    content
      .background {
        if solid {
          Rectangle().fill(GlassTokens.solid(.chrome))
        } else {
          Rectangle().fill(.ultraThinMaterial)
            .overlay { Rectangle().fill(GlassTokens.fill(.chrome, dark: dark)) }
        }
      }
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(solid ? Color.primary.opacity(0.3) : GlassTokens.rim(dark: dark))
          .frame(height: 1)
          .accessibilityHidden(true)
      }
  }
}

/// Soft brand colour field behind content: what the glass blurs. Fixed, no animation.
struct GlassBackdrop: View {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let dark = colorScheme == .dark
    ZStack {
      if reduceTransparency || contrast == .increased {
        Color(nsColor: .windowBackgroundColor)
      } else {
        VisualEffectBackground()
        GeometryReader { proxy in
          let size = max(proxy.size.width, proxy.size.height)
          blob(dark ? Color(red: 0.08, green: 0.22, blue: 0.62) : GlassTokens.brandLight,
               opacity: dark ? 0.42 : 0.38, diameter: size * 0.9)
            .position(x: proxy.size.width * 0.12, y: proxy.size.height * 0.08)
          blob(dark ? Color(red: 0.05, green: 0.14, blue: 0.45) : Color(red: 0.55, green: 0.74, blue: 1.0),
               opacity: dark ? 0.46 : 0.45, diameter: size * 0.8)
            .position(x: proxy.size.width * 0.92, y: proxy.size.height * 0.32)
          blob(dark ? Color(red: 0.10, green: 0.30, blue: 0.80) : GlassTokens.brand,
               opacity: dark ? 0.26 : 0.26, diameter: size * 0.85)
            .position(x: proxy.size.width * 0.3, y: proxy.size.height * 0.92)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      }
    }
    .ignoresSafeArea()
  }

  private func blob(_ color: Color, opacity: Double, diameter: CGFloat) -> some View {
    RadialGradient(
      colors: [color.opacity(opacity), color.opacity(0)],
      center: .center, startRadius: 0, endRadius: diameter / 2
    )
    .frame(width: diameter, height: diameter)
  }
}

private struct VisualEffectBackground: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .underWindowBackground
    view.blendingMode = .behindWindow
    view.state = .active
    return view
  }

  func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

extension View {
  func glassSurface(_ level: GlassLevel = .panel) -> some View {
    modifier(GlassSurface(level: level))
  }

  /// Escape hatch for a non-standard radius; keep to the radius scale in `GlassTokens`.
  func glassSurface(_ level: GlassLevel = .panel, radius: CGFloat) -> some View {
    modifier(GlassSurface(level: level, radius: radius))
  }

  func glassChrome() -> some View { modifier(GlassChrome()) }

  func glassBackdrop() -> some View { background { GlassBackdrop() } }
}

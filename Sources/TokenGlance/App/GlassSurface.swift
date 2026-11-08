import AppKit
import SwiftUI

struct GlassSurface: ViewModifier {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  var cornerRadius: CGFloat = 14

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    content
      .background {
        shape.fill(
          reduceTransparency
            ? AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
            : AnyShapeStyle(.regularMaterial)
        )
      }
      .overlay {
        shape.strokeBorder(Color.primary.opacity(reduceTransparency ? 0.12 : 0.09), lineWidth: 1)
      }
      .overlay(alignment: .top) {
        shape
          .strokeBorder(Color.white.opacity(reduceTransparency ? 0 : 0.16), lineWidth: 1)
          .mask(alignment: .top) {
            LinearGradient(
              colors: [.white, .clear],
              startPoint: .top,
              endPoint: .bottom
            )
            .frame(height: 18)
          }
          .accessibilityHidden(true)
      }
  }
}

extension View {
  func glassSurface(cornerRadius: CGFloat = 14) -> some View {
    modifier(GlassSurface(cornerRadius: cornerRadius))
  }
}

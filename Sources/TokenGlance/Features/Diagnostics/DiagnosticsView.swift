import SwiftUI

struct DiagnosticsView: View {
  let text: String

  var body: some View {
    ScrollView {
      Text(text)
        .font(.system(.caption, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .padding(12)
        .glassSurface(cornerRadius: 10)
    }
    .padding(16)
  }
}

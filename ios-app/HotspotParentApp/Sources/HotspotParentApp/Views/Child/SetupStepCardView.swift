import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct SetupStepCardView<Content: View>: View {
  let title: String
  let subtitle: String
  let statusText: String
  let statusColor: Color
  @ViewBuilder let content: Content

  public init(
    title: String,
    subtitle: String,
    statusText: String,
    statusColor: Color = .secondary,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.subtitle = subtitle
    self.statusText = statusText
    self.statusColor = statusColor
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
          Text(subtitle)
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        }
        Spacer()
        Text(statusText)
          .font(.system(size: 13, weight: .semibold))
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(statusColor.opacity(0.15))
          .foregroundStyle(statusColor)
          .clipShape(Capsule())
      }

      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

#Preview {
  SetupStepCardView(
    title: "Pair device",
    subtitle: "Connect this child phone to your backend device record.",
    statusText: "SETUP",
    statusColor: .orange
  ) {
    Button("Start pairing") {}
      .buttonStyle(.bordered)
  }
  .padding()
}
#endif

import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ChildLockedView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        headerCard
      }
      .padding(.top, 22)
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
  }

  private var headerCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Setup complete")
            .font(.largeTitle.bold())
          Text("This screen stays on. To change anything, the parent must unlock.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Text("Ready")
          .font(.caption.weight(.medium))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.green.opacity(0.18))
          .foregroundStyle(.green)
          .clipShape(RoundedRectangle(cornerRadius: 999))
      }

      Button {
        model.requestChildUnlock()
      } label: {
        Label("Unlock (parent)", systemImage: "arrow.right")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(18)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }
}

#Preview {
  ChildLockedView()
    .environmentObject(AppModel())
}
#endif

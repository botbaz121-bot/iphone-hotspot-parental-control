import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ChildPairView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Pair device")
          .font(.system(size: 34, weight: .bold))

        Text("Link this phone so the Shortcut can fetch policy and report activity.")
          .font(.footnote)
          .foregroundStyle(.secondary)

        Text("Enter pairing code")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
          .padding(.horizontal, 4)
          .padding(.top, 8)

        Text(model.loadHotspotConfig() != nil ? "Paired ✅" : "Not paired yet")
          .font(.footnote)
          .foregroundStyle(.secondary)

        NavigationLink {
          PairingEntryView()
            .environmentObject(model)
        } label: {
          Text("Enter pairing code")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)

        if model.loadHotspotConfig() != nil {
          Button(role: .destructive) {
            model.unpairChildDevice()
          } label: {
            Label("Unpair", systemImage: "link.badge.minus")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .tint(.red)
          .padding(.top, 2)
        }
      }
      .padding(.top, 18)
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
    .navigationTitle("Pair")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    ChildPairView()
      .environmentObject(AppModel())
  }
}
#endif

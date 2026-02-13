import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct LandingView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("SpotCheck")
          .font(.system(size: 34, weight: .bold))
          .padding(.top, 2)

        Text("Choose device type")
          .font(.footnote)
          .foregroundStyle(.secondary)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
          ShortcutTile(
            color: .blue,
            systemIcon: "person",
            title: "Parent phone",
            subtitle: nil
          ) {
            model.startParentFlow()
          }

          ShortcutTile(
            color: .pink,
            systemIcon: "iphone",
            title: "Set up child\nphone",
            subtitle: nil
          ) {
            model.startChildFlow()
          }
        }

        SettingsGroup("What this models") {
          SettingsRow(
            systemIcon: "bolt",
            title: "Shortcuts-only enforcement",
            subtitle: "Hotspot off + password rotation (via Shortcut)",
            showsChevron: false,
            action: nil
          )
          SettingsDivider()
          SettingsRow(
            systemIcon: "checklist",
            title: "Guided setup",
            subtitle: "A simple child-phone checklist",
            showsChevron: false,
            action: nil
          )
        }

        Button(role: .destructive) {
          model.resetLocalData()
        } label: {
          Label("Clear local state", systemImage: "trash")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .padding(.top, 8)
      }
      .padding(.top, 18)
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
  }
}

#Preview {
  LandingView()
    .environmentObject(AppModel())
}
#endif

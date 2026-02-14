import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ChildSettingsView: View {
  @EnvironmentObject private var model: AppModel
  @State private var showingResetConfirm = false

  public init() {}

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text("Settings")
            .font(.system(size: 34, weight: .bold))
            .padding(.top, 2)

          SettingsGroup("Mode") {
            SettingsToggleRow(
              systemIcon: "gearshape",
              title: "This is a child phone",
              subtitle: "Show the child setup experience on this device",
              isOn: Binding(
                get: { model.appMode == .childSetup },
                set: { isOn in
                  model.setAppMode(isOn ? .childSetup : .parent)
                }
              )
            )
          }

          SettingsGroup("Setup") {
            NavigationLink {
              PairingEntryView()
                .environmentObject(model)
            } label: {
              SettingsRow(
                systemIcon: "qrcode",
                title: model.loadHotspotConfig() != nil ? "Edit pairing" : "Pair device",
                subtitle: "Enter the pairing code from the parent phone",
                rightText: (model.loadHotspotConfig() != nil) ? "Paired" : "Not paired",
                showsChevron: true,
                action: nil
              )
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }

          Button(role: .destructive) {
            model.unlockChildSetup()
            model.restartOnboarding()
          } label: {
            Label("Reset child setup state", systemImage: "trash")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .tint(.red)

          
          SettingsGroup("Reset") {
            SettingsRow(
              systemIcon: "trash",
              title: "Reset local data",
              subtitle: "Clears app settings and pairing on this phone",
              rightText: nil,
              showsChevron: false,
              action: { showingResetConfirm = true }
            )
          }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 32)
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .confirmationDialog(
        "Reset local data?",
        isPresented: $showingResetConfirm,
        titleVisibility: .visible
      ) {
        Button("Reset", role: .destructive) {
          model.resetLocalData()
        }
        Button("Cancel", role: .cancel) {}
      }
    }
  }
}

#Preview {
  ChildSettingsView()
    .environmentObject(AppModel())
}
#endif

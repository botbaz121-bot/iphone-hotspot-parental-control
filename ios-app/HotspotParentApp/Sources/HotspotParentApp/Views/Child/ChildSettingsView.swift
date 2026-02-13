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
              ChildPairView()
                .environmentObject(model)
            } label: {
              SettingsRow(
                systemIcon: "qrcode",
                title: model.loadHotspotConfig() != nil ? "Edit pairing" : "Pair device",
                subtitle: "Scan a QR code or enter a pairing code",
                rightText: (model.loadHotspotConfig() != nil) ? "Paired" : "Not paired",
                showsChevron: true,
                action: nil
              )
              // Make the whole row tappable (since SettingsRow is a Button internally)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }

          SettingsGroup("Debug (prototype helpers)") {
            SettingsRow(
              systemIcon: "link",
              title: "Simulate Shortcut run",
              subtitle: "Increments run count (mock)",
              action: { model.recordIntentRun() }
            )
            SettingsDivider()
            SettingsRow(
              systemIcon: "shield",
              title: model.screenTimeAuthorized ? "Unset Screen Time auth" : "Set Screen Time auth",
              subtitle: "Toggle FamilyControls permission (mock)",
              action: { model.screenTimeAuthorized.toggle() }
            )
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

          #if DEBUG
          SettingsGroup("Debug") {
            VStack(alignment: .leading, spacing: 10) {
              TextField("Base URL", text: Binding(
                get: { model.apiBaseURL },
                set: { model.setAPIBaseURL($0) }
              ))
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .textFieldStyle(.roundedBorder)

              SecureField("Admin token (dev)", text: Binding(
                get: { model.adminToken },
                set: { model.setAdminToken($0) }
              ))
              .textFieldStyle(.roundedBorder)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
          }
          #endif

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

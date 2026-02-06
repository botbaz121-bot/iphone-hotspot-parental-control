import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct SettingsView: View {
  @EnvironmentObject private var model: AppModel
  @State private var showingResetConfirm = false

  public init() {}

  public var body: some View {
    NavigationStack {
      Form {
        Section("Account") {
          LabeledContent("Apple user") {
            Text(model.appleUserID ?? "—")
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(.secondary)
          }

          Button("Sign out") {
            model.signOut()
          }
          .foregroundStyle(.red)
        }

        Section("Backend (MVP)") {
          TextField("Base URL", text: Binding(
            get: { model.apiBaseURL },
            set: { model.setAPIBaseURL($0) }
          ))
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

          SecureField("Admin token (dev)", text: Binding(
            get: { model.adminToken },
            set: { model.setAdminToken($0) }
          ))

          Text("Admin token is only for dev/admin endpoints. Leave blank for normal use.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Section("Policy") {
          Toggle("Enforce Hotspot OFF", isOn: Binding(
            get: { model.hotspotOffPolicyEnabled },
            set: { model.setHotspotOffPolicyEnabled($0) }
          ))

          Text("When enabled, the child device should keep Personal Hotspot turned OFF.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Section("Debug") {
          Button("Reset local data") {
            showingResetConfirm = true
          }
          .foregroundStyle(.red)
        }
      }
      .navigationTitle("Settings")
      .confirmationDialog(
        "Reset local data?",
        isPresented: $showingResetConfirm,
        titleVisibility: .visible
      ) {
        Button("Reset", role: .destructive) {
          AppDefaults.resetAll()
          // Re-init state by sign out + reload token.
          model.signOut()
        }
        Button("Cancel", role: .cancel) {}
      }
    }
  }
}

#Preview {
  SettingsView()
    .environmentObject(AppModel())
}
#endif

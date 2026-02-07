import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentSettingsView: View {
  @EnvironmentObject private var model: AppModel
  @State private var showingResetConfirm = false

  public init() {}

  public var body: some View {
    NavigationStack {
      Form {
        Section {
          AppModeSwitcherView()
        } header: {
          Text("Mode")
        } footer: {
          Text("Switch between the parent and child setup experience.")
        }

        Section("Account (v1A stub)") {
          LabeledContent("Apple user") {
            Text(model.appleUserID ?? "—")
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(.secondary)
          }

          Button("Sign in (stub)") {
            let userID = "apple-stub-\(UUID().uuidString.prefix(8))"
            model.signInStub(userID: userID)
          }

          Button("Sign out", role: .destructive) {
            model.signOut()
          }
        }

        #if DEBUG
        Section("Backend (debug)") {
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

          Text("Admin token is for dev/admin endpoints and should not be shipped to production.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        #endif

        Section("Debug") {
          Button("Reset local data", role: .destructive) {
            showingResetConfirm = true
          }
        }
      }
      .navigationTitle("Settings")
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
  ParentSettingsView()
    .environmentObject(AppModel())
}
#endif

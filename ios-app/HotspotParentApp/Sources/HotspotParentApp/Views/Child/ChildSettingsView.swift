import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ChildSettingsView: View {
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
        }

        Section("Pairing") {
          NavigationLink {
            PairingEntryView()
          } label: {
            Text("Enter / change pairing code")
          }

          if model.loadHotspotConfig() != nil {
            Button("Unpair", role: .destructive) {
              model.unpairChildDevice()
            }
          }
        }

        Section("Shortcut status") {
          LabeledContent("Runs observed") {
            Text("\(model.appIntentRunCount)")
          }
          LabeledContent("Last run") {
            if let last = model.lastAppIntentRunAt {
              Text(last, style: .relative)
            } else {
              Text("—").foregroundStyle(.secondary)
            }
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
  ChildSettingsView()
    .environmentObject(AppModel())
}
#endif

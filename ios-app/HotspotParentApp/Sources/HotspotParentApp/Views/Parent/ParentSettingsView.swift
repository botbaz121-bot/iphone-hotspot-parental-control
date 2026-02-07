import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentSettingsView: View {
  @EnvironmentObject private var model: AppModel
  @StateObject private var iap = IAPManager.shared
  @State private var showingResetConfirm = false
  @State private var iapStatus: String?

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

        Section("In‑app purchases") {
          LabeledContent("Remove ads") {
            Text(iap.adsRemoved ? "Purchased" : "Not purchased")
              .foregroundStyle(iap.adsRemoved ? .green : .secondary)
          }

          Button("Buy: Remove ads") {
            Task {
              iapStatus = nil
              await iap.purchaseRemoveAds()
              await MainActor.run {
                model.adsRemoved = iap.adsRemoved
                iapStatus = "(Stub) Marked as purchased on this device"
              }
            }
          }
          .disabled(iap.adsRemoved)

          Button("Restore purchases") {
            Task {
              iapStatus = nil
              await iap.restorePurchases()
              await MainActor.run {
                model.adsRemoved = iap.adsRemoved
                iapStatus = "Restore not implemented yet"
              }
            }
          }

          #if DEBUG
          Toggle("Debug: ads removed", isOn: Binding(
            get: { iap.adsRemoved },
            set: { iap.setAdsRemovedForDebug($0); model.adsRemoved = iap.adsRemoved }
          ))
          #endif

          if let iapStatus {
            Text(iapStatus)
              .font(.footnote)
              .foregroundStyle(.secondary)
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

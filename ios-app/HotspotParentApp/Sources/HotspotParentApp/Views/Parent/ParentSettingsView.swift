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
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          settingsCard(title: "Mode") {
            VStack(alignment: .leading, spacing: 10) {
              Text("Switch between parent and child setup.")
                .font(.footnote)
                .foregroundStyle(.secondary)
              AppModeSwitcherView()
            }
          }

          settingsCard(title: "Account") {
            VStack(alignment: .leading, spacing: 10) {
              HStack {
                Text("Signed in")
                  .font(.subheadline.weight(.semibold))
                Spacer()
                Text(model.isSignedIn ? "Yes" : "No")
                  .foregroundStyle(model.isSignedIn ? .green : .secondary)
              }

              if model.isSignedIn {
                Button(role: .destructive) {
                  model.signOut()
                } label: {
                  Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
              } else {
                Text("Sign in from Home to manage devices.")
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }
            }
          }

          settingsCard(title: "In-app purchase") {
            VStack(alignment: .leading, spacing: 10) {
              Text(iap.adsRemoved ? "Ads removed ✅" : "Remove ads from the parent experience.")
                .font(.footnote)
                .foregroundStyle(.secondary)

              Button {
                Task {
                  iapStatus = nil
                  await iap.purchaseRemoveAds()
                  await MainActor.run {
                    model.adsRemoved = iap.adsRemoved
                    iapStatus = iap.adsRemoved ? "Purchased" : "Not purchased"
                  }
                }
              } label: {
                Label(iap.adsRemoved ? "Restore purchase (mock)" : "Remove ads (mock)", systemImage: "checkmark")
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .buttonStyle(iap.adsRemoved ? .bordered : .borderedProminent)

              if let iapStatus {
                Text(iapStatus)
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }
            }
          }

          #if DEBUG
          settingsCard(title: "Debug") {
            Text("Debug-only settings live here.")
              .font(.footnote)
              .foregroundStyle(.secondary)

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
          #endif

          settingsCard(title: "Reset") {
            VStack(alignment: .leading, spacing: 10) {
              Text("This clears app settings and sign-in state on this phone.")
                .font(.footnote)
                .foregroundStyle(.secondary)

              Button(role: .destructive) {
                showingResetConfirm = true
              } label: {
                Label("Reset local data", systemImage: "trash")
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .buttonStyle(.bordered)
            }
          }
        }
        .padding()
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

  private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.headline)
      content()
    }
    .padding()
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 18))
  }
}

#Preview {
  ParentSettingsView()
    .environmentObject(AppModel())
}
#endif

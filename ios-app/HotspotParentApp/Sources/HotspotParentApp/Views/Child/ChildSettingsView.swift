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
        VStack(alignment: .leading, spacing: 14) {
          ModeSettingsCardView()
            .environmentObject(model)

          settingsCard(title: "Pairing") {
            VStack(alignment: .leading, spacing: 10) {
              let paired = model.loadHotspotConfig() != nil
              Text(paired ? "Paired." : "Not paired yet.")
                .font(.footnote)
                .foregroundStyle(.secondary)

              Button {
                // Mock QR scan. Route to manual pairing entry for now.
              } label: {
                Label("Scan QR (mock)", systemImage: "qrcode.viewfinder")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.bordered)

              Text("Or enter pairing code")
                .font(.subheadline.weight(.semibold))

              NavigationLink {
                PairingEntryView()
                  .environmentObject(model)
              } label: {
                Text("Enter pairing code")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.borderedProminent)

              if paired {
                Button(role: .destructive) {
                  model.unpairChildDevice()
                } label: {
                  Label("Unpair", systemImage: "link.badge.minus")
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
              }

              Text("Pairing enables the Shortcut to fetch policy (hotspot off + quiet time).")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          settingsCard(title: "Debug (prototype helpers)") {
            VStack(alignment: .leading, spacing: 10) {
              Text("These simulate signals the real app would infer from App Intent runs + permissions.")
                .font(.footnote)
                .foregroundStyle(.secondary)

              HStack(spacing: 12) {
                Button {
                  model.recordIntentRun()
                } label: {
                  Label("Simulate\nShortcut run", systemImage: "link")
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                  model.screenTimeAuthorized = true
                } label: {
                  Label("Set Screen Time\nauth", systemImage: "shield")
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
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
            }
          }

          #if DEBUG
          settingsCard(title: "Debug") {
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
              Text("This clears app settings and pairing on this phone.")
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
  ChildSettingsView()
    .environmentObject(AppModel())
}
#endif

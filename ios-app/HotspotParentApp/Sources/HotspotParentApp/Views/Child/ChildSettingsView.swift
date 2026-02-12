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
              Text(paired ? "Paired ✅" : "Not paired yet.")
                .font(.footnote)
                .foregroundStyle(.secondary)

              NavigationLink {
                PairingEntryView()
                  .environmentObject(model)
              } label: {
                Label(paired ? "View / change pairing" : "Enter pairing code", systemImage: "qrcode")
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .buttonStyle(.borderedProminent)

              if paired {
                Button(role: .destructive) {
                  model.unpairChildDevice()
                } label: {
                  Label("Unpair", systemImage: "link.badge.minus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
              }
            }
          }

          settingsCard(title: "Shortcut status") {
            VStack(alignment: .leading, spacing: 10) {
              HStack {
                Text("Runs observed")
                  .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(model.appIntentRunCount)")
                  .font(.subheadline)
              }

              HStack {
                Text("Last run")
                  .font(.subheadline.weight(.semibold))
                Spacer()
                if let last = model.lastAppIntentRunAt {
                  Text(last, style: .relative)
                    .foregroundStyle(.secondary)
                } else {
                  Text("—")
                    .foregroundStyle(.secondary)
                }
              }
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

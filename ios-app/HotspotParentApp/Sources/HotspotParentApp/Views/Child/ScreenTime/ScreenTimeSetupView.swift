import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ScreenTimeSetupView: View {
  @EnvironmentObject private var model: AppModel
  @State private var status: String?

  public init() {}

  public var body: some View {
    Form {
      Section {
        Text("SpotCheck uses Family Controls to help reduce tampering (e.g., by shielding the Shortcuts app).")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Section("Status") {
        LabeledContent("Authorized") {
          Text(model.screenTimeAuthorized ? "Yes" : "No")
            .foregroundStyle(model.screenTimeAuthorized ? .green : .secondary)
        }
        LabeledContent("Shielding applied") {
          Text(model.shieldingApplied ? "Yes" : "No")
            .foregroundStyle(model.shieldingApplied ? .green : .secondary)
        }
      }

      Section("Actions") {
        Button("Request authorization") {
          Task {
            do {
              let ok = try await ScreenTimeManager.shared.requestAuthorization()
              await MainActor.run {
                model.screenTimeAuthorized = ok
                status = ok ? nil : "Authorization not granted"
              }
            } catch {
              await MainActor.run { status = "Authorization failed: \(error)" }
            }
          }
        }

        Button("Apply shielding") {
          Task {
            do {
              try await ScreenTimeManager.shared.applyRecommendedShielding()
              await MainActor.run {
                model.shieldingApplied = true
                status = nil
              }
            } catch {
              await MainActor.run { status = "Shielding failed: \(error)" }
            }
          }
        }
        .disabled(!model.screenTimeAuthorized)

        Button("Remove shielding", role: .destructive) {
          ScreenTimeManager.shared.clearShielding()
          model.shieldingApplied = false
        }
        .disabled(!model.shieldingApplied)
      }

      if let status {
        Section {
          Text(status)
            .foregroundStyle(.red)
            .font(.footnote)
        }
      }

      Section("Limitations") {
        Text("We can’t detect whether Screen Time passcode is set, whether personal automations exist, or whether Ask Before Running is disabled.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .navigationTitle("Screen Time")
  }
}

#Preview {
  NavigationStack {
    ScreenTimeSetupView()
      .environmentObject(AppModel())
  }
}
#endif

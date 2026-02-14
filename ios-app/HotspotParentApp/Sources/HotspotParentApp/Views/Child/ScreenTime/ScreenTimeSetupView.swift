import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

public struct ScreenTimeSetupView: View {
  @EnvironmentObject private var model: AppModel
  @State private var status: String?

  #if canImport(FamilyControls)
  @State private var selection = FamilyActivitySelection()
  @State private var showingPicker = false
  #endif

  public init() {}

  public var body: some View {
    Form {
      Section {
        VStack(alignment: .leading, spacing: 8) {
          Text("SpotCheck uses Family Controls to help reduce tampering.")
            .font(.footnote)
            .foregroundStyle(.secondary)

          Text("Required: Select and shield the Shortcuts app to prevent disabling automations.")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.orange)
        }
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

        #if canImport(FamilyControls)
        Button("Choose apps to shield") {
          showingPicker = true
        }
        .disabled(!model.screenTimeAuthorized)
        #endif

        Button("Apply shielding") {
          Task {
            do {
              #if canImport(FamilyControls)
              try await ScreenTimeManager.shared.applyShielding(selection: selection)
              #else
              try await ScreenTimeManager.shared.applyShielding()
              #endif

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

        #if canImport(FamilyControls)
        if model.screenTimeAuthorized && !selection.applicationTokens.isEmpty {
          // We can't programmatically force-add Shortcuts; we can only guide/validate.
          let missingShortcuts = !selection.applicationTokens.contains(where: { String(describing: $0).lowercased().contains("shortcuts") })
          if missingShortcuts {
            Text("Tip: Make sure ‘Shortcuts’ is selected in the app picker.")
              .font(.footnote)
              .foregroundStyle(.orange)
          }
        }
        #endif

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
    #if canImport(FamilyControls)
    .sheet(isPresented: $showingPicker) {
      NavigationStack {
        FamilyActivityPicker(selection: $selection)
          .navigationTitle("Select apps")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") { showingPicker = false }
            }
          }
      }
    }
    #endif
  }
}

#Preview {
  NavigationStack {
    ScreenTimeSetupView()
      .environmentObject(AppModel())
  }
}
#endif

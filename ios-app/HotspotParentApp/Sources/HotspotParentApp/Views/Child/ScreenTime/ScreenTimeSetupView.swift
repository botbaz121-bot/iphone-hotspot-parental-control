import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

public struct ScreenTimeSetupView: View {
  @EnvironmentObject private var model: AppModel
  @State private var statusText: String?
  @State private var selectionSummary = ScreenTimeSelectionSummary()
  @State private var busy = false

  #if canImport(FamilyControls)
  @State private var requiredSelection = FamilyActivitySelection()
  @State private var quietSelection = FamilyActivitySelection()
  @State private var showingRequiredPicker = false
  @State private var showingQuietPicker = false
  #endif

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("Screen Time protection")
          .font(.system(size: 34, weight: .bold))
          .padding(.top, 2)

        Text("Shortcuts stays locked at all times. Other selected apps are shielded only during parent quiet hours.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .padding(.bottom, 2)

        SettingsGroup("Step 1") {
          SettingsRow(
            systemIcon: model.screenTimeAuthorized ? "checkmark.shield" : "shield",
            title: "Grant Screen Time permission",
            subtitle: model.screenTimeAuthorized ? "Permission granted" : "Required before protection can be activated",
            rightText: model.screenTimeAuthorized ? "Done" : "Pending",
            showsChevron: false,
            action: nil
          )
        }

        Button {
          Task { await requestAuthorization() }
        } label: {
          Text(model.screenTimeAuthorized ? "Permission granted" : "Request permission")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(busy || model.screenTimeAuthorized)

        SettingsGroup("Step 2") {
          SettingsRow(
            systemIcon: selectionSummary.hasRequiredSelection ? "checkmark.circle" : "exclamationmark.circle",
            title: "Always-locked app (required)",
            subtitle: "Choose Shortcuts here so it stays locked at all times",
            rightText: selectionSummary.hasRequiredSelection ? "Ready" : "Missing",
            showsChevron: false,
            action: nil
          )

          SettingsDivider()

          SettingsRow(
            systemIcon: "app.badge",
            title: "Always-locked selections",
            subtitle: "Apps and categories blocked all day",
            rightText: "\(selectionSummary.requiredSelectionsSelected)",
            showsChevron: false,
            action: nil
          )

          SettingsDivider()

          SettingsRow(
            systemIcon: "moon.stars",
            title: "Quiet-hours selections",
            subtitle: "Apps and categories blocked only during quiet hours",
            rightText: "\(selectionSummary.quietSelectionsSelected)",
            showsChevron: false,
            action: nil
          )
        }

        #if canImport(FamilyControls)
        Button {
          showingRequiredPicker = true
        } label: {
          Text("Choose always-locked app")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!model.screenTimeAuthorized || busy)

        Button {
          showingQuietPicker = true
        } label: {
          Text("Choose quiet-hours apps (optional)")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!model.screenTimeAuthorized || busy)
        #endif

        SettingsGroup("Step 3") {
          SettingsRow(
            systemIcon: model.shieldingApplied ? "lock.shield" : "lock.open",
            title: "Activate protection",
            subtitle: model.shieldingApplied ? "Protection is active" : "Apply the configured protection now",
            rightText: model.shieldingApplied ? "Active" : "Inactive",
            showsChevron: false,
            action: nil
          )
        }

        Button {
          Task { await activateProtection() }
        } label: {
          Text(model.shieldingApplied ? "Re-apply protection" : "Activate protection")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!model.screenTimeAuthorized || !selectionSummary.hasRequiredSelection || busy)

        SettingsGroup("Protection status") {
          SettingsRow(
            systemIcon: model.shieldingApplied ? "checkmark.shield" : "xmark.shield",
            title: "Always-locked app",
            subtitle: "Should remain blocked all day",
            rightText: model.shieldingApplied ? "On" : "Off",
            showsChevron: false,
            action: nil
          )

          SettingsDivider()

          SettingsRow(
            systemIcon: "clock.badge",
            title: "Quiet-hours apps",
            subtitle: model.screenTimeScheduleEnforcedNow ? "Currently locked (quiet hours)" : "Currently allowed",
            rightText: model.screenTimeScheduleEnforcedNow ? "Locked" : "Allowed",
            showsChevron: false,
            action: nil
          )
        }

        if let reason = model.screenTimeDegradedReason, !reason.isEmpty {
          Text(reason)
            .font(.footnote)
            .foregroundStyle(.orange)
        }

        if let statusText, !statusText.isEmpty {
          Text(statusText)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        HStack(spacing: 10) {
          Button {
            Task { await refreshStatus() }
          } label: {
            Text("Refresh status")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .disabled(busy)

          Button(role: .destructive) {
            ScreenTimeManager.shared.clearShielding()
            model.shieldingApplied = false
            model.screenTimeDegradedReason = "Protection was turned off on this phone."
            statusText = "Protection removed."
          } label: {
            Text("Turn off")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }
      }
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await loadSelectionAndRefresh()
    }
    #if canImport(FamilyControls)
    .onChange(of: requiredSelection) { newValue in
      ScreenTimeManager.shared.saveRequiredSelection(newValue)
      selectionSummary = ScreenTimeManager.shared.selectionSummary()
    }
    .onChange(of: quietSelection) { newValue in
      ScreenTimeManager.shared.saveQuietSelection(newValue)
      selectionSummary = ScreenTimeManager.shared.selectionSummary()
    }
    .sheet(isPresented: $showingRequiredPicker) {
      NavigationStack {
        FamilyActivityPicker(selection: $requiredSelection)
          .navigationTitle("Always-locked app")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") {
                showingRequiredPicker = false
                ScreenTimeManager.shared.saveRequiredSelection(requiredSelection)
                selectionSummary = ScreenTimeManager.shared.selectionSummary()
                Task { await refreshStatus() }
              }
            }
          }
      }
    }
    .sheet(isPresented: $showingQuietPicker) {
      NavigationStack {
        FamilyActivityPicker(selection: $quietSelection)
          .navigationTitle("Quiet-hours apps")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") {
                showingQuietPicker = false
                ScreenTimeManager.shared.saveQuietSelection(quietSelection)
                selectionSummary = ScreenTimeManager.shared.selectionSummary()
                Task { await refreshStatus() }
              }
            }
          }
      }
    }
    #endif
  }

  private func loadSelectionAndRefresh() async {
    #if canImport(FamilyControls)
    if let savedRequired = ScreenTimeManager.shared.loadRequiredSelection() {
      requiredSelection = savedRequired
    }
    if let savedQuiet = ScreenTimeManager.shared.loadQuietSelection() {
      quietSelection = savedQuiet
    }
    #endif
    selectionSummary = ScreenTimeManager.shared.selectionSummary()
    await refreshStatus()
  }

  private func requestAuthorization() async {
    busy = true
    defer { busy = false }

    do {
      let ok = try await ScreenTimeManager.shared.requestAuthorization()
      model.screenTimeAuthorized = ok
      statusText = ok ? "Permission granted." : "Permission not granted."
      await refreshStatus()
    } catch {
      statusText = "Authorization failed: \(error)"
    }
  }

  private func activateProtection() async {
    busy = true
    defer { busy = false }

    #if canImport(FamilyControls)
    ScreenTimeManager.shared.saveRequiredSelection(requiredSelection)
    ScreenTimeManager.shared.saveQuietSelection(quietSelection)
    #endif
    await refreshStatus()
    if model.shieldingApplied {
      statusText = "Protection active."
    }
  }

  private func refreshStatus() async {
    let status = await ScreenTimeManager.shared.reconcileProtectionNow()
    model.screenTimeAuthorized = status.authorized
    model.shieldingApplied = status.shieldingApplied
    model.screenTimeHasRequiredSelection = status.hasRequiredSelection
    model.screenTimeScheduleEnforcedNow = status.scheduleEnforcedNow
    model.screenTimeDegradedReason = status.degradedReason
    selectionSummary = ScreenTimeManager.shared.selectionSummary()
  }
}

#Preview {
  NavigationStack {
    ScreenTimeSetupView()
      .environmentObject(AppModel())
  }
}
#endif

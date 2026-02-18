import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

public struct ScreenTimeSetupView: View {
  @EnvironmentObject private var model: AppModel
  @State private var statusText: String?
  @State private var debugText: String?
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

        Text("Shortcuts stays locked at all times. Other selected apps are shielded only during enforcement schedule hours.")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
          .padding(.bottom, 2)

        SettingsGroup("Permission") {
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
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(busy || model.screenTimeAuthorized)

        SettingsGroup("Step 1: Always Locked Apps") {
          SettingsRow(
            systemIcon: selectionSummary.hasRequiredSelection ? "checkmark.circle" : "exclamationmark.circle",
            title: "Always Locked Apps",
            subtitle: "Select one or more apps to lock all day",
            rightText: selectionSummary.hasRequiredSelection ? "Ready" : "Missing",
            showsChevron: false,
            action: nil
          )

          SettingsDivider()

          SettingsRow(
            systemIcon: "link",
            title: "Shortcuts should be included",
            subtitle: "For automation safety, lock Shortcuts (usually under Productivity & Finance)",
            rightText: nil,
            showsChevron: false,
            action: nil
          )

          SettingsDivider()

          SettingsRow(
            systemIcon: "app.badge",
            title: "Always Locked selections",
            subtitle: "Apps and categories blocked all day",
            rightText: "\(selectionSummary.requiredSelectionsSelected)",
            showsChevron: false,
            action: nil
          )
        }

        #if canImport(FamilyControls)
        Button {
          showingRequiredPicker = true
        } label: {
          Text("Choose Always Locked Apps")
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!model.screenTimeAuthorized || busy)

        SettingsGroup("Step 2: Enforcement Schedule") {
          SettingsRow(
            systemIcon: "moon.stars",
            title: "Enforcement Schedule selections",
            subtitle: "Apps and categories blocked only during enforcement schedule hours",
            rightText: "\(selectionSummary.quietSelectionsSelected)",
            showsChevron: false,
            action: nil
          )
        }

        Button {
          showingQuietPicker = true
        } label: {
          Text("Choose Enforcement Schedule Apps (optional)")
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!model.screenTimeAuthorized || busy)
        #endif

        SettingsGroup("Status") {
          SettingsRow(
            systemIcon: "clock.badge",
            title: "Enforcement Schedule apps",
            subtitle: model.screenTimeScheduleEnforcedNow ? "Currently locked (enforcement schedule active)" : "Currently allowed",
            rightText: model.screenTimeScheduleEnforcedNow ? "Locked" : "Allowed",
            showsChevron: false,
            action: nil
          )
        }

        if let reason = model.screenTimeDegradedReason, !reason.isEmpty {
          Text(reason)
            .font(.system(size: 14))
            .foregroundStyle(.orange)
        }

        if let statusText, !statusText.isEmpty {
          Text(statusText)
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        }

        if let debugText, !debugText.isEmpty {
          Text(debugText)
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .foregroundStyle(.secondary)
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
          .navigationTitle("Always Locked Apps")
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
          .navigationTitle("Enforcement Schedule Apps")
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

  private func refreshStatus() async {
    let status = await ScreenTimeManager.shared.reconcileProtectionNow()
    model.screenTimeAuthorized = status.authorized
    model.shieldingApplied = status.shieldingApplied
    model.screenTimeHasRequiredSelection = status.hasRequiredSelection
    model.screenTimeScheduleEnforcedNow = status.scheduleEnforcedNow
    model.screenTimeDegradedReason = status.degradedReason
    debugText = ScreenTimeManager.shared.currentPolicyDebugLine()
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

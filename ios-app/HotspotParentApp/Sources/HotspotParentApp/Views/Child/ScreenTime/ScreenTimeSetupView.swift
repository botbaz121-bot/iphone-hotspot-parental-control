import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(SwiftUI)
public struct ScreenTimeSetupView: View {
  @EnvironmentObject private var model: AppModel
  @State private var statusText: String?
  @State private var selectionSummary = ScreenTimeSelectionSummary()
  @State private var busy = false
  @State private var openedScreenTimeSettings = false
  @State private var openedDeletionProtectionSettings = false

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("Screen Time protection")
          .font(.system(size: 34, weight: .bold))
          .padding(.top, 2)

        Text("Complete each step to protect automation settings.")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
          ChecklistTile(
            color: model.screenTimeAuthorized ? .pink : .gray,
            systemIcon: "shield",
            customIcon: nil,
            title: "Grant Permissions",
            subtitle: model.screenTimeAuthorized
              ? "Done (\(model.screenTimeAuthorizationMode.title))"
              : "Tap to allow Screen Time protection",
            disabled: busy
          ) {
            Task { await requestAuthorization() }
          }

          ChecklistTile(
            color: openedScreenTimeSettings ? .pink : .gray,
            systemIcon: "lock.shield",
            customIcon: nil,
            title: "Screen Time Password",
            subtitle: openedScreenTimeSettings
              ? "Done"
              : "Set a Screen Time passcode and lock Screen Time settings.",
            disabled: busy
          ) {
            openScreenTimeSettings()
          }

          if model.screenTimeAuthorized && model.screenTimeAuthorizationMode == .individual {
            ChecklistTile(
              color: openedDeletionProtectionSettings ? .pink : .gray,
              systemIcon: "trash.slash",
              customIcon: nil,
              title: "Prevent App Deletions",
              subtitle: openedDeletionProtectionSettings
                ? "Done"
                : "Set Screen Time to disallow deleting apps.",
              disabled: busy
            ) {
              openDeletionProtectionSettings()
            }
          }
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

      }
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await loadSelectionAndRefresh()
    }
  }

  private func loadSelectionAndRefresh() async {
    openedScreenTimeSettings = model.screenTimePasswordStepCompleted
    openedDeletionProtectionSettings = model.screenTimeDeletionProtectionStepCompleted
    selectionSummary = ScreenTimeManager.shared.selectionSummary()
    await refreshStatus()
  }

  private func requestAuthorization() async {
    busy = true
    defer { busy = false }

    let result = await ScreenTimeManager.shared.requestAuthorizationAuto()
    model.screenTimeAuthorized = result.approved
    if let grantedMode = result.grantedMode {
      model.screenTimeAuthorizationMode = grantedMode
      statusText = "Permission granted (\(grantedMode.title)). \(result.debugLine)"
    } else {
      statusText = "Permission not granted. \(result.debugLine)"
    }
    await refreshStatus()
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

  private func openScreenTimeSettings() {
    #if canImport(UIKit)
    let candidates = [
      "App-prefs:root=SCREEN_TIME",
      "App-prefs:SCREEN_TIME",
      "prefs:root=SCREEN_TIME",
      "App-prefs:",
      "prefs:root=General",
    ]

    func tryOpen(_ index: Int) {
      guard index < candidates.count else {
        if let appSettingsURL = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(appSettingsURL, options: [:]) { success in
            openedScreenTimeSettings = success
            statusText = success
              ? "Opened app settings. Go to Screen Time."
              : "Could not open Settings."
          }
        } else {
          statusText = "Could not open Settings."
        }
        return
      }

      guard let url = URL(string: candidates[index]) else {
        tryOpen(index + 1)
        return
      }

      UIApplication.shared.open(url, options: [:]) { success in
        if success {
          openedScreenTimeSettings = true
          model.screenTimePasswordStepCompleted = true
          statusText = "Opened Screen Time settings."
        } else {
          tryOpen(index + 1)
        }
      }
    }

    tryOpen(0)
    #else
    statusText = "Settings shortcut unavailable on this build."
    #endif
  }

  private func openDeletionProtectionSettings() {
    #if canImport(UIKit)
    let candidates = [
      "App-prefs:root=SCREEN_TIME&path=CONTENT_PRIVACY",
      "App-prefs:root=SCREEN_TIME&path=CONTENT_AND_PRIVACY",
      "prefs:root=SCREEN_TIME&path=CONTENT_PRIVACY",
      "prefs:root=SCREEN_TIME&path=CONTENT_AND_PRIVACY",
      "App-prefs:root=SCREEN_TIME",
      "prefs:root=SCREEN_TIME",
    ]

    func tryOpen(_ index: Int) {
      guard index < candidates.count else {
        statusText = "Could not open Screen Time restrictions."
        return
      }

      guard let url = URL(string: candidates[index]) else {
        tryOpen(index + 1)
        return
      }

      UIApplication.shared.open(url, options: [:]) { success in
        if success {
          openedDeletionProtectionSettings = true
          model.screenTimeDeletionProtectionStepCompleted = true
          statusText = "Opened Screen Time restrictions."
        } else {
          tryOpen(index + 1)
        }
      }
    }

    tryOpen(0)
    #else
    statusText = "Settings shortcut unavailable on this build."
    #endif
  }
}

private struct ChecklistTile: View {
  let color: ShortcutTileColor
  let systemIcon: String?
  let customIcon: Image?
  let title: String
  let subtitle: String
  let disabled: Bool
  let action: () -> Void

  var body: some View {
    Button {
      action()
    } label: {
      ZStack {
        RoundedRectangle(cornerRadius: 22)
          .fill(color.gradient)

        VStack(alignment: .leading, spacing: 10) {
          ZStack {
            RoundedRectangle(cornerRadius: 10)
              .fill(Color.black.opacity(0.22))
              .overlay(
                RoundedRectangle(cornerRadius: 10)
                  .stroke(Color.white.opacity(0.18), lineWidth: 1)
              )
            if let customIcon {
              customIcon
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.95))
                .frame(width: 18, height: 18)
            } else if let systemIcon {
              Image(systemName: systemIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
            }
          }
          .frame(width: 28, height: 28)

          Spacer(minLength: 0)

          Text(title)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white.opacity(0.95))
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text(subtitle)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.80))
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
      }
      .frame(minHeight: 124)
      .opacity(disabled ? 0.7 : 1)
    }
    .buttonStyle(.plain)
    .disabled(disabled)
  }
}

#Preview {
  NavigationStack {
    ScreenTimeSetupView()
      .environmentObject(AppModel())
  }
}
#endif

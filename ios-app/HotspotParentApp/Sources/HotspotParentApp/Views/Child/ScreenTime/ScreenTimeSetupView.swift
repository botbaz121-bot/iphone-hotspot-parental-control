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

  #if canImport(FamilyControls)
  @State private var requiredSelection = FamilyActivitySelection()
  @State private var showingRequiredPicker = false
  #endif

  private static let shortcutsIconBase64 = "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAACXBIWXMAAAsTAAALEwEAmpwYAAAD2UlEQVR4nO2ZS2hVRxzGf01qrBofWC2INmIQBNMWFdpCF1URdFe0ahBfCD6KqbTGjVmpqzYIFVwI6kJKTXTV1i6ki+6r+EBMjPHRbGwbbE2FkpgYX1cGvgN/LveeOY977skiHwxcznzzf9wz8//mzMA4xpEb6oBm4BxwBxgCChm3IfnqlG8XQyp8DvRVIXBf+wNYlySBGuCoMXQT+ApYDEwhe0wBmoCvgS4TR7tii4wgiafAF3EHVxg1wF7FEiQTeToFSSxn7GCFSWatj1xn1oR7E2MNLYrtPjAhjNhs1kSa6fQWcAC4Cgyrud+t6kuKWqBbMW4II54TyS3spHgf6A2pQL3iJMV+2ekII90VyVWnJNhidKZX/9ostY3AbfU9AbYm9NEkG05nymJQpPqYxt9UNQn+9R+AySV4blqdNrxTwMSYvqZqrIu1LAIHcTAP+N1UOlf7fdiut+LGXAcWxPRZ8MUZNxFXEh9qzAPg4xhjl5oKOQCsySORN4CDwAvxLwIziY/pwE+y8SqGclckkWkJnVfyTymkTaTRTIdHMaeDD87WI9nuk6+kcXoJv6j/CtBA5dEg287HhRRxegkD6ve9+kkplP1t88aTxukl3FB/Wwjng5TK3mbKcmaJNGuBO87JEhs3qw+llD1IcEi7AAtn66QpIuuzTAQFNCzeb8AMPZ8D/K3n32t6FcM9O2P8nNCOe4ZsFWTb+aiKjnwI9Jt/fqFR+W0Rxu8CRjT+snlT/bJdVWV/t0iZPyUelgF/GZ/OlrOZq7K7NgrsIDo2mbeSi7LPlPo63kvgEPCdGfutJ5gacQL+MeCwbBXyUvbVpm838Ex9P5Y5bZmsvoK4e4qUfcBMswV5Kvsq4LE491R93lFr1rOCOI5bjPlG2X/OW9kXAT0hgtgjjk/Z/81b2QO92K/SOqR2SR9dvi1Km3xcq6ayu0/cSqHqyr7ebEOssqfBVFMJR4DN1dKRJcCf5rAsbM770GhOV/qBj6qt7HM1jx3/P32/x8UnwD+y4Q6rXdWi2omgY6MLFVD2X/UJTV6JBNuVI2bscY+yl+K7o9A48MaZ9IDOYWeRspc7oDsvznPgywR+pmn8/1kemZZS9tlG2e97lD0K3otyZNopUpTTwqyU3YdW2Tkb5VqhK+VZVRplD4NbS7eiXCvU6eKxoOuusYZ9ZtqGXvSg29PgQDqJNmSFlSrxbvvyWdRB7SaZlgTlsZKo1ZsYVUzfxBlcU3Tf0a0535SwNMdFvapTq1kTr5REorW71pTMPNu9ONOpHCaoQnTo2CYQzSzboDaSZ+Xbu7DHMQ6ywWtk2y9Osdf+/AAAAABJRU5ErkJggg=="

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
              : "Tap to auto-detect and grant Screen Time",
            disabled: busy
          ) {
            Task { await requestAuthorization() }
          }

          ChecklistTile(
            color: selectionSummary.hasRequiredSelection ? .pink : .gray,
            systemIcon: selectionSummary.hasRequiredSelection ? nil : "link",
            customIcon: shortcutsIcon,
            title: "Lock Shortcuts",
            subtitle: selectionSummary.hasRequiredSelection
              ? "Done"
              : "Pick Shortcuts app. Usually in Productivity & Finance.",
            disabled: !model.screenTimeAuthorized || busy
          ) {
            #if canImport(FamilyControls)
            showingRequiredPicker = true
            #endif
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
    #if canImport(FamilyControls)
    .onChange(of: requiredSelection) { newValue in
      ScreenTimeManager.shared.saveRequiredSelection(newValue)
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
    #endif
  }

  private var shortcutsIcon: Image? {
    #if canImport(UIKit)
    guard let data = Data(base64Encoded: Self.shortcutsIconBase64),
          let uiImage = UIImage(data: data) else { return nil }
    return Image(uiImage: uiImage)
    #else
    return nil
    #endif
  }

  private func loadSelectionAndRefresh() async {
    #if canImport(FamilyControls)
    if let savedRequired = ScreenTimeManager.shared.loadRequiredSelection() {
      requiredSelection = savedRequired
    }
    #endif
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
    if let screenTimeURL = URL(string: "App-prefs:root=SCREEN_TIME") {
      UIApplication.shared.open(screenTimeURL, options: [:]) { success in
        if success {
          openedScreenTimeSettings = true
          statusText = "Opened Screen Time settings."
        } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(settingsURL, options: [:]) { fallbackSuccess in
            openedScreenTimeSettings = fallbackSuccess
            statusText = fallbackSuccess
              ? "Opened Settings. Go to Screen Time."
              : "Could not open Settings."
          }
        } else {
          statusText = "Could not open Settings."
        }
      }
    } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(settingsURL, options: [:]) { success in
        openedScreenTimeSettings = success
        statusText = success
          ? "Opened Settings. Go to Screen Time."
          : "Could not open Settings."
      }
    } else {
      statusText = "Could not open Settings."
    }
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
          if let customIcon {
            customIcon
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .foregroundStyle(.white.opacity(0.95))
              .frame(width: 28, height: 28)
          } else if let systemIcon {
            Image(systemName: systemIcon)
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(.white.opacity(0.95))
              .frame(width: 28, height: 28)
          }

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

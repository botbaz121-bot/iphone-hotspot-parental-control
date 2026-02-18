import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct ChildDashboardView: View {
  @EnvironmentObject private var model: AppModel
  @State private var showAutomationsInfo = false
  @State private var showFinishConfirm = false

  private struct AutomationRow: View {
    let triggerIcon: String
    let triggerIconColor: Color
    let triggerIconBackground: Color
    let title: String

    var body: some View {
      HStack(spacing: 10) {
        HStack(spacing: 7) {
          ZStack {
            RoundedRectangle(cornerRadius: 7)
              .fill(triggerIconBackground)
            Image(systemName: triggerIcon)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(triggerIconColor)
          }
          .frame(width: 24, height: 24)

          Image(systemName: "arrow.right")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary.opacity(0.7))

          ZStack {
            RoundedRectangle(cornerRadius: 7)
              .fill(Color(red: 0.29, green: 0.41, blue: 1.00))
            Image(systemName: "globe")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.white)
          }
          .frame(width: 24, height: 24)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.system(size: 16, weight: .semibold))
            .lineLimit(1)
            .truncationMode(.tail)

          Text("Enforce Hotspot Policy")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 0)

        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary.opacity(0.8))
      }
      .padding(.vertical, 10)
      .padding(.horizontal, 12)
    }
  }

  public init() {}

  private var pairingComplete: Bool {
    model.loadHotspotConfig() != nil
  }

  private var shortcutComplete: Bool {
    model.appIntentRunCount > 0
  }

  private var automationsComplete: Bool {
    model.appIntentRunCount >= 2
  }

  private var screenTimeComplete: Bool {
    model.screenTimeAuthorized && model.screenTimeHasRequiredSelection
  }

  private var canFinishSetup: Bool {
    pairingComplete && shortcutComplete && automationsComplete && screenTimeComplete
  }

  private var finishMissingSummary: String {
    var missing: [String] = []
    if !pairingComplete { missing.append("Pairing") }
    if !shortcutComplete { missing.append("Shortcut") }
    if !automationsComplete { missing.append("Automations") }
    if !screenTimeComplete { missing.append("Screen Time") }
    if missing.isEmpty { return "Lock phone into child mode" }
    return "Complete first: " + missing.joined(separator: ", ")
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Setup checklist")
          .font(.system(size: 34, weight: .bold))
          .padding(.top, 2)

        Text("Complete these steps so rules can be enforced.")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
          pairingTile
          shortcutTile
          automationsTile
          screenTimeTile
          finishTile
        }
        .padding(.top, 6)
      }
      .padding(.top, 18)
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
    // Re-read intent telemetry (AppIntents update SharedDefaults out-of-process)
    // so the dashboard highlights update without restarting the app.
    // This runs whenever the view appears.
    .onAppear { model.syncFromSharedDefaults() }
    .sheet(isPresented: $showAutomationsInfo) {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            Text("Personal")
              .font(.system(size: 34, weight: .bold))
              .padding(.top, 2)

            VStack(spacing: 0) {
              AutomationRow(
                triggerIcon: "clock.fill",
                triggerIconColor: .orange,
                triggerIconBackground: Color.orange.opacity(0.18),
                title: "At a time, daily"
              )
              SettingsDivider()
              AutomationRow(
                triggerIcon: "wifi",
                triggerIconColor: .blue,
                triggerIconBackground: Color.blue.opacity(0.18),
                title: "When joining your Wi‑Fi"
              )
              SettingsDivider()
              AutomationRow(
                triggerIcon: "arrow.up.right.square.fill",
                triggerIconColor: .white.opacity(0.9),
                triggerIconBackground: Color.white.opacity(0.12),
                title: "When \"Settings\" is opened"
              )
              SettingsDivider()
              AutomationRow(
                triggerIcon: "battery.50",
                triggerIconColor: .white.opacity(0.9),
                triggerIconBackground: Color.white.opacity(0.12),
                title: "When battery level is 50%"
              )
            }
            .background(Color.white.opacity(0.06))
            .overlay(
              RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
          }
          .padding(18)
        }
        .navigationTitle("Automations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button("Done") {
              showAutomationsInfo = false
            }
          }
        }
      }
    }
    .confirmationDialog(
      "Logout and lock this phone?",
      isPresented: $showFinishConfirm,
      titleVisibility: .visible
    ) {
      Button("Logout and lock", role: .destructive) {
        // Lock the child setup screen and remove parent session from this device.
        model.signOut()
        model.lockChildSetup()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will sign the parent out on this phone and show the locked screen.")
    }
  }

  private var pairingTile: some View {
    let paired = pairingComplete
    return NavigationLink {
      PairingEntryView()
        .environmentObject(model)
    } label: {
      ShortcutTileCard(
        color: paired ? .pink : .gray,
        systemIcon: "qrcode",
        title: paired ? "Edit pairing" : "Start pairing",
        subtitle: paired ? "Paired ✅" : "Not paired yet"
      )
    }
    .buttonStyle(.plain)
  }

  private var shortcutTile: some View {
    let shortcutURL = "https://www.icloud.com/shortcuts/397015e4b5f24d488f12d0658454c6a0"
    let hasRun = shortcutComplete
    return ShortcutTile(
      color: hasRun ? .pink : .gray,
      systemIcon: "link",
      title: "Install our Shortcut",
      subtitle: hasRun ? "Done" : "Open link, add Shortcut, run once"
    ) {
      openURL(shortcutURL)
    }
  }

  private var automationsTile: some View {
    let ok = automationsComplete
    return ShortcutTile(
      color: ok ? .pink : .gray,
      systemIcon: "wrench.and.screwdriver",
      title: "Automations",
      subtitle: ok ? "Done" : "Tap to view instructions"
    ) {
      showAutomationsInfo = true
    }
  }

  private var screenTimeTile: some View {
    let ok = screenTimeComplete
    let subtitle: String = {
      if !ok { return "Needs setup" }
      if model.shieldingApplied { return "Managed by parent" }
      return "Configured (parent can enable)"
    }()
    return NavigationLink {
      ScreenTimeSetupView()
        .environmentObject(model)
    } label: {
      ShortcutTileCard(
        color: ok ? .pink : .gray,
        systemIcon: "shield",
        title: "Screen Time lock",
        subtitle: subtitle
      )
    }
    .buttonStyle(.plain)
  }

  private var finishTile: some View {
    Button {
      showFinishConfirm = true
    } label: {
      ShortcutTileCard(
        color: canFinishSetup ? .pink : .gray,
        systemIcon: "checkmark",
        title: "Finish setup",
        subtitle: canFinishSetup ? "Lock phone into child mode" : finishMissingSummary
      )
      .opacity(canFinishSetup ? 1.0 : 0.7)
    }
    .buttonStyle(.plain)
    .disabled(!canFinishSetup)
  }

  private func openURL(_ s: String) {
    guard let url = URL(string: s) else { return }
    #if canImport(UIKit)
    UIApplication.shared.open(url)
    #endif
  }
}

#Preview {
  ChildDashboardView()
    .environmentObject(AppModel())
}
#endif

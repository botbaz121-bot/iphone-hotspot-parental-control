import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(UIKit)
import UIKit
#endif

public struct ChildDashboardView: View {
  @EnvironmentObject private var model: AppModel
  @State private var showAutomationsInfo = false
  @State private var showFinishConfirm = false
  #if canImport(FamilyControls)
  @State private var requiredSelection = FamilyActivitySelection()
  @State private var showingRequiredPicker = false
  @State private var quietSelection = FamilyActivitySelection()
  @State private var showingQuietPicker = false
  #endif

  private static let shortcutsIconBase64 = "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAACXBIWXMAAAsTAAALEwEAmpwYAAAD2UlEQVR4nO2ZS2hVRxzGf01qrBofWC2INmIQBNMWFdpCF1URdFe0ahBfCD6KqbTGjVmpqzYIFVwI6kJKTXTV1i6ki+6r+EBMjPHRbGwbbE2FkpgYX1cGvgN/LveeOY977skiHwxcznzzf9wz8//mzMA4xpEb6oBm4BxwBxgCChm3IfnqlG8XQyp8DvRVIXBf+wNYlySBGuCoMXQT+ApYDEwhe0wBmoCvgS4TR7tii4wgiafAF3EHVxg1wF7FEiQTeToFSSxn7GCFSWatj1xn1oR7E2MNLYrtPjAhjNhs1kSa6fQWcAC4Cgyrud+t6kuKWqBbMW4II54TyS3spHgf6A2pQL3iJMV+2ekII90VyVWnJNhidKZX/9ostY3AbfU9AbYm9NEkG05nymJQpPqYxt9UNQn+9R+AySV4blqdNrxTwMSYvqZqrIu1LAIHcTAP+N1UOlf7fdiut+LGXAcWxPRZ8MUZNxFXEh9qzAPg4xhjl5oKOQCsySORN4CDwAvxLwIziY/pwE+y8SqGclckkWkJnVfyTymkTaTRTIdHMaeDD87WI9nuk6+kcXoJv6j/CtBA5dEg287HhRRxegkD6ve9+kkplP1t88aTxukl3FB/Wwjng5TK3mbKcmaJNGuBO87JEhs3qw+llD1IcEi7AAtn66QpIuuzTAQFNCzeb8AMPZ8D/K3n32t6FcM9O2P8nNCOe4ZsFWTb+aiKjnwI9Jt/fqFR+W0Rxu8CRjT+snlT/bJdVWV/t0iZPyUelgF/GZ/OlrOZq7K7NgrsIDo2mbeSi7LPlPo63kvgEPCdGfutJ5gacQL+MeCwbBXyUvbVpm838Ex9P5Y5bZmsvoK4e4qUfcBMswV5Kvsq4LE491R93lFr1rOCOI5bjPlG2X/OW9kXAT0hgtgjjk/Z/81b2QO92K/SOqR2SR9dvi1Km3xcq6ayu0/cSqHqyr7ebEOssqfBVFMJR4DN1dKRJcCf5rAsbM770GhOV/qBj6qt7HM1jx3/P32/x8UnwD+y4Q6rXdWi2omgY6MLFVD2X/UJTV6JBNuVI2bscY+yl+K7o9A48MaZ9IDOYWeRspc7oDsvznPgywR+pmn8/1kemZZS9tlG2e97lD0K3otyZNopUpTTwqyU3YdW2Tkb5VqhK+VZVRplD4NbS7eiXCvU6eKxoOuusYZ9ZtqGXvSg29PgQDqJNmSFlSrxbvvyWdRB7SaZlgTlsZKo1ZsYVUzfxBlcU3Tf0a0535SwNMdFvapTq1kTr5REorW71pTMPNu9ONOpHCaoQnTo2CYQzSzboDaSZ+Xbu7DHMQ6ywWtk2y9Osdf+/AAAAABJRU5ErkJggg=="

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
            Image(systemName: "lock.shield.fill")
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
          lockSettingsTile
          lockAppsTile
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
    #if canImport(FamilyControls)
    .onAppear {
      if let savedRequired = ScreenTimeManager.shared.loadRequiredSelection() {
        requiredSelection = savedRequired
      }
      if let saved = ScreenTimeManager.shared.loadQuietSelection() {
        quietSelection = saved
      }
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
                Task {
                  await model.reconcileScreenTimeProtection()
                }
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
                Task {
                  await model.reconcileScreenTimeProtection()
                }
              }
            }
          }
      }
    }
    #endif
    .sheet(isPresented: $showAutomationsInfo) {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            Text("Personal")
              .font(.system(size: 34, weight: .bold))
              .padding(.top, 2)

            Text("Set these automations up in Shortcuts exactly like this. Add multiple times per day, and add multiple battery levels. More triggers means policy checks run more often.")
              .font(.system(size: 15))
              .foregroundStyle(.secondary)

            VStack(spacing: 0) {
              AutomationRow(
                triggerIcon: "clock.fill",
                triggerIconColor: .orange,
                triggerIconBackground: Color.orange.opacity(0.18),
                title: "At 16:00, daily"
              )
              SettingsDivider()
              AutomationRow(
                triggerIcon: "clock.fill",
                triggerIconColor: .orange,
                triggerIconBackground: Color.orange.opacity(0.18),
                title: "At 21:00, daily"
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
                triggerIcon: "battery.50",
                triggerIconColor: .white.opacity(0.9),
                triggerIconBackground: Color.white.opacity(0.12),
                title: "When battery level is 50%"
              )
              SettingsDivider()
              AutomationRow(
                triggerIcon: "battery.25",
                triggerIconColor: .white.opacity(0.9),
                triggerIconBackground: Color.white.opacity(0.12),
                title: "When battery level is 20%"
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
        subtitle: paired ? "Paired" : "Not paired yet"
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
      customIcon: shortcutsIcon,
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
        color: canFinishSetup ? .blue : .gray,
        systemIcon: "checkmark",
        title: "Finish setup",
        subtitle: canFinishSetup ? "Lock phone into child mode" : finishMissingSummary
      )
      .opacity(canFinishSetup ? 1.0 : 0.86)
    }
    .buttonStyle(.plain)
    .disabled(!canFinishSetup)
  }

  private var lockAppsTile: some View {
    let quietCount = ScreenTimeManager.shared.selectionSummary().quietSelectionsSelected
    let ok = quietCount > 0
    return ShortcutTile(
      color: ok ? .pink : .gray,
      systemIcon: "moon.stars",
      title: "Lock apps",
      subtitle: ok ? "Done" : "Choose apps for Enforcement Schedule"
    ) {
      #if canImport(FamilyControls)
      if let saved = ScreenTimeManager.shared.loadQuietSelection() {
        quietSelection = saved
      } else {
        quietSelection = FamilyActivitySelection()
      }
      showingQuietPicker = true
      #endif
    }
  }

  private var lockSettingsTile: some View {
    let ok = ScreenTimeManager.shared.selectionSummary().hasRequiredSelection
    return ShortcutTile(
      color: ok ? .pink : .gray,
      systemIcon: ok ? "checkmark.shield" : "gearshape.fill",
      title: "Lock Settings App",
      subtitle: ok ? "Done" : "Pick Settings in Always Locked Apps"
    ) {
      #if canImport(FamilyControls)
      if let saved = ScreenTimeManager.shared.loadRequiredSelection() {
        requiredSelection = saved
      } else {
        requiredSelection = FamilyActivitySelection()
      }
      showingRequiredPicker = true
      #endif
    }
  }

  private func openURL(_ s: String) {
    guard let url = URL(string: s) else { return }
    #if canImport(UIKit)
    UIApplication.shared.open(url)
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
}

#Preview {
  ChildDashboardView()
    .environmentObject(AppModel())
}
#endif

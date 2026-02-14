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

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Setup checklist")
          .font(.system(size: 34, weight: .bold))
          .padding(.top, 2)

        Text("Complete these steps so rules can be enforced.")
          .font(.footnote)
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
            Text("Turn on the automations inside the Shortcuts app. If iOS asks, allow notifications and always allow where possible.")
              .font(.footnote)
              .foregroundStyle(.secondary)
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
    let paired = model.loadHotspotConfig() != nil
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
    let shortcutURL = "https://www.icloud.com/shortcuts/1aef99958a6b4e9ea7e41be31192bab1"
    let hasRun = model.appIntentRunCount > 0
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
    let ok = model.appIntentRunCount >= 2
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
    let ok = model.screenTimeAuthorized && model.shieldingApplied
    return NavigationLink {
      ScreenTimeSetupView()
        .environmentObject(model)
    } label: {
      ShortcutTileCard(
        color: ok ? .pink : .gray,
        systemIcon: "shield",
        title: "Screen Time lock",
        subtitle: ok ? "Done" : "Not set up yet"
      )
    }
    .buttonStyle(.plain)
  }

  private var finishTile: some View {
    ShortcutTile(
      color: .gray,
      systemIcon: "checkmark",
      title: "Finish setup",
      subtitle: "Lock phone into child mode"
    ) {
      showFinishConfirm = true
    }
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

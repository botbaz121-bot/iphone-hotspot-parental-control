import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct ChildDashboardView: View {
  @EnvironmentObject private var model: AppModel
  @State private var showAutomationsInfo = false

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

          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            pairingTile
            shortcutTile
            automationsTile
            screenTimeTile
            finishTile
          }
        }
        .padding(.top, 18)
        .padding(.horizontal, 18)
        .padding(.bottom, 32)
      }
      .sheet(isPresented: $showAutomationsInfo) {
        NavigationStack {
          ScrollView {
            VStack(alignment: .leading, spacing: 12) {
              Text("Turn on the automations inside the Shortcuts app. If iOS asks, allow notifications and always allow where possible.")
                .font(.footnote)
                .foregroundStyle(.secondary)

              Button("Close") {
                showAutomationsInfo = false
              }
              .buttonStyle(.bordered)
              .tint(.secondary)
            }
            .padding(18)
          }
          .navigationTitle("Automations")
          .navigationBarTitleDisplayMode(.inline)
        }
      }
    }
  }

  private var pairingTile: some View {
    let paired = model.loadHotspotConfig() != nil
    return NavigationLink {
      ChildPairView()
        .environmentObject(model)
    } label: {
      ShortcutTile(
        color: paired ? .blue : .gray,
        systemIcon: "qrcode",
        title: paired ? "Edit pairing" : "Start pairing",
        subtitle: paired ? "Paired ✅" : "Not paired yet"
      ) {}
    }
    .buttonStyle(.plain)
  }

  private var shortcutTile: some View {
    let shortcutURL = "https://www.icloud.com/shortcuts/1aef99958a6b4e9ea7e41be31192bab1"
    return ShortcutTile(
      color: .gray,
      systemIcon: "link",
      title: "Install our Shortcut",
      subtitle: "Open link, add Shortcut, run once"
    ) {
      openURL(shortcutURL)
    }
  }

  private var automationsTile: some View {
    ShortcutTile(
      color: .gray,
      systemIcon: "wrench.and.screwdriver",
      title: "Automations",
      subtitle: "Tap to view instructions"
    ) {
      showAutomationsInfo = true
    }
  }

  private var finishTile: some View {
    ShortcutTile(
      color: .gray,
      systemIcon: "checkmark",
      title: "Finish setup",
      subtitle: "Lock phone into child mode"
    ) {
      model.lockChildSetup()
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

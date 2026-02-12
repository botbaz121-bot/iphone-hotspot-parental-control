import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct ChildDashboardView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Dashboard")
              .font(.title.bold())
            Text("Pair this phone, install the Shortcut, and then lock setup screens.")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }

          pairStep
          shortcutStep
          automationsStep
          #if DEBUG
          screenTimeStep
          #else
          screenTimeStepUnavailable
          #endif

          Button {
            model.lockChildSetup()
          } label: {
            Text("Exit child setup")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .padding(.top, 4)

          Text("Tip: After exiting, a parent can unlock these screens if changes are needed.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding()
      }
      .navigationTitle("Dashboard")
    }
  }

  private var pairStep: some View {
    let paired = model.loadHotspotConfig() != nil
    return SetupStepCardView(
      title: "1) Pair",
      subtitle: "Enter the pairing code shown in the parent app.",
      statusText: paired ? "OK" : "SETUP",
      statusColor: paired ? .green : .orange
    ) {
      NavigationLink {
        PairingEntryView()
      } label: {
        Text(paired ? "View / change pairing" : "Enter pairing code")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)

      if paired {
        VStack(alignment: .leading, spacing: 4) {
          Text("Paired as: \(model.childPairedDeviceName ?? "Device")")
            .font(.footnote)
            .foregroundStyle(.secondary)
          Text("Device id: \(model.childPairedDeviceId ?? "—")")
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var shortcutStep: some View {
    let hasRun = model.appIntentRunCount > 0
    return SetupStepCardView(
      title: "2) Install Shortcut",
      subtitle: "Install it, then run it once to verify.",
      statusText: hasRun ? "OK" : "WAITING",
      statusColor: hasRun ? .green : .orange
    ) {
      let shortcutURL = "https://www.icloud.com/shortcuts/1aef99958a6b4e9ea7e41be31192bab1"

      Button {
        openURL(shortcutURL)
      } label: {
        Text("Install Shortcut")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)

      Button {
        copyToPasteboard(shortcutURL)
      } label: {
        Text("Copy Shortcut link")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)

      VStack(alignment: .leading, spacing: 4) {
        Text("Runs observed: \(model.appIntentRunCount)")
          .font(.footnote)
          .foregroundStyle(.secondary)
        if let last = model.lastAppIntentRunAt {
          Text("Last run: \(last.formatted(date: .abbreviated, time: .shortened))")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var automationsStep: some View {
    let ok = model.appIntentRunCount >= 2
    return SetupStepCardView(
      title: "3) Enable automations",
      subtitle: "So the Shortcut can enforce Hotspot OFF and Quiet Time.",
      statusText: ok ? "OK" : "WAITING",
      statusColor: ok ? .green : .orange
    ) {
      Text("Tip: in Shortcuts → Automation, run the Shortcut on a schedule and turn off ‘Ask Before Running’.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }

  private var screenTimeStep: some View {
    let ok = model.screenTimeAuthorized && model.shieldingApplied
    let status: String
    let color: Color
    if ok {
      status = "OK"; color = .green
    } else if model.screenTimeAuthorized {
      status = "INCOMPLETE"; color = .orange
    } else {
      status = "SETUP"; color = .orange
    }

    return SetupStepCardView(
      title: "4) Screen Time lock",
      subtitle: "Reduce tampering (dev builds only).", 
      statusText: status,
      statusColor: color
    ) {
      NavigationLink {
        ScreenTimeSetupView()
      } label: {
        Text("Open Screen Time setup")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)

      VStack(alignment: .leading, spacing: 4) {
        Text("Authorized: \(model.screenTimeAuthorized ? "Yes" : "No")")
          .font(.footnote)
          .foregroundStyle(.secondary)
        Text("Shielding applied: \(model.shieldingApplied ? "Yes" : "No")")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var screenTimeStepUnavailable: some View {
    SetupStepCardView(
      title: "4) Screen Time lock",
      subtitle: "Not available in TestFlight builds yet.",
      statusText: "COMING SOON",
      statusColor: .orange
    ) {
      Text("We’ll add this once Apple allows the required entitlement in shipping builds.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }

  private func openURL(_ s: String) {
    guard let url = URL(string: s) else { return }
    #if canImport(UIKit)
    UIApplication.shared.open(url)
    #endif
  }

  private func copyToPasteboard(_ s: String) {
    #if canImport(UIKit)
    UIPasteboard.general.string = s
    #endif
  }
}

#Preview {
  ChildDashboardView()
    .environmentObject(AppModel())
}
#endif

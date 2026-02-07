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
            Text("Child setup")
              .font(.title.bold())
            Text("Complete the checklist, then lock the setup screens.")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }

          pairStep
          shortcutStep
          automationsStep
          screenTimeStep

          Button {
            model.lockChildSetup()
          } label: {
            Text("Finish setup")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .padding(.top, 4)
        }
        .padding()
      }
      .navigationTitle("Checklist")
    }
  }

  private var pairStep: some View {
    let paired = model.loadHotspotConfig() != nil
    return SetupStepCardView(
      title: "1) Pair device",
      subtitle: "Enter a pairing code from the backend.",
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
      title: "2) Install our Shortcut",
      subtitle: "Install the Shortcut, then run it once.",
      statusText: hasRun ? "OK" : "WAITING",
      statusColor: hasRun ? .green : .orange
    ) {
      Button {
        openURL("https://www.icloud.com/shortcuts/")
      } label: {
        Text("Open Shortcuts Gallery")
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
      title: "3) Automations",
      subtitle: "We can’t detect your automations directly; multiple runs are a confidence signal.",
      statusText: ok ? "OK" : "WAITING",
      statusColor: ok ? .green : .orange
    ) {
      Text("Tip: Create a Personal Automation that runs the Shortcut frequently, with Ask Before Running disabled.")
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
      subtitle: "Authorize Family Controls and shield Shortcuts/Settings to reduce tampering.",
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

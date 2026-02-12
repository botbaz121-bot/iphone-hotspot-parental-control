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
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        pairDeviceCard
        shortcutCard
        automationsCard
        screenTimeCard

        Button {
          model.lockChildSetup()
        } label: {
          Label("Finish setup", systemImage: "checkmark")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .padding(.top, 4)
      }
      .padding(.top, 22)
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
  }

  private var pairDeviceCard: some View {
    let paired = model.loadHotspotConfig() != nil
    return SetupStepCardView(
      title: "1) Pair device",
      subtitle: paired ? "Paired." : "Not paired yet.",
      statusText: paired ? "OK" : "Awaiting",
      statusColor: paired ? .green : .orange
    ) {
      NavigationLink {
        PairingEntryView()
      } label: {
        Label(paired ? "View pairing" : "Start pairing", systemImage: "qrcode")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(.blue)
    }
  }

  private var shortcutCard: some View {
    let shortcutURL = "https://www.icloud.com/shortcuts/1aef99958a6b4e9ea7e41be31192bab1"
    let hasRun = model.appIntentRunCount > 0

    return VStack(alignment: .leading, spacing: 10) {
      SetupStepCardView(
        title: "2) Install our Shortcut",
        subtitle: "",
        statusText: "",
        statusColor: .secondary
      ) {
        Button {
          openURL(shortcutURL)
        } label: {
          Label("Open Shortcut link", systemImage: "link")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
      }

      SetupStepCardView(
        title: "Initial run",
        subtitle: "Open the Shortcut and tap ▶ to run once. If iOS prompts, choose “Always Allow” where possible.",
        statusText: "",
        statusColor: .secondary
      ) {
        EmptyView()
      }

      SetupStepCardView(
        title: "Shortcut runs",
        subtitle: hasRun ? "Detected" : "Awaiting first run",
        statusText: hasRun ? "OK" : "Awaiting",
        statusColor: hasRun ? .green : .orange
      ) {
        EmptyView()
      }
    }
  }

  private var automationsCard: some View {
    let ok = model.appIntentRunCount >= 2
    return SetupStepCardView(
      title: "3) Automations",
      subtitle: "",
      statusText: ok ? "OK" : "Awaiting",
      statusColor: ok ? .green : .orange
    ) {
      Text("Automation runs")
        .font(.subheadline.weight(.semibold))
      Text(ok ? "Detected multiple runs" : "Awaiting multiple runs")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }

  private var screenTimeCard: some View {
    #if DEBUG
    let ok = model.screenTimeAuthorized && model.shieldingApplied
    let statusText = ok ? "OK" : "Awaiting"
    let statusColor: Color = ok ? .green : .orange

    return SetupStepCardView(
      title: "4) Screen Time lock",
      subtitle: "",
      statusText: statusText,
      statusColor: statusColor
    ) {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("Screen Time authorization")
              .font(.subheadline.weight(.semibold))
            Text(model.screenTimeAuthorized ? "FamilyControls permission granted" : "Not granted")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Text(model.screenTimeAuthorized ? "OK" : "Awaiting")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((model.screenTimeAuthorized ? Color.green : Color.orange).opacity(0.15))
            .foregroundStyle(model.screenTimeAuthorized ? .green : .orange)
            .clipShape(Capsule())
        }

        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("Shielding applied")
              .font(.subheadline.weight(.semibold))
            Text(model.shieldingApplied ? "Shortcuts/Settings selected for shielding" : "Not applied")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Text(model.shieldingApplied ? "OK" : "Awaiting")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((model.shieldingApplied ? Color.green : Color.orange).opacity(0.15))
            .foregroundStyle(model.shieldingApplied ? .green : .orange)
            .clipShape(Capsule())
        }

        NavigationLink {
          ScreenTimeSetupView()
        } label: {
          Label("Select apps to shield", systemImage: "app")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
      }
    }
    #else
    return SetupStepCardView(
      title: "4) Screen Time lock",
      subtitle: "",
      statusText: "Awaiting",
      statusColor: .orange
    ) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Not available in TestFlight builds yet.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    #endif
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

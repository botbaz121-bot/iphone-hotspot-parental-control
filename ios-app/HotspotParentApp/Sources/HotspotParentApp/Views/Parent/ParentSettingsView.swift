import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentSettingsView: View {
  @EnvironmentObject private var model: AppModel
  @StateObject private var iap = IAPManager.shared

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("Settings")
          .font(.system(size: 34, weight: .bold))
          .padding(.top, 2)

        SettingsGroup("Mode") {
          SettingsToggleRow(
            systemIcon: "gearshape",
            title: "This is a child phone",
            subtitle: "Show the child setup experience on this device",
            isOn: Binding(
              get: { model.appMode == .childSetup },
              set: { isOn in
                model.setAppMode(isOn ? .childSetup : .parent)
              }
            )
          )
        }

        SettingsGroup("Account") {
          SettingsRow(
            systemIcon: "person",
            title: "Signed in",
            subtitle: nil,
            rightText: model.isSignedIn ? "Yes" : "No",
            showsChevron: false,
            action: nil
          )
        }

        Button(role: .destructive) {
          model.signOut()
          model.setAppMode(nil)
        } label: {
          Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .disabled(!model.isSignedIn)

        SettingsGroup("In-app purchase") {
          SettingsRow(
            systemIcon: "checkmark",
            title: model.adsRemoved ? "Ads removed" : "Remove ads",
            subtitle: model.adsRemoved ? "Purchased ✅" : "Remove ads from the parent experience",
            showsChevron: true,
            action: {
              Task {
                await iap.purchaseRemoveAds()
                await MainActor.run { model.adsRemoved = iap.adsRemoved }
              }
            }
          )
        }

        Text(versionLine)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.top, 8)

      }
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
  }

  private var versionLine: String {
    let info = Bundle.main.infoDictionary
    let version = (info?["CFBundleShortVersionString"] as? String) ?? "?"
    let build = (info?["CFBundleVersion"] as? String) ?? "?"
    return "Version \(version) (\(build))"
  }
}

#Preview {
  ParentSettingsView()
    .environmentObject(AppModel())
}
#endif

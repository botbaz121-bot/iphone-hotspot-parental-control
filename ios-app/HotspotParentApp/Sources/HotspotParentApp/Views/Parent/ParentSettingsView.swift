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

        SettingsGroup("Debug") {
          SettingsRow(
            systemIcon: "ladybug",
            title: "Static prototype",
            subtitle: "No server, no push, no background tasks",
            showsChevron: false,
            action: nil
          )
        }
      }
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
  }
}

#Preview {
  ParentSettingsView()
    .environmentObject(AppModel())
}
#endif

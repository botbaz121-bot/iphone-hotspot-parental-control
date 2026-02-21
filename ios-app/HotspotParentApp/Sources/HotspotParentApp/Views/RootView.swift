import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct RootView: View {
  @StateObject private var model = AppModel()
  @Environment(\.scenePhase) private var scenePhase

  public init() {}

  public var body: some View {
    content
      .environmentObject(model)
      .onReceive(NotificationCenter.default.publisher(for: PushEventNames.didRegisterDeviceToken)) { note in
        let token = (note.userInfo?["token"] as? String) ?? ""
        Task { await model.registerParentPushTokenIfPossible(token) }
      }
      .onReceive(NotificationCenter.default.publisher(for: PushEventNames.didReceiveExtraTimeRequest)) { note in
        guard model.parentNotifyExtraTimeRequests else { return }
        guard let deviceId = note.userInfo?["deviceId"] as? String, !deviceId.isEmpty else { return }
        let requestIdRaw = note.userInfo?["requestId"] as? String
        let requestId = (requestIdRaw?.isEmpty ?? true) ? nil : requestIdRaw
        let minutes = (note.userInfo?["requestedMinutes"] as? Int) ?? 15
        model.setExtraTimePrefill(deviceId: deviceId, minutes: minutes, requestId: requestId)
        model.startParentFlow()
      }
      .onChange(of: scenePhase) { phase in
        if phase == .active {
          model.syncFromSharedDefaults()
          consumePendingExtraTimePushIfPresent()
          if model.isSignedIn, model.appMode == nil {
            model.setAppMode(.parent)
          }
          Task {
            await model.reconcileScreenTimeProtection()
            await model.syncPushRegistrationIfNeeded()
          }
        }
      }
      .onChange(of: model.isSignedIn) { signedIn in
        if signedIn, model.appMode == nil {
          model.setAppMode(.parent)
        }
      }
      .task {
        consumePendingExtraTimePushIfPresent()
        if model.isSignedIn, model.appMode == nil {
          model.setAppMode(.parent)
        }
        await model.reconcileScreenTimeProtection()
        await model.syncPushRegistrationIfNeeded()
      }
  }

  private func consumePendingExtraTimePushIfPresent() {
    guard let deviceId = AppDefaults.pendingExtraTimeDeviceId, !deviceId.isEmpty else { return }
    let requestId = AppDefaults.pendingExtraTimeRequestId
    let minutes = AppDefaults.pendingExtraTimeMinutes
    model.setExtraTimePrefill(deviceId: deviceId, minutes: minutes, requestId: requestId)
    model.startParentFlow()
    AppDefaults.clearPendingExtraTimeRequest()
  }

  @ViewBuilder
  private var content: some View {
    NavigationStack {
      ZStack {
        // Background gradient-ish feel (approximate the mock's dark vignette)
        LinearGradient(
          colors: [Color.black, Color.black.opacity(0.85), Color.black],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        Group {
          if model.appMode == nil {
            LandingView()
          } else {
            switch model.appMode {
              case .some(.parent):
                // Onboarding screens removed in the latest mock: go straight to sign-in/dashboard.
                if !model.isSignedIn {
                  ParentSignInView()
                } else {
                  ParentTabView()
                }

              case .some(.childSetup):
                // Onboarding screens removed in the latest mock: go straight to setup dashboard.
                if model.childIsLocked {
                  if model.childUnlockRequested {
                    ChildUnlockView()
                  } else {
                    ChildLockedView()
                  }
                } else {
                  ChildTabView()
                }

              case .none:
                LandingView()
            }
          }
        }
        .environmentObject(model)
      }
    }
  }
}

#Preview {
  RootView()
}
#endif

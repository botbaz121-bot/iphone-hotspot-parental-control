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
      .onChange(of: scenePhase) { phase in
        if phase == .active {
          model.syncFromSharedDefaults()
        }
      }
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

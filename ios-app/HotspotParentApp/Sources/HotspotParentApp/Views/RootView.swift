import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct RootView: View {
  @StateObject private var model = AppModel()

  public init() {}

  public var body: some View {
    content
      .environmentObject(model)
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
                if !model.onboardingCompleted {
                  ParentOnboardingView()
                } else {
                  ParentTabView()
                }

              case .some(.childSetup):
                if !model.onboardingCompleted {
                  ChildWelcomeView()
                } else if model.childIsLocked && !model.childUnlockRequested {
                  ChildLockedView()
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

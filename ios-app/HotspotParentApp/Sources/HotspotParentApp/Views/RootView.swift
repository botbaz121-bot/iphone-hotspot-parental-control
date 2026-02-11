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
    if !model.onboardingCompleted {
      OnboardingView()
    } else if model.isSignedIn {
      // v1B: Parent/Child modes share the same binary.
      switch model.appMode {
        case .some(.childSetup):
          ChildTabView()
        case .some(.parent), .none:
          ParentTabView()
      }
    } else {
      NavigationStack {
        SignInView()
      }
    }
  }
}

#Preview {
  RootView()
}
#endif

import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct RootView: View {
  @StateObject private var model = AppModel()

  public init() {}

  @ViewBuilder
  public var body: some View {
    content
  }

  @ViewBuilder
  private var content: some View {
    if !model.onboardingCompleted {
      OnboardingView()
        .environmentObject(model)
    } else if model.isSignedIn {
      // v1B: Parent/Child modes share the same binary.
      switch model.appMode {
        case .child:
          ChildTabView()
        case .parent, .none:
          ParentTabView()
      }
      .environmentObject(model)
    } else {
      NavigationStack {
        SignInView()
          .environmentObject(model)
      }
    }
  }
}

#Preview {
  RootView()
}
#endif

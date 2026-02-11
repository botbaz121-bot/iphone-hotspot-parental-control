import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct RootView: View {
  @StateObject private var model = AppModel()

  public init() {}

  public var body: some View {
    if !model.onboardingCompleted {
      OnboardingView()
        .environmentObject(model)
    } else if model.isSignedIn {
      // v1B: Parent/Child modes share the same binary.
      Group {
        switch model.appMode {
          case .child:
            ChildTabView()
          case .parent, .none:
            ParentTabView()
        }
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

import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct RootView: View {
  @StateObject private var model = AppModel()

  public init() {}

  public var body: some View {
    Group {
      if !model.onboardingCompleted {
        OnboardingView()
          .environmentObject(model)
      } else if model.isSignedIn {
        TabView {
          DashboardView()
            .tabItem { Label("Dashboard", systemImage: "house") }

          EnrollmentView()
            .tabItem { Label("Enroll", systemImage: "qrcode") }

          SettingsView()
            .tabItem { Label("Settings", systemImage: "gear") }
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
}

#Preview {
  RootView()
}
#endif

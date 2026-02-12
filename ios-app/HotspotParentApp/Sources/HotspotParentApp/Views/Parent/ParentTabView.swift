import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentTabView: View {
  @EnvironmentObject private var model: AppModel
  @State private var tab: Tab = .dashboard

  public init() {}

  public var body: some View {
    TabView(selection: $tab) {
      LandingView()
        .tag(Tab.home)
        .tabItem {
          // Match mock: icon-only "home"
          Image(systemName: "house")
        }

      ParentDashboardView()
        .tag(Tab.dashboard)
        .tabItem {
          Text("Dashboard")
        }

      ParentSettingsView()
        .tag(Tab.settings)
        .tabItem {
          Text("Settings")
        }
    }
    .accentColor(.blue)
  }

  private enum Tab {
    case home
    case dashboard
    case settings
  }
}

#Preview {
  ParentTabView()
    .environmentObject(AppModel())
}
#endif

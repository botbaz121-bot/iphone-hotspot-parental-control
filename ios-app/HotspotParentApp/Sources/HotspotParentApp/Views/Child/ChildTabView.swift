import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ChildTabView: View {
  @EnvironmentObject private var model: AppModel
  @State private var tab: Tab = .dashboard

  public init() {}

  public var body: some View {
    TabView(selection: $tab) {
      ChildLockedView()
        .tag(Tab.home)
        .tabItem {
          Image(systemName: "house")
        }

      ChildDashboardView()
        .tag(Tab.dashboard)
        .tabItem {
          Text("Dashboard")
        }

      ChildSettingsView()
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
  ChildTabView()
    .environmentObject(AppModel())
}
#endif

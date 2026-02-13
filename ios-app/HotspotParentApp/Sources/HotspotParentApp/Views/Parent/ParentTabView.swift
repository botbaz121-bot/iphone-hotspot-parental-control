import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentTabView: View {
  @EnvironmentObject private var model: AppModel
  @State private var tab: Tab = .dashboard

  public init() {}

  public var body: some View {
    TabView(selection: $tab) {
      ParentDashboardView()
        .tag(Tab.dashboard)
        .tabItem {
          Label("Dashboard", systemImage: "house")
        }

      ParentSettingsView()
        .tag(Tab.settings)
        .tabItem {
          Label("Settings", systemImage: "gearshape")
        }
    }
    .accentColor(.blue)
  }

  private enum Tab {
    case dashboard
    case settings
  }
}

#Preview {
  ParentTabView()
    .environmentObject(AppModel())
}
#endif

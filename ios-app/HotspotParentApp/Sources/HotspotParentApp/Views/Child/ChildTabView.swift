import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ChildTabView: View {
  @EnvironmentObject private var model: AppModel
  @State private var tab: Tab = .dashboard

  public init() {}

  public var body: some View {
    TabView(selection: $tab) {
      ChildDashboardView()
        .tag(Tab.dashboard)
        .tabItem {
          Label("Dashboard", systemImage: "house")
        }

      ChildSettingsView()
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
  ChildTabView()
    .environmentObject(AppModel())
}
#endif

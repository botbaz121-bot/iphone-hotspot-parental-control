import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ChildTabView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    TabView {
      ChildLockedView()
        .tabItem {
          Label("Home", systemImage: "house")
        }

      ChildDashboardView()
        .tabItem {
          Label("Dashboard", systemImage: "rectangle.3.group")
        }

      ChildSettingsView()
        .tabItem {
          Label("Settings", systemImage: "gear")
        }
    }
    .accentColor(.blue)
  }
}

#Preview {
  ChildTabView()
    .environmentObject(AppModel())
}
#endif

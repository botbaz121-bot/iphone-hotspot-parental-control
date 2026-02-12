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
          Image(systemName: "house")
        }

      ChildDashboardView()
        .tabItem {
          Text("Dashboard")
        }

      ChildSettingsView()
        .tabItem {
          Text("Settings")
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

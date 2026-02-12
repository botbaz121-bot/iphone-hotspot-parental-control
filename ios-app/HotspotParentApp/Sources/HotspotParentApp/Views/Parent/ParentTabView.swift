import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentTabView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    TabView {
      ParentHomeView()
        .tabItem {
          Image(systemName: "house")
        }

      ParentDashboardView()
        .tabItem {
          Text("Dashboard")
        }

      ParentSettingsView()
        .tabItem {
          Text("Settings")
        }
    }
    .accentColor(.blue)
  }
}

#Preview {
  ParentTabView()
    .environmentObject(AppModel())
}
#endif

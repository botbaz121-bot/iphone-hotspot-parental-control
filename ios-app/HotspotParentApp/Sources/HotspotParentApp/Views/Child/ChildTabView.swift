import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ChildTabView: View {
  public init() {}

  public var body: some View {
    TabView {
      ChildDashboardView()
        .tabItem { Label("Checklist", systemImage: "checklist") }

      ChildSettingsView()
        .tabItem { Label("Settings", systemImage: "gear") }
    }
  }
}

#Preview {
  ChildTabView()
    .environmentObject(AppModel())
}
#endif

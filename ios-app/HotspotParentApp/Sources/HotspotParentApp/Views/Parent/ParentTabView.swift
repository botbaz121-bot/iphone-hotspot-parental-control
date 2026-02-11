import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentTabView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    TabView {
      ParentDashboardView()
        .tabItem { Label("Dashboard", systemImage: "rectangle.3.group") }

      ParentSettingsView()
        .tabItem { Label("Settings", systemImage: "gear") }
    }
    .overlay(alignment: .top) {
      // Keep mode switch quickly accessible in v1A.
      VStack(spacing: 0) {
        AppModeSwitcherView()
          .padding(.horizontal)
          .padding(.top, 8)
        Divider().opacity(0.2)
      }
      .background(.ultraThinMaterial)
    }
    .onChange(of: model.appMode) { newValue in
      // iOS 16-compatible onChange signature.
      // If switching away, leave tab view promptly.
      if newValue != .parent { }
    }
  }
}

#Preview {
  ParentTabView()
    .environmentObject(AppModel())
}
#endif

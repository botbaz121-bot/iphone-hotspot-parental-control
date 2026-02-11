import Foundation

#if DEBUG
#if canImport(SwiftUI)
import SwiftUI

// Legacy v1A settings (kept for reference). Excluded from Release/TestFlight builds.
public struct SettingsView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    Text("Legacy SettingsView (DEBUG only)")
  }
}

#Preview {
  SettingsView()
    .environmentObject(AppModel())
}
#endif
#endif

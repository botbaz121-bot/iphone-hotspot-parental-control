import Foundation

#if DEBUG
#if canImport(SwiftUI)
import SwiftUI

// Legacy v1A dashboard (kept for reference). Excluded from Release/TestFlight builds.
public struct DashboardView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    Text("Legacy DashboardView (DEBUG only)")
  }
}

#Preview {
  DashboardView()
    .environmentObject(AppModel())
}
#endif
#endif

import Foundation

#if canImport(SwiftUI)
import SwiftUI

/// Legacy entry-point view used by the xcodegen wrapper target.
///
/// This now forwards to `RootView`, which contains the MVP UI.
public struct AppShellView: View {
  public init() {}

  public var body: some View {
    RootView()
  }
}
#endif

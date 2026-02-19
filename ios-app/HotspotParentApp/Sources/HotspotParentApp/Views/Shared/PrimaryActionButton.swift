import Foundation

#if canImport(SwiftUI)
import SwiftUI

public extension View {
  func primaryActionButton(tint: Color = .blue) -> some View {
    self
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .tint(tint)
  }
}
#endif

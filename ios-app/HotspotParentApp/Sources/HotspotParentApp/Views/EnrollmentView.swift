import Foundation

#if DEBUG
#if canImport(SwiftUI)
import SwiftUI

// Legacy v1A enroll screen (kept for reference). Excluded from Release/TestFlight builds.
public struct EnrollmentView: View {
  public init() {}

  public var body: some View {
    Text("Legacy EnrollmentView (DEBUG only)")
  }
}

#Preview {
  EnrollmentView()
}
#endif
#endif

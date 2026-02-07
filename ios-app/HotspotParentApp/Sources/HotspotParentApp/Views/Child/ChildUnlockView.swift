import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ChildUnlockView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss

  @State private var status: String?

  public init() {}

  public var body: some View {
    VStack(spacing: 16) {
      Spacer()

      Text("Parent unlock")
        .font(.title.bold())

      Text("In v1A this is a stub. In v1B, require real Sign in with Apple session.")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)

      Button("Sign in (stub)") {
        let userID = "apple-stub-\(UUID().uuidString.prefix(8))"
        model.signInStub(userID: userID)
        model.unlockChildSetup()
        dismiss()
      }
      .buttonStyle(.borderedProminent)
      .padding(.horizontal)

      if let status {
        Text(status)
          .font(.footnote)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
      }

      Spacer()
    }
    .padding(.vertical)
    .navigationTitle("Unlock")
  }
}

#Preview {
  NavigationStack {
    ChildUnlockView()
      .environmentObject(AppModel())
  }
}
#endif

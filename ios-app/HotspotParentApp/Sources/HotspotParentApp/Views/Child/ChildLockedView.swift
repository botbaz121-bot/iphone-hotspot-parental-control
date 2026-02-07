import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ChildLockedView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Spacer()

        Image(systemName: "lock.fill")
          .font(.system(size: 56))
          .foregroundStyle(.secondary)

        Text("Setup complete")
          .font(.title.bold())

        Text("Setup screens are locked on this phone. A parent can unlock to make changes.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)

        NavigationLink {
          ChildUnlockView()
        } label: {
          Text("Unlock")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)

        Spacer()
      }
      .navigationTitle("Locked")
    }
  }
}

#Preview {
  ChildLockedView()
    .environmentObject(AppModel())
}
#endif

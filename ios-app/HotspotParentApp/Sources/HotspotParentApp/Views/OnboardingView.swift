import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct OnboardingView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    VStack(spacing: 16) {
      Spacer()

      VStack(spacing: 8) {
        Text("Hotspot Parent")
          .font(.largeTitle.bold())

        Text("MVP setup")
          .font(.headline)
          .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: 10) {
        Text("What this build does")
          .font(.headline)

        Text("• Generates an enrollment token + QR")
        Text("• Lets you configure policy: Hotspot OFF")
        Text("• (Optional) Talks to the backend for admin pairing")

        Text("Note: iOS cannot directly toggle Personal Hotspot via public APIs. The enforcement approach is Shortcut/MDM-based (per our earlier plan).")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .padding(.top, 6)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
      .background(.thinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .padding(.horizontal)

      Button("Continue") {
        model.completeOnboarding()
      }
      .buttonStyle(.borderedProminent)
      .padding(.top, 8)

      Spacer()
    }
    .padding(.vertical)
    .navigationTitle("Welcome")
  }
}

#Preview {
  NavigationStack {
    OnboardingView()
      .environmentObject(AppModel())
  }
}
#endif

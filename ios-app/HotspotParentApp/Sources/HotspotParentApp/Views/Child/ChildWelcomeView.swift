import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ChildWelcomeView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    VStack(spacing: 16) {
      Spacer()

      VStack(spacing: 8) {
        Text("Welcome")
          .font(.largeTitle.bold())

        Text("Pair this phone, install the Shortcut, and lock the right settings so rules can be enforced.")
          .font(.headline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      VStack(alignment: .leading, spacing: 10) {
        Text("What you’ll do")
          .font(.headline)

        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
          featureTile(icon: "qrcode.viewfinder", title: "Pair", sub: "Scan a QR from the parent app to link this phone.")
          featureTile(icon: "clock", title: "Enable automations", sub: "So the Shortcut can enforce Hotspot OFF and Quiet Time.")
          featureTile(icon: "exclamationmark.shield", title: "Stay protected", sub: "If this stops running, the parent will see a tamper warning.")
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
      .background(.ultraThinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .padding(.horizontal)

      Text("Tip")
        .font(.headline)
      Text("When you’re done, use Exit child setup to hand the phone back to the parent.")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
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

  private func featureTile(icon: String, title: String, sub: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.title2.weight(.medium))
        .foregroundStyle(.blue)
      Text(title)
        .font(.headline.weight(.semibold))
      Text(sub)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(.ultraThinMaterial.opacity(0.5))
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

#Preview {
  NavigationStack {
    ChildWelcomeView()
      .environmentObject(AppModel())
  }
}
#endif

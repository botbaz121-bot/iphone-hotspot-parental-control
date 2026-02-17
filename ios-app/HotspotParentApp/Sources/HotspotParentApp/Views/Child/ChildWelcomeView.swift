import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ChildWelcomeView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        headerCard
        whatYoullDoCard
        tipCard
      }
      .padding(.top, 22)
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
  }

  private var headerCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Welcome")
            .font(.largeTitle.bold())

          Text("Pair this phone, install the Shortcut, and lock the right settings so rules can be enforced.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Text("Child")
          .font(.caption.weight(.medium))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.primary.opacity(0.08))
          .clipShape(RoundedRectangle(cornerRadius: 999))
      }

      Button {
        model.startChildFlow()
        model.completeOnboarding()
      } label: {
        Label("Continue", systemImage: "arrow.right")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(18)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  private var whatYoullDoCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("What you’ll do")
        .font(.headline)

      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
        featureTile(icon: "qrcode.viewfinder", title: "Pair", sub: "Scan a QR from the parent app to link this phone.")
        featureTile(icon: "checklist", title: "Enable\nautomations", sub: "So the Shortcut can enforce Hotspot OFF and Quiet Time.")
        featureTile(icon: "exclamationmark.triangle", title: "Stay\nprotected", sub: "If this stops running, the parent will see a tamper warning.")
      }
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  private var tipCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Tip")
        .font(.headline)
      Text("When you’re done, use Exit child setup to hand the phone back to the parent.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  private func featureTile(icon: String, title: String, sub: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Image(systemName: icon)
        .font(.title2.weight(.medium))
        .foregroundStyle(.secondary)

      Text(title)
        .font(.subheadline.weight(.semibold))

      Text(sub)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(.ultraThinMaterial.opacity(0.5))
    .clipShape(RoundedRectangle(cornerRadius: 18))
  }
}

#Preview {
  NavigationStack {
    ChildWelcomeView()
      .environmentObject(AppModel())
  }
}
#endif

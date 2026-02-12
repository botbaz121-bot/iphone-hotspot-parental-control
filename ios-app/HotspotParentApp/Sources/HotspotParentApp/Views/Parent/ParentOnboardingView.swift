import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentOnboardingView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        headerCard
        featureCard
        constraintsCard
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
          Text("Set rules, guide setup on the child phone, and get a simple tamper warning if it stops running.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Text("Parent")
          .font(.caption.weight(.medium))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.primary.opacity(0.08))
          .clipShape(RoundedRectangle(cornerRadius: 999))
      }

      Button {
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

  private var featureCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("What this can do")
        .font(.headline)

      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
        featureTile(icon: "slider.horizontal.3", title: "Per-device\nrules", sub: "Hotspot OFF and Quiet Time per child device.")
        featureTile(icon: "checkmark.circle", title: "Guided\nsetup", sub: "Pair the child phone, install the Shortcut, and apply Screen Time shielding.")
        featureTile(icon: "exclamationmark.triangle", title: "Tamper\nwarning", sub: "Warn when the phone hasn’t been seen recently (likely disabled).")
      }
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  private var constraintsCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Constraints")
        .font(.headline)
      Text("iOS apps can’t reliably toggle Personal Hotspot directly; enforcement is performed by the Shortcut on the device.")
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
  ParentOnboardingView()
    .environmentObject(AppModel())
}
#endif

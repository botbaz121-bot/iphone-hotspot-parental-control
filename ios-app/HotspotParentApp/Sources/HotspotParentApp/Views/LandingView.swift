import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct LandingView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(spacing: 14) {
        welcomeCard

        adCard

        infoCard

        resetCard
      }
      .padding(.top, 22)
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
  }

  private var welcomeCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("SpotCheck")
            .font(.largeTitle.bold())
          Text("High‑fidelity prototype to design parent +\nchild setup flows (no iOS build).")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Text("Prototype")
          .font(.caption.weight(.medium))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.primary.opacity(0.08))
          .clipShape(RoundedRectangle(cornerRadius: 999))
      }

      Button {
        model.startParentFlow()
      } label: {
        Label("Parent phone", systemImage: "person")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)

      Button {
        model.startChildFlow()
      } label: {
        Label("Set up child phone", systemImage: "clock")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
    }
    .padding(18)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  private var adCard: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text("Ad")
          .font(.caption.weight(.medium))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.primary.opacity(0.08))
          .clipShape(RoundedRectangle(cornerRadius: 999))
        Spacer()
      }

      Text("SpeedifyPress — Make WordPress Fast")
        .font(.headline)

      Text("Real‑world performance audits + fixes. (Prototype placeholder)")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  private var infoCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("What this models")
        .font(.headline)

      Text("Shortcuts‑only enforcement (hotspot off + password rotation), device activity signals, and a guided child-phone checklist.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  private var resetCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Reset mockup")
        .font(.headline)

      Button(role: .destructive) {
        model.resetLocalData()
      } label: {
        Label("Clear local state", systemImage: "trash")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .tint(.red)

      Text("Clears localStorage only (no server).")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }
}

#Preview {
  LandingView()
    .environmentObject(AppModel())
}
#endif

import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentHomeView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
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

            if model.isSignedIn {
              Button {
                // Signed-in users go straight to Dashboard.
                // Tab bar exists; this is just a nudge.
              } label: {
                Text("You’re signed in")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.bordered)
              .disabled(true)
            } else {
              NavigationLink {
                SignInView()
                  .environmentObject(model)
              } label: {
                Label("Continue", systemImage: "arrow.right")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.borderedProminent)
            }
          }
          .padding()
          .background(.ultraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 22))

          VStack(alignment: .leading, spacing: 10) {
            Text("What this can do")
              .font(.headline)

            featureRow(icon: "slider.horizontal.3", title: "Per-device rules", sub: "Hotspot OFF and Quiet Time per child device.")
            featureRow(icon: "checklist", title: "Guided setup", sub: "Pair the child phone and install the Shortcut.")
            featureRow(icon: "exclamationmark.triangle", title: "Tamper warning", sub: "Warn when the phone hasn’t been seen recently.")
          }
          .padding()
          .background(Color.primary.opacity(0.06))
          .clipShape(RoundedRectangle(cornerRadius: 18))

          VStack(alignment: .leading, spacing: 10) {
            Text("Constraints")
              .font(.headline)
            Text("iOS apps can’t reliably toggle Personal Hotspot directly; enforcement is performed by the Shortcut on the device.")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          .padding()
          .background(Color.primary.opacity(0.06))
          .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .padding()
      }
      .navigationTitle("Home")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          AppModeSwitcherView()
        }
      }
    }
  }

  private func featureRow(icon: String, title: String, sub: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .frame(width: 22)
        .foregroundStyle(.blue)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.subheadline.weight(.semibold))
        Text(sub)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 4)
  }
}

#Preview {
  ParentHomeView()
    .environmentObject(AppModel())
}
#endif

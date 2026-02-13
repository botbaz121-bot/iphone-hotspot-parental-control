import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

public struct LandingView: View {
  @EnvironmentObject private var model: AppModel

  @State private var status: String?
  @State private var showError = false

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("SpotCheck")
          .font(.system(size: 34, weight: .bold))
          .padding(.top, 2)

        Text("Choose device type")
          .font(.footnote)
          .foregroundStyle(.secondary)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
          ShortcutTile(
            color: .blue,
            systemIcon: "person",
            title: "Parent phone",
            subtitle: nil
          ) {
            Task { await startParent() }
          }

          ShortcutTile(
            color: .pink,
            systemIcon: "iphone",
            title: "Set up child\nphone",
            subtitle: nil
          ) {
            model.startChildFlow()
          }
        }

        SettingsGroup("What this models") {
          SettingsRow(
            systemIcon: "bolt",
            title: "Shortcuts-only enforcement",
            subtitle: "Hotspot off + password rotation (via Shortcut)",
            showsChevron: false,
            action: nil
          )
          SettingsDivider()
          SettingsRow(
            systemIcon: "checklist",
            title: "Guided setup",
            subtitle: "A simple child-phone checklist",
            showsChevron: false,
            action: nil
          )
        }

        Button(role: .destructive) {
          model.resetLocalData()
        } label: {
          Label("Clear local state", systemImage: "trash")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .padding(.top, 8)
      }
      .padding(.top, 18)
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
    .alert("Sign in failed", isPresented: $showError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(status ?? "Unknown error")
    }
  }

  @MainActor
  private func startParent() async {
    status = nil

    // If already signed in, just enter parent mode.
    if model.isSignedIn {
      model.setAppMode(.parent)
      return
    }

    #if canImport(AuthenticationServices)
    do {
      let coord = AppleSignInCoordinator()
      let creds = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<AppleSignInCoordinator.AppleCredentials, Error>) in
        coord.start { result in cont.resume(with: result) }
      }

      try await model.signInWithApple(
        identityToken: creds.identityToken,
        appleUserID: creds.userID,
        email: creds.email,
        fullName: creds.fullName
      )

      model.setAppMode(.parent)
    } catch {
      status = String(describing: error)
      showError = true
    }
    #else
    status = "Sign in with Apple is unavailable on this build target."
    showError = true
    #endif
  }
}

#Preview {
  LandingView()
    .environmentObject(AppModel())
}
#endif

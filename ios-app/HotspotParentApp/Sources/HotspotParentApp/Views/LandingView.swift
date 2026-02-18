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
          .font(.system(size: 14))
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
            title: "Child\nphone",
            subtitle: nil
          ) {
            model.startChildFlow()
          }
        }

      }
      .padding(.top, 18)
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
    .alert("Sign in required", isPresented: $showError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(signInMessage(for: status))
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

  private func signInMessage(for raw: String?) -> String {
    let base = "To setup a parent phone, we need to know who you are. This will allow you to unlock paired child phones and enables locking apps on the child device via Apple Screen Time / Family Controls."

    let detail: String = {
      guard let raw, !raw.isEmpty else { return "" }
      // Common case: user cancelled.
      if raw.contains("AuthorizationError") && raw.contains("Code=1001") {
        return "\n\nIt looks like you cancelled the Sign in with Apple prompt."
      }
      return "\n\nTechnical details: \(raw)"
    }()

    return base + detail
  }
}

#Preview {
  LandingView()
    .environmentObject(AppModel())
}
#endif

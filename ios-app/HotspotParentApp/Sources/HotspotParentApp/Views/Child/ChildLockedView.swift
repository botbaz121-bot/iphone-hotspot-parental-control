import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

public struct ChildLockedView: View {
  @EnvironmentObject private var model: AppModel
  @State private var signInError: String?
  @State private var showError = false

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        headerCard
      }
      .padding(.top, 22)
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
    .alert("Unlock failed", isPresented: $showError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(signInError ?? "Unknown error")
    }
  }

  private var headerCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Setup complete")
            .font(.largeTitle.bold())
          Text("This screen stays on. To change anything, the parent must unlock.")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        }

        Spacer()

        Text("Ready")
          .font(.system(size: 13, weight: .medium))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.green.opacity(0.18))
          .foregroundStyle(.green)
          .clipShape(RoundedRectangle(cornerRadius: 999))
      }

      Button {
        Task { await unlockWithApple() }
      } label: {
        Label("Unlock", systemImage: "arrow.right")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(18)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  @MainActor
  private func unlockWithApple() async {
    signInError = nil

    // If already signed in, no need to show the dialog.
    if model.isSignedIn {
      model.unlockChildSetup()
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

      model.unlockChildSetup()
    } catch {
      signInError = String(describing: error)
      showError = true
    }
    #else
    signInError = "Sign in with Apple unavailable on this build target."
    showError = true
    #endif
  }
}

#Preview {
  ChildLockedView()
    .environmentObject(AppModel())
}
#endif

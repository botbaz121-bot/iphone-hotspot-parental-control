import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

public struct ParentSignInView: View {
  @EnvironmentObject private var model: AppModel
  @State private var status: String?

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        headerCard
        whyCard

        if let status {
          Text(status)
            .font(.footnote)
            .foregroundStyle(.red)
        }
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
          Text("Sign in")
            .font(.largeTitle.bold())
          Text("Sign in to manage devices and unlock child setup screens.")
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

      #if canImport(AuthenticationServices)
      Button {
        status = nil
        Task {
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
          } catch {
            status = "Apple sign-in failed: \(error)"
          }
        }
      } label: {
        Label("Sign in with Apple", systemImage: "arrow.right")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      #else
      Button {
        let userID = "apple-stub-\(UUID().uuidString.prefix(8))"
        model.signInStub(userID: userID)
      } label: {
        Label("Continue (stub)", systemImage: "arrow.right")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      #endif

      Button {
        // Return to landing / choose mode again.
        model.setAppMode(nil)
        model.restartOnboarding()
      } label: {
        Text("Back")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
    }
    .padding(18)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  private var whyCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Why this exists")
        .font(.headline)
      Text("The parent needs a session to create pairing codes, manage device rules, and unlock child setup screens.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }
}

#Preview {
  ParentSignInView()
    .environmentObject(AppModel())
}
#endif

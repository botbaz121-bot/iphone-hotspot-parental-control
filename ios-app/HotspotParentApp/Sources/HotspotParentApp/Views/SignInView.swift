import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

public struct SignInView: View {
  @EnvironmentObject private var model: AppModel
  @State private var status: String?

  public init() {}

  public var body: some View {
    VStack(spacing: 20) {
      Spacer()

      VStack(spacing: 8) {
        Text("Hotspot Parent")
          .font(.largeTitle.bold())

        Text("MVP")
          .font(.headline)
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 12) {
        #if canImport(AuthenticationServices)
        Button {
          status = nil
          Task {
            do {
              let coord = AppleSignInCoordinator()
              let creds = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<AppleSignInCoordinator.AppleCredentials, Error>) in
                coord.start { result in
                  cont.resume(with: result)
                }
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
          Label("Sign in with Apple", systemImage: "person.crop.circle")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)

        #if DEBUG
        Button("Continue without Apple (dev)") {
          let userID = "apple-stub-\(UUID().uuidString.prefix(8))"
          model.signInStub(userID: userID)
        }
        .buttonStyle(.bordered)

        Text("DEBUG: Stub sign-in is enabled. Release/TestFlight should use real Apple sign-in.")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
        #endif
        #else
        Button("Continue (stub)") {
          let userID = "apple-stub-\(UUID().uuidString.prefix(8))"
          model.signInStub(userID: userID)
        }
        .buttonStyle(.borderedProminent)

        Text("AuthenticationServices not available; using stub.")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
        #endif

        if let status {
          Text(status)
            .font(.system(size: 14))
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        }
      }

      Spacer()
    }
    .padding(.vertical)
    .navigationTitle("Sign In")
  }
}

#Preview {
  NavigationStack {
    SignInView()
      .environmentObject(AppModel())
  }
}
#endif

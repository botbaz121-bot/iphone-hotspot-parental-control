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
        SignInWithAppleButton { request in
          request.requestedScopes = []
        } onCompletion: { result in
          // This is a stub: we *do not* verify tokens or talk to a backend.
          switch result {
            case .success:
              let userID = "apple-stub-\(UUID().uuidString.prefix(8))"
              model.signInStub(userID: userID)
            case .failure(let error):
              status = "Apple sign-in failed: \(error.localizedDescription)"
          }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 48)
        .padding(.horizontal)

        Text("Sign in with Apple is currently a local stub (no backend exchange).")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
        #else
        Button("Sign in (stub)") {
          let userID = "apple-stub-\(UUID().uuidString.prefix(8))"
          model.signInStub(userID: userID)
        }
        .buttonStyle(.borderedProminent)

        Text("AuthenticationServices not available; using stub.")
          .font(.footnote)
          .foregroundStyle(.secondary)
        #endif

        if let status {
          Text(status)
            .font(.footnote)
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

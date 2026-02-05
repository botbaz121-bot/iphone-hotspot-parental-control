import Foundation

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

public enum AppleSignInError: Error {
  case notAvailable
  case missingToken
}

/// Native Sign in with Apple helper.
///
/// Note: This is a building block; the app still needs an app-level coordinator
/// and a backend endpoint to exchange/verify the tokens.
@MainActor
public final class AppleSignInCoordinator: NSObject {
  public typealias Completion = (Result<AppleCredentials, Error>) -> Void

  private var completion: Completion?

  public struct AppleCredentials {
    public var userID: String
    public var identityToken: String
    public var authorizationCode: String
    public var email: String?
    public var fullName: PersonNameComponents?
  }

  public func start(completion: @escaping Completion) {
    #if canImport(AuthenticationServices)
    self.completion = completion

    let provider = ASAuthorizationAppleIDProvider()
    let request = provider.createRequest()
    request.requestedScopes = [.fullName, .email]

    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    controller.performRequests()
    #else
    completion(.failure(AppleSignInError.notAvailable))
    #endif
  }
}

#if canImport(AuthenticationServices)
extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
  public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      completion?(.failure(AppleSignInError.missingToken))
      return
    }

    guard
      let identityTokenData = credential.identityToken,
      let identityToken = String(data: identityTokenData, encoding: .utf8),
      let authCodeData = credential.authorizationCode,
      let authCode = String(data: authCodeData, encoding: .utf8)
    else {
      completion?(.failure(AppleSignInError.missingToken))
      return
    }

    let creds = AppleCredentials(
      userID: credential.user,
      identityToken: identityToken,
      authorizationCode: authCode,
      email: credential.email,
      fullName: credential.fullName
    )

    completion?(.success(creds))
    completion = nil
  }

  public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    completion?(.failure(error))
    completion = nil
  }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
  public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    // App should override this for multi-window scenarios.
    return ASPresentationAnchor()
  }
}
#endif

import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct AppShellView: View {
  @State private var status: String = ""
  @State private var apiBaseURL: String = "https://hotspot-api-ux32.onrender.com"

  public init() {}

  public var body: some View {
    NavigationStack {
      Form {
        Section("Backend") {
          TextField("Base URL", text: $apiBaseURL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

          Button("Test /healthz") {
            Task {
              do {
                let client = HotspotAPIClient(api: API(baseURL: URL(string: apiBaseURL)!, adminToken: nil))
                let out = try await client.healthz()
                status = "healthz: ok=\(out.ok)"
              } catch {
                status = "healthz error: \(error)"
              }
            }
          }
        }

        Section("Sign in with Apple") {
          Button("Start native Sign in with Apple") {
            #if canImport(AuthenticationServices)
            let coord = AppleSignInCoordinator()
            coord.start { result in
              switch result {
                case .success(let creds):
                  status = "Apple user=\(creds.userID.prefix(8))… code=\(creds.authorizationCode.prefix(8))…"
                case .failure(let err):
                  status = "Apple sign-in error: \(err)"
              }
            }
            #else
            status = "AuthenticationServices not available"
            #endif
          }
        }

        if !status.isEmpty {
          Section("Status") {
            Text(status)
              .font(.system(.footnote, design: .monospaced))
          }
        }
      }
      .navigationTitle("Hotspot Parent")
    }
  }
}
#endif

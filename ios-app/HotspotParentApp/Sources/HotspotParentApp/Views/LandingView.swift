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
  @State private var inviteCode: String = ""
  @State private var joiningInvite: Bool = false

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("SpotChecker")
          .font(.system(size: 34, weight: .bold))
          .padding(.top, 2)

        Text("Choose device type")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)

        Text("Debug: mode=\(model.appMode?.rawValue ?? "nil") signedIn=\(model.isSignedIn ? "yes" : "no") parentId=\(model.currentParentId ?? "nil")")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)

        Text(model.authDebugLastEvent)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .lineLimit(3)

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

        SettingsGroup("Join By Invite") {
          VStack(alignment: .leading, spacing: 8) {
            Text("Enter the 4-character code from the parent.")
              .font(.system(size: 14))
              .foregroundStyle(.secondary)

            HStack(spacing: 8) {
              TextField("ABCD", text: $inviteCode)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))

              Button {
                Task { await joinByInvite() }
              } label: {
                if joiningInvite {
                  ProgressView()
                } else {
                  Text("Join")
                    .font(.system(size: 15, weight: .semibold))
                }
              }
              .buttonStyle(.borderedProminent)
              .disabled(joiningInvite)
            }
          }
          .padding(14)
        }
        .padding(.top, 10)
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
    .onChange(of: inviteCode) { value in
      let filtered = value.uppercased().filter { $0.isLetter || $0.isNumber }
      if filtered != value || filtered.count > 4 {
        inviteCode = String(filtered.prefix(4))
      }
    }
  }

  @MainActor
  private func startParent() async {
    status = nil

    do {
      try await ensureParentSignedIn()
      model.setAppMode(.parent)
    } catch {
      status = String(describing: error)
      showError = true
    }
  }

  @MainActor
  private func joinByInvite() async {
    let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard code.count == 4 else {
      status = "Invite code must be 4 characters."
      showError = true
      return
    }

    status = nil
    joiningInvite = true
    defer { joiningInvite = false }

    do {
      try await ensureParentSignedIn()
      try await model.acceptHouseholdInviteCode(code)
      inviteCode = ""
      model.setAppMode(.parent)
    } catch {
      status = String(describing: error)
      showError = true
    }
  }

  @MainActor
  private func ensureParentSignedIn() async throws {
    if model.isSignedIn { return }

    #if canImport(AuthenticationServices)
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
    #else
    throw APIError.invalidResponse
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
      return "\n\nSign in could not be completed. Please try again."
    }()

    return base + detail
  }
}

#Preview {
  LandingView()
    .environmentObject(AppModel())
}
#endif

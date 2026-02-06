import Foundation

#if canImport(SwiftUI)
import SwiftUI

/// Global app state for the MVP.
///
/// Notes:
/// - This is intentionally lightweight (single ObservableObject).
/// - Networking is best-effort and *optional*; the UI works without a backend.
@MainActor
public final class AppModel: ObservableObject {
  // MARK: - Onboarding / Auth

  @Published public var onboardingCompleted: Bool
  @Published public private(set) var appleUserID: String?

  public var isSignedIn: Bool { appleUserID != nil }

  // MARK: - Enrollment

  /// Local enrollment token (works offline).
  @Published public var enrollmentToken: String

  /// Optional backend device id. If present and API is configured, the app can request a pairing code.
  @Published public var deviceId: String?

  @Published public var pairingCode: String?
  @Published public var pairingCodeExpiresAt: Date?

  // MARK: - Dashboard status

  @Published public var lastCheckIn: Date?
  @Published public var hotspotOffPolicyEnabled: Bool

  @Published public var backendHealthOK: Bool?
  @Published public var backendLastError: String?
  @Published public var backendLastRefresh: Date?
  @Published public var backendDeviceCount: Int?

  // MARK: - API Config

  @Published public var apiBaseURL: String
  @Published public var adminToken: String

  // MARK: - Init

  public init() {
    self.onboardingCompleted = AppDefaults.onboardingCompleted
    self.appleUserID = AppDefaults.appleUserID

    self.enrollmentToken = AppDefaults.enrollmentToken ?? Self.generateEnrollmentToken()

    self.lastCheckIn = AppDefaults.lastCheckIn
    self.hotspotOffPolicyEnabled = AppDefaults.policyHotspotOff

    self.apiBaseURL = AppDefaults.apiBaseURL
    self.adminToken = AppDefaults.adminToken ?? ""
    self.deviceId = AppDefaults.deviceId

    // Ensure a token exists on first run.
    if AppDefaults.enrollmentToken == nil {
      AppDefaults.enrollmentToken = enrollmentToken
    }
  }

  // MARK: - Onboarding

  public func completeOnboarding() {
    onboardingCompleted = true
    AppDefaults.onboardingCompleted = true
  }

  // MARK: - Auth (stub)

  public func signInStub(userID: String) {
    appleUserID = userID
    AppDefaults.appleUserID = userID
  }

  public func signOut() {
    appleUserID = nil
    AppDefaults.appleUserID = nil
  }

  // MARK: - Enrollment

  public func regenerateEnrollmentToken() {
    enrollmentToken = Self.generateEnrollmentToken()
    AppDefaults.enrollmentToken = enrollmentToken
  }

  public func clearPairingCode() {
    pairingCode = nil
    pairingCodeExpiresAt = nil
  }

  // MARK: - Policy

  public func setHotspotOffPolicyEnabled(_ enabled: Bool) {
    hotspotOffPolicyEnabled = enabled
    AppDefaults.policyHotspotOff = enabled
  }

  public func recordCheckInNow() {
    let now = Date()
    lastCheckIn = now
    AppDefaults.lastCheckIn = now
  }

  // MARK: - API Config

  public func setAPIBaseURL(_ value: String) {
    apiBaseURL = value
    AppDefaults.apiBaseURL = value
  }

  public func setAdminToken(_ value: String) {
    adminToken = value
    AppDefaults.adminToken = value.isEmpty ? nil : value
  }

  public func setDeviceId(_ value: String?) {
    deviceId = (value?.isEmpty ?? true) ? nil : value
    AppDefaults.deviceId = deviceId
  }

  public var isBackendConfigured: Bool {
    URL(string: apiBaseURL) != nil
  }

  private var apiClient: HotspotAPIClient? {
    guard let url = URL(string: apiBaseURL) else { return nil }
    let token = adminToken.trimmingCharacters(in: .whitespacesAndNewlines)
    let api = API(baseURL: url, adminToken: token.isEmpty ? nil : token)
    return HotspotAPIClient(api: api)
  }

  // MARK: - Backend actions (best-effort)

  public func refreshBackendStatus() async {
    backendLastError = nil
    backendLastRefresh = Date()

    guard let client = apiClient else {
      backendHealthOK = nil
      backendDeviceCount = nil
      backendLastError = "Invalid API base URL"
      return
    }

    do {
      let health: Healthz = try await client.healthz()
      backendHealthOK = health.ok
    } catch {
      backendHealthOK = false
      backendLastError = "Health check failed: \(error)"
      return
    }

    // Admin-only info; ignore errors if admin token missing.
    do {
      let devices = try await client.listDevices()
      backendDeviceCount = devices.count
    } catch {
      backendDeviceCount = nil
    }
  }

  /// Creates a backend device (admin-only) and stores its deviceId.
  public func createBackendDeviceIfNeeded(name: String? = nil) async throws {
    guard deviceId == nil else { return }
    guard let client = apiClient else {
      throw APIError.invalidResponse
    }
    let resp = try await client.createDevice(name: name)
    setDeviceId(resp.id)
  }

  /// Requests a short-lived pairing code (admin-only) for the stored deviceId.
  public func refreshPairingCode() async throws {
    guard let client = apiClient else {
      throw APIError.invalidResponse
    }
    guard let deviceId else {
      throw APIError.invalidResponse
    }
    let resp = try await client.createPairingCode(deviceId: deviceId)
    pairingCode = resp.code
    pairingCodeExpiresAt = Date(timeIntervalSince1970: TimeInterval(resp.expiresAt))
  }

  // MARK: - Token generation

  private static func generateEnrollmentToken() -> String {
    // Human-friendly token: 8-4-4 (not a UUID, but similar).
    func chunk(_ n: Int) -> String {
      let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
      return String((0..<n).compactMap { _ in alphabet.randomElement() })
    }

    return "\(chunk(8))-\(chunk(4))-\(chunk(4))"
  }
}
#endif

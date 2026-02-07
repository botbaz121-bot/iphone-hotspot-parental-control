import Foundation

#if canImport(SwiftUI)
import SwiftUI

/// Global app state for SpotCheck iOS.
///
/// v1A scope: child setup + shortcut config + basic parent UI (no admin token shipped).
@MainActor
public final class AppModel: ObservableObject {
  // MARK: - Mode / Session

  @Published public var appMode: AppMode? {
    didSet { SharedDefaults.appModeRaw = appMode?.rawValue }
  }

  /// Parent unlock/sign-in (stub for v1A). Used for child unlock.
  @Published public private(set) var appleUserID: String?
  public var isSignedIn: Bool { appleUserID != nil }

  // MARK: - Parent state (v1A mostly cosmetic)

  @Published public var selectedDeviceId: String? {
    didSet { SharedDefaults.selectedDeviceId = selectedDeviceId }
  }

  // MARK: - Child setup state

  @Published public var childIsLocked: Bool {
    didSet { SharedDefaults.childLocked = childIsLocked }
  }

  @Published public var childPairedDeviceId: String? {
    didSet { SharedDefaults.childPairingDeviceId = childPairedDeviceId }
  }

  @Published public var childPairedDeviceName: String? {
    didSet { SharedDefaults.childPairingName = childPairedDeviceName }
  }

  @Published public var appIntentRunCount: Int {
    didSet { SharedDefaults.appIntentRunCount = appIntentRunCount }
  }

  @Published public var lastAppIntentRunAt: Date? {
    didSet { SharedDefaults.lastAppIntentRunAt = lastAppIntentRunAt }
  }

  @Published public var screenTimeAuthorized: Bool {
    didSet { SharedDefaults.screenTimeAuthorized = screenTimeAuthorized }
  }

  @Published public var shieldingApplied: Bool {
    didSet { SharedDefaults.shieldingApplied = shieldingApplied }
  }

  // MARK: - API Config

  /// Base URL for the backend. Needed on child for pairing + shortcut execution.
  @Published public var apiBaseURL: String

  /// Dev-only admin token (kept for local debugging; should be blank in App Store builds).
  @Published public var adminToken: String

  // MARK: - Backend status (debug)

  @Published public var backendHealthOK: Bool?
  @Published public var backendLastError: String?
  @Published public var backendLastRefresh: Date?

  // MARK: - Init

  public init() {
    self.appMode = SharedDefaults.appModeRaw.flatMap { AppMode(rawValue: $0) }
    self.appleUserID = AppDefaults.appleUserID

    self.selectedDeviceId = SharedDefaults.selectedDeviceId

    self.childIsLocked = SharedDefaults.childLocked
    self.childPairedDeviceId = SharedDefaults.childPairingDeviceId
    self.childPairedDeviceName = SharedDefaults.childPairingName

    self.appIntentRunCount = SharedDefaults.appIntentRunCount
    self.lastAppIntentRunAt = SharedDefaults.lastAppIntentRunAt

    self.screenTimeAuthorized = SharedDefaults.screenTimeAuthorized
    self.shieldingApplied = SharedDefaults.shieldingApplied

    self.apiBaseURL = AppDefaults.apiBaseURL
    self.adminToken = AppDefaults.adminToken ?? ""
  }

  // MARK: - Mode switching

  public func setAppMode(_ mode: AppMode?) {
    appMode = mode
  }

  // MARK: - Auth (stub for v1A)

  public func signInStub(userID: String) {
    appleUserID = userID
    AppDefaults.appleUserID = userID
  }

  public func signOut() {
    appleUserID = nil
    AppDefaults.appleUserID = nil
  }

  // MARK: - Child pairing

  public var isBackendConfigured: Bool {
    URL(string: apiBaseURL) != nil
  }

  private var apiClient: HotspotAPIClient? {
    guard let url = URL(string: apiBaseURL) else { return nil }
    let token = adminToken.trimmingCharacters(in: .whitespacesAndNewlines)
    let api = API(baseURL: url, adminToken: token.isEmpty ? nil : token)
    return HotspotAPIClient(api: api)
  }

  public func pairChildDevice(code: String, name: String?) async throws {
    guard let client = apiClient else { throw APIError.invalidResponse }
    let resp = try await client.pairDevice(code: code, name: name)

    childPairedDeviceId = resp.deviceId
    childPairedDeviceName = resp.name

    let cfg = HotspotConfig(apiBaseURL: apiBaseURL, deviceToken: resp.deviceToken, deviceSecret: resp.deviceSecret)
    try KeychainStore.setCodable(cfg, account: KeychainAccounts.hotspotConfig)
  }

  public func unpairChildDevice() {
    childPairedDeviceId = nil
    childPairedDeviceName = nil
    do {
      try KeychainStore.setCodable(Optional<HotspotConfig>.none, account: KeychainAccounts.hotspotConfig)
    } catch {
      // Best-effort. If Keychain fails, the UI will still consider the device unpaired.
    }
  }

  public func loadHotspotConfig() -> HotspotConfig? {
    do {
      return try KeychainStore.getCodable(HotspotConfig.self, account: KeychainAccounts.hotspotConfig)
    } catch {
      return nil
    }
  }

  // MARK: - Child lock

  public func lockChildSetup() {
    childIsLocked = true
  }

  public func unlockChildSetup() {
    childIsLocked = false
  }

  // MARK: - Intent telemetry

  public func recordIntentRun(now: Date = Date()) {
    appIntentRunCount += 1
    lastAppIntentRunAt = now
  }

  // MARK: - API config persistence

  public func setAPIBaseURL(_ value: String) {
    apiBaseURL = value
    AppDefaults.apiBaseURL = value
  }

  public func setAdminToken(_ value: String) {
    adminToken = value
    AppDefaults.adminToken = value.isEmpty ? nil : value
  }

  // MARK: - Backend status (debug)

  public func refreshBackendStatus() async {
    backendLastError = nil
    backendLastRefresh = Date()

    guard let client = apiClient else {
      backendHealthOK = nil
      backendLastError = "Invalid API base URL"
      return
    }

    do {
      let health: Healthz = try await client.healthz()
      backendHealthOK = health.ok
    } catch {
      backendHealthOK = false
      backendLastError = "Health check failed: \(error)"
    }
  }

  // MARK: - Debug

  public func resetLocalData() {
    // Non-secure defaults
    AppDefaults.resetAll()
    // App group defaults
    SharedDefaults.resetAll()
    // Keychain (best-effort)
    unpairChildDevice()

    // Reset in-memory state
    appMode = nil
    signOut()

    apiBaseURL = AppDefaults.apiBaseURL
    adminToken = AppDefaults.adminToken ?? ""

    backendHealthOK = nil
    backendLastError = nil
    backendLastRefresh = nil
  }
}

public enum KeychainAccounts {
  public static let hotspotConfig = "spotcheck.hotspotConfig"
}
#endif

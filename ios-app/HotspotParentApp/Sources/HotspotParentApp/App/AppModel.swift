import Foundation

#if canImport(SwiftUI)
import SwiftUI

/// Global app state for SpotCheck iOS.
///
/// v1A scope: child setup + shortcut config + basic parent UI (no admin token shipped).
@MainActor
public final class AppModel: ObservableObject {
  // MARK: - Mode / Session

  @Published public var onboardingCompleted: Bool {
    didSet { AppDefaults.onboardingCompleted = onboardingCompleted }
  }

  @Published public var appMode: AppMode? {
    didSet { SharedDefaults.appModeRaw = appMode?.rawValue }
  }

  /// Parent unlock/sign-in (v1B). Server-minted session JWT.
  @Published public private(set) var parentSessionToken: String?
  public var isSignedIn: Bool { parentSessionToken != nil }

  /// Apple user id (best-effort, informational).
  @Published public private(set) var appleUserID: String?

  // MARK: - Parent state (v1B)

  @Published public var parentDevices: [DashboardDevice] = []
  @Published public var parentLoading: Bool = false
  @Published public var parentLastError: String?

  // UI helpers
  @Published public var presentEnrollSheet: Bool = false

  @Published public var selectedDeviceId: String? {
    didSet { SharedDefaults.selectedDeviceId = selectedDeviceId }
  }

  @Published public var adsRemoved: Bool {
    didSet { AppDefaults.adsRemoved = adsRemoved }
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

  @Published public var childUnlockRequested: Bool {
    didSet { SharedDefaults.childUnlockRequested = childUnlockRequested }
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
    self.onboardingCompleted = AppDefaults.onboardingCompleted

    self.appMode = SharedDefaults.appModeRaw.flatMap { AppMode(rawValue: $0) }

    // Parent session token: store in Keychain so it survives app restarts reliably.
    // Fallback to legacy UserDefaults value if present.
    let keychainToken = (try? KeychainStore.getCodable(String.self, account: KeychainAccounts.parentSessionToken)) ?? nil
    let token = keychainToken ?? AppDefaults.parentSessionToken
    self.parentSessionToken = token
    if let token { try? KeychainStore.setCodable(token, account: KeychainAccounts.parentSessionToken) }

    self.appleUserID = AppDefaults.appleUserID

    self.selectedDeviceId = SharedDefaults.selectedDeviceId

    self.adsRemoved = AppDefaults.adsRemoved

    self.childIsLocked = SharedDefaults.childLocked
    self.childPairedDeviceId = SharedDefaults.childPairingDeviceId
    self.childPairedDeviceName = SharedDefaults.childPairingName

    self.appIntentRunCount = SharedDefaults.appIntentRunCount
    self.lastAppIntentRunAt = SharedDefaults.lastAppIntentRunAt

    self.screenTimeAuthorized = SharedDefaults.screenTimeAuthorized
    self.shieldingApplied = SharedDefaults.shieldingApplied
    self.childUnlockRequested = SharedDefaults.childUnlockRequested

    self.apiBaseURL = AppDefaults.apiBaseURL
    self.adminToken = AppDefaults.adminToken ?? ""
  }

  // MARK: - Mode switching

  public func completeOnboarding() {
    onboardingCompleted = true
  }

  public func restartOnboarding() {
    onboardingCompleted = false
  }

  public func setAppMode(_ mode: AppMode?) {
    appMode = mode
  }

  public func startParentFlow() {
    // Onboarding screens removed; this now simply selects the parent mode.
    setAppMode(.parent)
  }

  public func startChildFlow() {
    // Onboarding screens removed; this now simply selects the child-setup mode.
    setAppMode(.childSetup)
  }

  // MARK: - Auth (v1B)

  public func signInStub(userID: String) {
    // Kept for DEBUG/dev flows.
    appleUserID = userID
    AppDefaults.appleUserID = userID
  }

  public func signInWithApple(identityToken: String, appleUserID: String, email: String?, fullName: PersonNameComponents?) async throws {
    guard let client = apiClient else { throw APIError.invalidResponse }

    let displayName: String? = {
      guard let fullName else { return nil }
      let parts = [fullName.givenName, fullName.familyName].compactMap { $0 }.filter { !$0.isEmpty }
      return parts.isEmpty ? nil : parts.joined(separator: " ")
    }()

    let resp = try await client.signInWithAppleNative(identityToken: identityToken, email: email, fullName: displayName)

    parentSessionToken = resp.sessionToken
    AppDefaults.parentSessionToken = resp.sessionToken
    try? KeychainStore.setCodable(resp.sessionToken, account: KeychainAccounts.parentSessionToken)

    self.appleUserID = appleUserID
    AppDefaults.appleUserID = appleUserID
  }

  public func signOut() {
    parentSessionToken = nil
    AppDefaults.parentSessionToken = nil
    try? KeychainStore.setCodable(Optional<String>.none, account: KeychainAccounts.parentSessionToken)

    appleUserID = nil
    AppDefaults.appleUserID = nil
  }

  // MARK: - Child pairing

  public var isBackendConfigured: Bool {
    URL(string: apiBaseURL) != nil
  }

  private var apiClient: HotspotAPIClient? {
    guard let url = URL(string: apiBaseURL) else { return nil }
    let admin = adminToken.trimmingCharacters(in: .whitespacesAndNewlines)
    let parent = (parentSessionToken ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let api = API(baseURL: url, parentSessionToken: parent.isEmpty ? nil : parent, adminToken: admin.isEmpty ? nil : admin)
    return HotspotAPIClient(api: api)
  }

  public func pairChildDevice(code: String) async throws {
    guard let client = apiClient else { throw APIError.invalidResponse }
    let resp = try await client.pairDevice(code: code)

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
    childUnlockRequested = false
  }

  public func requestChildUnlock() {
    childUnlockRequested = true
  }

  public func cancelChildUnlock() {
    childUnlockRequested = false
  }

  public func unlockChildSetup() {
    childIsLocked = false
    childUnlockRequested = false
  }

  // MARK: - Intent telemetry

  public func recordIntentRun(now: Date = Date()) {
    appIntentRunCount += 1
    lastAppIntentRunAt = now
  }

  /// Pull values from the shared defaults suite.
  ///
  /// Note: AppIntents run in a separate process. When they update SharedDefaults,
  /// the running app won't see those changes unless we re-read them.
  public func syncFromSharedDefaults() {
    self.childIsLocked = SharedDefaults.childLocked
    self.childUnlockRequested = SharedDefaults.childUnlockRequested

    self.childPairedDeviceId = SharedDefaults.childPairingDeviceId
    self.childPairedDeviceName = SharedDefaults.childPairingName

    self.appIntentRunCount = SharedDefaults.appIntentRunCount
    self.lastAppIntentRunAt = SharedDefaults.lastAppIntentRunAt

    self.screenTimeAuthorized = SharedDefaults.screenTimeAuthorized
    self.shieldingApplied = SharedDefaults.shieldingApplied

    self.selectedDeviceId = SharedDefaults.selectedDeviceId
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

  // MARK: - Parent API

  public var selectedParentDevice: DashboardDevice? {
    guard let id = selectedDeviceId else { return nil }
    return parentDevices.first(where: { $0.id == id })
  }

  public func refreshParentDashboard() async {
    parentLastError = nil
    guard isSignedIn else { return }
    guard let client = apiClient else {
      parentLastError = "Invalid API base URL"
      return
    }

    parentLoading = true
    defer { parentLoading = false }

    do {
      let dash = try await client.dashboard()
      parentDevices = dash.devices
      if selectedDeviceId == nil {
        selectedDeviceId = dash.devices.first?.id
      }
    } catch {
      parentLastError = String(describing: error)
    }
  }

  public func updateSelectedDevicePolicy(
    enforce: Bool? = nil,
    setHotspotOff: Bool? = nil,
    rotatePassword: Bool? = nil,
    quietStart: String? = nil,
    quietEnd: String? = nil,
    tz: String? = nil,
    gapMinutes: Int? = nil
  ) async throws {
    guard let deviceId = selectedDeviceId else { throw APIError.invalidResponse }
    guard let client = apiClient else { throw APIError.invalidResponse }

    let patch = UpdatePolicyRequest(
      enforce: enforce,
      setHotspotOff: setHotspotOff,
      rotatePassword: rotatePassword,
      quietStart: quietStart,
      quietEnd: quietEnd,
      tz: tz,
      gapMinutes: gapMinutes
    )

    try await client.updatePolicy(deviceId: deviceId, patch: patch)
    await refreshParentDashboard()
  }

  public func createPairingCodeForSelectedDevice(ttlMinutes: Int = 10) async throws -> PairingCodeResponse {
    guard let deviceId = selectedDeviceId else { throw APIError.invalidResponse }
    guard let client = apiClient else { throw APIError.invalidResponse }
    let out = try await client.createPairingCode(deviceId: deviceId)
    return out
  }

  public func createDeviceAndPairingCode(name: String?) async throws -> PairingCodeResponse {
    guard let client = apiClient else { throw APIError.invalidResponse }
    let created = try await client.createDevice(name: name)
    let code = try await client.createPairingCode(deviceId: created.id)
    await refreshParentDashboard()
    selectedDeviceId = created.id
    return code
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
    onboardingCompleted = false
    childIsLocked = false
    childUnlockRequested = false
    signOut()

    adsRemoved = AppDefaults.adsRemoved

    apiBaseURL = AppDefaults.apiBaseURL
    adminToken = AppDefaults.adminToken ?? ""

    backendHealthOK = nil
    backendLastError = nil
    backendLastRefresh = nil
  }
}

public enum KeychainAccounts {
  public static let hotspotConfig = "spotcheck.hotspotConfig"
  public static let parentSessionToken = "spotcheck.parent.sessionToken"
}
#endif

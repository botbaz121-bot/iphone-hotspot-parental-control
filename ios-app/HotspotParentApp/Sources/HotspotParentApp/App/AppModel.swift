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
  @Published public var pendingOpenDeviceDetailsId: String?

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

  @Published public var screenTimeAuthorizationMode: ScreenTimeAuthorizationMode {
    didSet { SharedDefaults.screenTimeAuthorizationModeRaw = screenTimeAuthorizationMode.rawValue }
  }

  @Published public var shieldingApplied: Bool {
    didSet { SharedDefaults.shieldingApplied = shieldingApplied }
  }

  @Published public var screenTimeHasRequiredSelection: Bool {
    didSet { SharedDefaults.screenTimeHasRequiredSelection = screenTimeHasRequiredSelection }
  }

  @Published public var screenTimePasswordStepCompleted: Bool {
    didSet { SharedDefaults.screenTimePasswordStepCompleted = screenTimePasswordStepCompleted }
  }

  @Published public var screenTimeDeletionProtectionStepCompleted: Bool {
    didSet { SharedDefaults.screenTimeDeletionProtectionStepCompleted = screenTimeDeletionProtectionStepCompleted }
  }

  @Published public var screenTimeDegradedReason: String? {
    didSet { SharedDefaults.screenTimeDegradedReason = screenTimeDegradedReason }
  }

  @Published public var screenTimeScheduleEnforcedNow: Bool {
    didSet { SharedDefaults.screenTimeScheduleEnforcedNow = screenTimeScheduleEnforcedNow }
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
  @Published public var extraTimePrefillMinutesByDeviceId: [String: Int] = [:]
  @Published public var extraTimePendingRequestIdByDeviceId: [String: String] = [:]
  @Published public var lastRegisteredPushToken: String?

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
    self.screenTimeAuthorizationMode = SharedDefaults.screenTimeAuthorizationModeRaw
      .flatMap(ScreenTimeAuthorizationMode.init(rawValue:)) ?? .individual
    self.shieldingApplied = SharedDefaults.shieldingApplied
    self.screenTimeHasRequiredSelection = SharedDefaults.screenTimeHasRequiredSelection
    self.screenTimePasswordStepCompleted = SharedDefaults.screenTimePasswordStepCompleted
    self.screenTimeDeletionProtectionStepCompleted = SharedDefaults.screenTimeDeletionProtectionStepCompleted
    self.screenTimeDegradedReason = SharedDefaults.screenTimeDegradedReason
    self.screenTimeScheduleEnforcedNow = SharedDefaults.screenTimeScheduleEnforcedNow
    self.childUnlockRequested = SharedDefaults.childUnlockRequested

    self.apiBaseURL = AppDefaults.apiBaseURL
    self.adminToken = AppDefaults.adminToken ?? ""
    self.lastRegisteredPushToken = AppDefaults.parentPushToken
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
    await syncPushRegistrationIfNeeded()
  }

  public func signOut() {
    parentSessionToken = nil
    AppDefaults.parentSessionToken = nil
    try? KeychainStore.setCodable(Optional<String>.none, account: KeychainAccounts.parentSessionToken)

    appleUserID = nil
    AppDefaults.appleUserID = nil
    pendingOpenDeviceDetailsId = nil
    extraTimePrefillMinutesByDeviceId = [:]
    extraTimePendingRequestIdByDeviceId = [:]
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
    self.screenTimeAuthorizationMode = SharedDefaults.screenTimeAuthorizationModeRaw
      .flatMap(ScreenTimeAuthorizationMode.init(rawValue:)) ?? .individual
    self.shieldingApplied = SharedDefaults.shieldingApplied
    self.screenTimeHasRequiredSelection = SharedDefaults.screenTimeHasRequiredSelection
    self.screenTimePasswordStepCompleted = SharedDefaults.screenTimePasswordStepCompleted
    self.screenTimeDeletionProtectionStepCompleted = SharedDefaults.screenTimeDeletionProtectionStepCompleted
    self.screenTimeDegradedReason = SharedDefaults.screenTimeDegradedReason
    self.screenTimeScheduleEnforcedNow = SharedDefaults.screenTimeScheduleEnforcedNow

    self.selectedDeviceId = SharedDefaults.selectedDeviceId
  }

  public func reconcileScreenTimeProtection() async {
    let status = await ScreenTimeManager.shared.reconcileProtectionNow()
    self.screenTimeAuthorized = status.authorized
    self.shieldingApplied = status.shieldingApplied
    self.screenTimeHasRequiredSelection = status.hasRequiredSelection
    self.screenTimeScheduleEnforcedNow = status.scheduleEnforcedNow
    self.screenTimeDegradedReason = status.degradedReason
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

  public func setExtraTimePrefill(deviceId: String, minutes: Int, requestId: String?) {
    let clamped = max(5, min(240, (minutes / 5) * 5))
    extraTimePrefillMinutesByDeviceId[deviceId] = clamped
    if let requestId, !requestId.isEmpty {
      extraTimePendingRequestIdByDeviceId[deviceId] = requestId
    }
    selectedDeviceId = deviceId
    pendingOpenDeviceDetailsId = deviceId
  }

  public func consumeExtraTimePrefill(deviceId: String) -> Int? {
    defer { extraTimePrefillMinutesByDeviceId.removeValue(forKey: deviceId) }
    return extraTimePrefillMinutesByDeviceId[deviceId]
  }

  public func consumeExtraTimePendingRequestId(deviceId: String) -> String? {
    defer { extraTimePendingRequestIdByDeviceId.removeValue(forKey: deviceId) }
    return extraTimePendingRequestIdByDeviceId[deviceId]
  }

  public func stashExtraTimePendingRequest(deviceId: String, requestId: String, minutes: Int) {
    let clamped = max(5, min(240, (minutes / 5) * 5))
    extraTimePrefillMinutesByDeviceId[deviceId] = clamped
    extraTimePendingRequestIdByDeviceId[deviceId] = requestId
  }

  public func registerParentPushTokenIfPossible(_ token: String) async {
    let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return }
    AppDefaults.parentPushToken = normalized
    lastRegisteredPushToken = normalized

    guard isSignedIn else { return }
    guard let client = apiClient else { return }
    do {
      try await client.registerParentPushToken(normalized)
    } catch {
      // best-effort
    }
  }

  public func syncPushRegistrationIfNeeded() async {
    guard isSignedIn else { return }
    let token = (lastRegisteredPushToken ?? AppDefaults.parentPushToken)?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let token, !token.isEmpty else { return }
    guard let client = apiClient else { return }
    do {
      try await client.registerParentPushToken(token)
    } catch {
      // best-effort
    }
  }

  public func childRequestExtraTime(minutes: Int, reason: String? = nil) async throws {
    let clamped = max(5, min(240, (minutes / 5) * 5))
    guard let cfg = loadHotspotConfig() else { throw APIError.invalidResponse }
    guard let url = URL(string: cfg.apiBaseURL) else { throw APIError.invalidResponse }
    let client = HotspotAPIClient(api: API(baseURL: url))
    _ = try await client.requestExtraTime(deviceSecret: cfg.deviceSecret, minutes: clamped, reason: reason)
  }

  public func parentApplyExtraTime(deviceId: String, minutes: Int) async throws -> Date? {
    guard let client = apiClient else { throw APIError.invalidResponse }
    let clamped = max(0, min(240, (minutes / 5) * 5))

    if let requestId = consumeExtraTimePendingRequestId(deviceId: deviceId) {
      _ = try await client.decideExtraTimeRequest(requestId: requestId, approve: true, grantedMinutes: clamped)
    } else {
      _ = try await client.grantExtraTime(deviceId: deviceId, minutes: clamped, reason: "parent_manual")
    }
    await refreshParentDashboard()
    if let device = parentDevices.first(where: { $0.id == deviceId }),
       let endsAt = device.activeExtraTime?.endsAt {
      return Date(timeIntervalSince1970: TimeInterval(endsAt) / 1000.0)
    }
    return nil
  }

  public func fetchLatestPendingExtraTimeRequest(deviceId: String) async throws -> ExtraTimeRequestRow? {
    guard let client = apiClient else { throw APIError.invalidResponse }
    let out = try await client.extraTimeRequests(status: "pending", deviceId: nil)
    return out.requests.first(where: { $0.deviceId == deviceId })
  }

  public func updateSelectedDevicePolicy(
    activateProtection: Bool? = nil,
    setHotspotOff: Bool? = nil,
    setWifiOff: Bool? = nil,
    setMobileDataOff: Bool? = nil,
    rotatePassword: Bool? = nil,
    quietStart: String? = nil,
    quietEnd: String? = nil,
    quietDays: [String: UpdatePolicyRequest.QuietDayWindow]? = nil,
    tz: String? = nil,
    gapMinutes: Int? = nil
  ) async throws {
    guard let deviceId = selectedDeviceId else { throw APIError.invalidResponse }
    guard let client = apiClient else { throw APIError.invalidResponse }

    let patch = UpdatePolicyRequest(
      activateProtection: activateProtection,
      setHotspotOff: setHotspotOff,
      rotatePassword: rotatePassword,
      setWifiOff: setWifiOff,
      setMobileDataOff: setMobileDataOff,
      quietStart: quietStart,
      quietEnd: quietEnd,
      quietDays: quietDays,
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

  public func createDeviceAndPairingCode(name: String) async throws -> PairingCodeResponse {
    guard let client = apiClient else { throw APIError.invalidResponse }
    let created = try await client.createDevice(name: name)
    let code = try await client.createPairingCode(deviceId: created.id)
    await refreshParentDashboard()
    selectedDeviceId = created.id
    return code
  }

  public func renameDevice(deviceId: String, name: String) async throws {
    guard let client = apiClient else { throw APIError.invalidResponse }
    try await client.updateDevice(deviceId: deviceId, patch: UpdateDeviceRequest(name: name, icon: nil))
    await refreshParentDashboard()
  }

  public func setDevicePhoto(deviceId: String, jpegData: Data?) {
    do {
      try DevicePhotoStore.setPhotoJPEG(deviceId: deviceId, data: jpegData)
      objectWillChange.send()
    } catch {
      // best-effort
    }
  }

  public func deleteDevice(deviceId: String) async throws {
    guard let client = apiClient else { throw APIError.invalidResponse }
    try await client.deleteDevice(deviceId: deviceId)
    // If we deleted the selected device, clear selection.
    if selectedDeviceId == deviceId { selectedDeviceId = nil }
    await refreshParentDashboard()
  }

  public func fetchDeviceEvents(deviceId: String) async throws -> [DeviceEventRow] {
    guard let client = apiClient else { throw APIError.invalidResponse }
    let resp = try await client.events(deviceId: deviceId)
    return resp.events
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
    screenTimeAuthorized = false
    shieldingApplied = false
    screenTimeHasRequiredSelection = false
    screenTimePasswordStepCompleted = false
    screenTimeDeletionProtectionStepCompleted = false
    screenTimeDegradedReason = nil
    screenTimeScheduleEnforcedNow = false
    signOut()

    adsRemoved = AppDefaults.adsRemoved

    apiBaseURL = AppDefaults.apiBaseURL
    adminToken = AppDefaults.adminToken ?? ""

    backendHealthOK = nil
    backendLastError = nil
    backendLastRefresh = nil
    pendingOpenDeviceDetailsId = nil
    extraTimePrefillMinutesByDeviceId = [:]
    extraTimePendingRequestIdByDeviceId = [:]
    lastRegisteredPushToken = nil
  }
}

public enum KeychainAccounts {
  public static let hotspotConfig = "spotcheck.hotspotConfig"
  public static let parentSessionToken = "spotcheck.parent.sessionToken"
}
#endif

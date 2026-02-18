import Foundation

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

public struct ScreenTimeSelectionSummary {
  public var requiredSelectionsSelected: Int
  public var quietSelectionsSelected: Int
  public var hasRequiredSelection: Bool

  public init(requiredSelectionsSelected: Int = 0, quietSelectionsSelected: Int = 0, hasRequiredSelection: Bool = false) {
    self.requiredSelectionsSelected = requiredSelectionsSelected
    self.quietSelectionsSelected = quietSelectionsSelected
    self.hasRequiredSelection = hasRequiredSelection
  }
}

public struct ScreenTimeProtectionStatus {
  public var authorized: Bool
  public var shieldingApplied: Bool
  public var hasRequiredSelection: Bool
  public var quietHoursConfigured: Bool
  public var scheduleEnforcedNow: Bool
  public var degradedReason: String?

  public init(
    authorized: Bool = false,
    shieldingApplied: Bool = false,
    hasRequiredSelection: Bool = false,
    quietHoursConfigured: Bool = false,
    scheduleEnforcedNow: Bool = false,
    degradedReason: String? = nil
  ) {
    self.authorized = authorized
    self.shieldingApplied = shieldingApplied
    self.hasRequiredSelection = hasRequiredSelection
    self.quietHoursConfigured = quietHoursConfigured
    self.scheduleEnforcedNow = scheduleEnforcedNow
    self.degradedReason = degradedReason
  }
}

public enum ScreenTimeAuthorizationMode: String, CaseIterable {
  case individual
  case familyChild

  public var title: String {
    switch self {
    case .individual:
      return "This Device"
    case .familyChild:
      return "Family Child"
    }
  }
}

@MainActor
public final class ScreenTimeManager {
  public static let shared = ScreenTimeManager()

  #if canImport(ManagedSettings)
  private let store = ManagedSettingsStore()
  #endif

  private init() {}

  private static let policyCacheKey = "last_policy_json"
  private var lastPolicyDebugLine: String = "policy: not loaded yet"
  private var lastAuthorizationDebugLine: String = "auth: not requested yet"

  public func requestAuthorization(mode: ScreenTimeAuthorizationMode) async throws -> Bool {
    #if canImport(FamilyControls)
    let center = AuthorizationCenter.shared
    lastAuthorizationDebugLine = "auth: request mode=\(mode.rawValue) status(before)=\(String(describing: center.authorizationStatus))"
    do {
      switch mode {
      case .individual:
        try await center.requestAuthorization(for: .individual)
      case .familyChild:
        try await center.requestAuthorization(for: .child)
      }
      let approved = center.authorizationStatus == .approved
      SharedDefaults.screenTimeAuthorizedModeRaw = approved ? mode.rawValue : nil
      let grantedMode = SharedDefaults.screenTimeAuthorizedModeRaw ?? "none"
      lastAuthorizationDebugLine =
        "auth: mode=\(mode.rawValue) status(after)=\(String(describing: center.authorizationStatus)) approved=\(approved) grantedMode=\(grantedMode)"
      return approved
    } catch {
      SharedDefaults.screenTimeAuthorizedModeRaw = nil
      lastAuthorizationDebugLine =
        "auth: mode=\(mode.rawValue) error=\(String(describing: error)) status(after)=\(String(describing: center.authorizationStatus))"
      return false
    }
    #else
    return false
    #endif
  }

  public func isAuthorized() -> Bool {
    #if canImport(FamilyControls)
    return AuthorizationCenter.shared.authorizationStatus == .approved
    #else
    return false
    #endif
  }

  public func selectionSummary() -> ScreenTimeSelectionSummary {
    #if canImport(FamilyControls)
    let required = loadRequiredSelection()
    let quiet = loadQuietSelection()
    let requiredCount = (required?.applicationTokens.count ?? 0) + (required?.categoryTokens.count ?? 0)
    let quietCount = (quiet?.applicationTokens.count ?? 0) + (quiet?.categoryTokens.count ?? 0)
    return ScreenTimeSelectionSummary(
      requiredSelectionsSelected: requiredCount,
      quietSelectionsSelected: quietCount,
      hasRequiredSelection: !(required?.applicationTokens.isEmpty ?? true)
    )
    #else
    return ScreenTimeSelectionSummary()
    #endif
  }

  public func reconcileProtectionNow() async -> ScreenTimeProtectionStatus {
    #if canImport(FamilyControls) && canImport(ManagedSettings)
    let mode = SharedDefaults.screenTimeAuthorizationModeRaw
      .flatMap(ScreenTimeAuthorizationMode.init(rawValue:)) ?? .individual
    let modeAuthorized = SharedDefaults.screenTimeAuthorizedModeRaw
      .flatMap(ScreenTimeAuthorizationMode.init(rawValue:)) == mode
    let authorized = isAuthorized() && modeAuthorized
    guard authorized else {
      lastPolicyDebugLine = "policy source=skipped(reason=not_authorized)"
      clearShielding()
      return ScreenTimeProtectionStatus(
        authorized: false,
        shieldingApplied: false,
        hasRequiredSelection: false,
        quietHoursConfigured: false,
        scheduleEnforcedNow: false,
        degradedReason: mode == .familyChild
          ? "Waiting for guardian approval in Screen Time Family settings."
          : "Screen Time permission is not granted."
      )
    }

    guard let required = loadRequiredSelection(),
          !required.applicationTokens.isEmpty else {
      lastPolicyDebugLine = "policy source=skipped(reason=missing_required_selection)"
      clearShielding()
      return ScreenTimeProtectionStatus(
        authorized: true,
        shieldingApplied: false,
        hasRequiredSelection: false,
        quietHoursConfigured: false,
        scheduleEnforcedNow: false,
        degradedReason: nil
      )
    }

    return await applyPolicyDrivenShielding(requiredSelection: required, quietSelection: loadQuietSelection())
    #else
    lastPolicyDebugLine = "policy source=skipped(reason=family_controls_unavailable)"
    return ScreenTimeProtectionStatus(
      authorized: false,
      shieldingApplied: false,
      hasRequiredSelection: false,
      quietHoursConfigured: false,
      scheduleEnforcedNow: false,
      degradedReason: "Family Controls is unavailable in this build."
    )
    #endif
  }

  #if canImport(FamilyControls)
  public func saveRequiredSelection(_ selection: FamilyActivitySelection) {
    if let data = try? JSONEncoder().encode(selection) {
      SharedDefaults.screenTimeSelectionData = data
    }
  }

  public func loadRequiredSelection() -> FamilyActivitySelection? {
    guard let data = SharedDefaults.screenTimeSelectionData else { return nil }
    return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
  }

  public func saveQuietSelection(_ selection: FamilyActivitySelection) {
    if let data = try? JSONEncoder().encode(selection) {
      SharedDefaults.screenTimeQuietSelectionData = data
    }
  }

  public func loadQuietSelection() -> FamilyActivitySelection? {
    guard let data = SharedDefaults.screenTimeQuietSelectionData else { return nil }
    return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
  }
  #endif

  public func clearShielding() {
    #if canImport(ManagedSettings)
    store.clearAllSettings()
    #endif
  }

  public func currentPolicyDebugLine() -> String {
    lastPolicyDebugLine
  }

  public func currentAuthorizationDebugLine() -> String {
    #if canImport(FamilyControls)
    let mode = SharedDefaults.screenTimeAuthorizationModeRaw ?? "individual"
    let grantedMode = SharedDefaults.screenTimeAuthorizedModeRaw ?? "none"
    return "\(lastAuthorizationDebugLine) selectedMode=\(mode) osStatus=\(String(describing: AuthorizationCenter.shared.authorizationStatus)) grantedMode=\(grantedMode)"
    #else
    return "auth: Family Controls unavailable"
    #endif
  }

  #if canImport(FamilyControls) && canImport(ManagedSettings)
  private struct PolicyWindow {
    var activateProtection: Bool
    var quietHoursConfigured: Bool
    var inQuietHours: Bool

    static let `default` = PolicyWindow(activateProtection: true, quietHoursConfigured: false, inQuietHours: false)
  }

  private func applyPolicyDrivenShielding(
    requiredSelection: FamilyActivitySelection,
    quietSelection: FamilyActivitySelection?
  ) async -> ScreenTimeProtectionStatus {
    let policy = await loadPolicyWindow()

    guard policy.activateProtection else {
      clearShielding()
      return ScreenTimeProtectionStatus(
        authorized: true,
        shieldingApplied: false,
        hasRequiredSelection: true,
        quietHoursConfigured: policy.quietHoursConfigured,
        scheduleEnforcedNow: false,
        degradedReason: "Protection is disabled by parent settings for this child device."
      )
    }

    // Backend already evaluates schedule semantics:
    // - schedule set: true only inside schedule window
    // - schedule unset: true (always enforce)
    let shieldOtherAppsNow = policy.inQuietHours

    var appsToShield = Set(requiredSelection.applicationTokens)
    let quietApps = Set(quietSelection?.applicationTokens ?? [])
    if shieldOtherAppsNow {
      appsToShield.formUnion(quietApps)
    }

    store.shield.applications = appsToShield.isEmpty ? nil : appsToShield
    let quietCategories = quietSelection?.categoryTokens ?? []
    if shieldOtherAppsNow, !quietCategories.isEmpty {
      store.shield.applicationCategories = .specific(quietCategories)
    } else {
      store.shield.applicationCategories = nil
    }

    return ScreenTimeProtectionStatus(
      authorized: true,
      shieldingApplied: true,
      hasRequiredSelection: true,
      quietHoursConfigured: policy.quietHoursConfigured,
      scheduleEnforcedNow: shieldOtherAppsNow,
      degradedReason: nil
    )
  }

  private func loadPolicyWindow() async -> PolicyWindow {
    if let cfg = try? KeychainStore.getCodable(HotspotConfig.self, account: KeychainAccounts.hotspotConfig),
       let base = URL(string: cfg.apiBaseURL) {
      do {
        var req = URLRequest(url: base.appendingPathComponent("policy"))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(cfg.deviceSecret)", forHTTPHeaderField: "Authorization")
        req.setValue("SpotCheckiOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(code) else {
          let cached = cachedPolicyWindow()
          lastPolicyDebugLine = "policy source=cache(status \(code)) activateProtection=\(cached.activateProtection) inSchedule=\(cached.inQuietHours)"
          return cached
        }
        if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
          SharedDefaults.suite.set(raw, forKey: Self.policyCacheKey)
        }
        let parsed = parsePolicyWindow(data)
        lastPolicyDebugLine = "policy source=network activateProtection=\(parsed.activateProtection) inSchedule=\(parsed.inQuietHours)"
        return parsed
      } catch {
        let cached = cachedPolicyWindow()
        lastPolicyDebugLine = "policy source=cache(error) activateProtection=\(cached.activateProtection) inSchedule=\(cached.inQuietHours)"
        return cached
      }
    }

    let cached = cachedPolicyWindow()
    lastPolicyDebugLine = "policy source=cache(no config) activateProtection=\(cached.activateProtection) inSchedule=\(cached.inQuietHours)"
    return cached
  }

  private func cachedPolicyWindow() -> PolicyWindow {
    guard let raw = SharedDefaults.suite.string(forKey: Self.policyCacheKey),
          let data = raw.data(using: .utf8)
    else {
      return .default
    }
    return parsePolicyWindow(data)
  }

  private func parsePolicyWindow(_ data: Data) -> PolicyWindow {
    guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
      return .default
    }

    let actions = obj["actions"] as? [String: Any]
    let activateProtection = (obj["activateProtection"] as? Bool) ?? (actions?["activateProtection"] as? Bool) ?? true
    let quietHoursConfigured = (obj["quietHours"] as? [String: Any]) != nil
    let inQuietHours = (obj["isQuietHours"] as? Bool) ?? false
    return PolicyWindow(
      activateProtection: activateProtection,
      quietHoursConfigured: quietHoursConfigured,
      inQuietHours: inQuietHours
    )
  }
  #endif

}

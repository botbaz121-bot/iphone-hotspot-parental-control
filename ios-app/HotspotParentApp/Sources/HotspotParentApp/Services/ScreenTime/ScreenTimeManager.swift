import Foundation

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

public struct ScreenTimeSelectionSummary {
  public var totalAppsSelected: Int
  public var shortcutsSelected: Bool

  public init(totalAppsSelected: Int = 0, shortcutsSelected: Bool = false) {
    self.totalAppsSelected = totalAppsSelected
    self.shortcutsSelected = shortcutsSelected
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

@MainActor
public final class ScreenTimeManager {
  public static let shared = ScreenTimeManager()

  #if canImport(ManagedSettings)
  private let store = ManagedSettingsStore()
  #endif

  private init() {}

  private static let policyCacheKey = "last_policy_json"

  public func requestAuthorization() async throws -> Bool {
    #if canImport(FamilyControls)
    let center = AuthorizationCenter.shared
    do {
      try await center.requestAuthorization(for: .individual)
      return center.authorizationStatus == .approved
    } catch {
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
    guard let selection = loadSelection() else { return ScreenTimeSelectionSummary() }
    let split = splitSelection(selection)
    return ScreenTimeSelectionSummary(
      totalAppsSelected: selection.applicationTokens.count,
      shortcutsSelected: !split.shortcutsTokens.isEmpty
    )
    #else
    return ScreenTimeSelectionSummary()
    #endif
  }

  public func reconcileProtectionNow() async -> ScreenTimeProtectionStatus {
    #if canImport(FamilyControls) && canImport(ManagedSettings)
    let authorized = isAuthorized()
    guard authorized else {
      clearShielding()
      return ScreenTimeProtectionStatus(
        authorized: false,
        shieldingApplied: false,
        hasRequiredSelection: false,
        quietHoursConfigured: false,
        scheduleEnforcedNow: false,
        degradedReason: "Screen Time permission is not granted."
      )
    }

    guard let selection = loadSelection() else {
      clearShielding()
      return ScreenTimeProtectionStatus(
        authorized: true,
        shieldingApplied: false,
        hasRequiredSelection: false,
        quietHoursConfigured: false,
        scheduleEnforcedNow: false,
        degradedReason: "Choose apps to protect first."
      )
    }

    return await applyPolicyDrivenShielding(selection: selection)
    #else
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
  public func saveSelection(_ selection: FamilyActivitySelection) {
    if let data = try? JSONEncoder().encode(selection) {
      SharedDefaults.screenTimeSelectionData = data
    }
  }

  public func loadSelection() -> FamilyActivitySelection? {
    guard let data = SharedDefaults.screenTimeSelectionData else { return nil }
    return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
  }
  #endif

  public func clearShielding() {
    #if canImport(ManagedSettings)
    store.clearAllSettings()
    #endif
  }

  #if canImport(FamilyControls) && canImport(ManagedSettings)
  private struct SelectionSplit {
    var shortcutsTokens: Set<ApplicationToken>
    var otherAppTokens: Set<ApplicationToken>
    var categoryTokens: Set<ActivityCategoryToken>
  }

  private struct PolicyWindow {
    var quietHoursConfigured: Bool
    var inQuietHours: Bool

    static let `default` = PolicyWindow(quietHoursConfigured: false, inQuietHours: false)
  }

  private func splitSelection(_ selection: FamilyActivitySelection) -> SelectionSplit {
    let shortcuts = selection.applicationTokens.filter { token in
      String(describing: token).lowercased().contains("shortcuts")
    }
    let shortcutsSet = Set(shortcuts)
    let others = Set(selection.applicationTokens.filter { !shortcutsSet.contains($0) })
    return SelectionSplit(
      shortcutsTokens: shortcutsSet,
      otherAppTokens: others,
      categoryTokens: selection.categoryTokens
    )
  }

  private func applyPolicyDrivenShielding(selection: FamilyActivitySelection) async -> ScreenTimeProtectionStatus {
    let split = splitSelection(selection)
    let hasRequired = !split.shortcutsTokens.isEmpty

    guard hasRequired else {
      clearShielding()
      return ScreenTimeProtectionStatus(
        authorized: true,
        shieldingApplied: false,
        hasRequiredSelection: false,
        quietHoursConfigured: false,
        scheduleEnforcedNow: false,
        degradedReason: "Select the Shortcuts app. It must stay locked at all times."
      )
    }

    let policy = await loadPolicyWindow()
    let shieldOtherAppsNow = policy.quietHoursConfigured && policy.inQuietHours

    var appsToShield = split.shortcutsTokens
    if shieldOtherAppsNow {
      appsToShield.formUnion(split.otherAppTokens)
    }

    store.shield.applications = appsToShield.isEmpty ? nil : appsToShield
    if shieldOtherAppsNow, !split.categoryTokens.isEmpty {
      store.shield.applicationCategories = .specific(split.categoryTokens)
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
       let cfg,
       let base = URL(string: cfg.apiBaseURL) {
      do {
        var req = URLRequest(url: base.appendingPathComponent("policy"))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(cfg.deviceSecret)", forHTTPHeaderField: "Authorization")
        req.setValue("SpotCheckiOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(code) else { return cachedPolicyWindow() }
        if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
          SharedDefaults.suite.set(raw, forKey: Self.policyCacheKey)
        }
        return parsePolicyWindow(data)
      } catch {
        return cachedPolicyWindow()
      }
    }

    return cachedPolicyWindow()
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

    let quietHoursConfigured = (obj["quietHours"] as? [String: Any]) != nil
    let inQuietHours = (obj["isQuietHours"] as? Bool) ?? false
    return PolicyWindow(
      quietHoursConfigured: quietHoursConfigured,
      inQuietHours: quietHoursConfigured ? inQuietHours : false
    )
  }
  #endif
}

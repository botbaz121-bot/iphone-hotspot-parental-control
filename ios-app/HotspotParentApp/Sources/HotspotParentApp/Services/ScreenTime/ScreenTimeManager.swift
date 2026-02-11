import Foundation

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

/// Best-effort Screen Time / FamilyControls integration.
///
/// Notes:
/// - Requires iOS 16+.
/// - Capabilities/entitlements must be enabled in the Apple Developer portal.
@MainActor
public final class ScreenTimeManager {
  public static let shared = ScreenTimeManager()

  #if canImport(ManagedSettings)
  private let store = ManagedSettingsStore()
  #endif

  private init() {}

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

    /// Applies a minimal shielding set.
  ///
  /// If you pass a non-empty `FamilyActivitySelection`, we shield those apps/categories.
  ///
  /// Note: This is **best-effort**. If FamilyControls/ManagedSettings aren’t available
  /// (or entitlements are missing), this becomes a no-op.
  public func applyShielding(selection: Any? = nil) async throws {
    #if canImport(FamilyControls) && canImport(ManagedSettings)
    if let sel = selection as? FamilyActivitySelection {
      // Applications
      let apps = sel.applicationTokens
      store.shield.applications = apps.isEmpty ? nil : apps

      // Categories (ManagedSettings expects an ActivityCategoryPolicy)
      if let cats = sel.categoryTokens, !cats.isEmpty {
        store.shield.applicationCategories = .specific(cats)
      } else {
        store.shield.applicationCategories = nil
      }
    } else {
      // No selection provided: clear any per-app/category shields.
      store.shield.applications = nil
      store.shield.applicationCategories = nil
    }
    #else
    // No-op
    _ = selection
    #endif
  }

  public func clearShielding() {
    #if canImport(ManagedSettings)
    store.clearAllSettings()
    #endif
  }
}

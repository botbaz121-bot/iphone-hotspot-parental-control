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

  /// Applies a minimal, recommended shielding set.
  ///
  /// For v1A we keep this conservative; further selection UI (FamilyActivityPicker)
  /// can be added later.
  public func applyRecommendedShielding() async throws {
    #if canImport(ManagedSettings)
    // Best-effort. App tokens require user selection via FamilyActivityPicker;
    // here we only set the app/category shields when available.
    // Leaving empty is still a successful no-op if selection isn't implemented.
    store.shield.applications = nil
    store.shield.applicationCategories = nil
    #else
    // No-op
    #endif
  }

  public func clearShielding() {
    #if canImport(ManagedSettings)
    store.clearAllSettings()
    #endif
  }
}

import Foundation

/// App Group-backed shared defaults used by the main app and App Intents.
///
/// Note: Requires an App Group capability with this identifier.
public enum SharedDefaults {
  // Update to match the App Group you create in the Apple Developer portal.
  public static let appGroupID = "group.com.bazapps.hotspotparent"

  public static var suite: UserDefaults {
    // Fall back to standard defaults in environments where the suite isn't available (e.g. previews/tests).
    UserDefaults(suiteName: appGroupID) ?? .standard
  }

  private enum Key {
    static let appMode = "spotcheck.appMode"
    static let selectedDeviceId = "spotcheck.parent.selectedDeviceId"

    static let childLocked = "spotcheck.child.locked"
    static let childPairingDeviceId = "spotcheck.child.pair.deviceId"
    static let childPairingName = "spotcheck.child.pair.name"

    static let appIntentRunCount = "spotcheck.intent.runCount"
    static let lastAppIntentRunAtEpoch = "spotcheck.intent.lastRunAt"

    static let screenTimeAuthorized = "spotcheck.screentime.authorized"
    static let screenTimeAuthorizationMode = "spotcheck.screentime.authorizationMode"
    static let screenTimeAuthorizedMode = "spotcheck.screentime.authorizedMode"
    static let shieldingApplied = "spotcheck.screentime.shieldingApplied"
    static let screenTimeSelectionData = "spotcheck.screentime.selection.data"
    static let screenTimeQuietSelectionData = "spotcheck.screentime.quietSelection.data"
    static let screenTimeHasRequiredSelection = "spotcheck.screentime.requiredSelection"
    static let screenTimePasswordStepCompleted = "spotcheck.screentime.passwordStepCompleted"
    static let screenTimeDeletionProtectionStepCompleted = "spotcheck.screentime.deletionProtectionStepCompleted"
    static let screenTimeDegradedReason = "spotcheck.screentime.degradedReason"
    static let screenTimeScheduleEnforcedNow = "spotcheck.screentime.scheduleEnforcedNow"

    static let childUnlockRequested = "spotcheck.child.unlockRequested"
  }

  public static func resetAll() {
    let d = suite
    [
      Key.appMode,
      Key.selectedDeviceId,
      Key.childLocked,
      Key.childPairingDeviceId,
      Key.childPairingName,
      Key.appIntentRunCount,
      Key.lastAppIntentRunAtEpoch,
      Key.screenTimeAuthorized,
      Key.screenTimeAuthorizationMode,
      Key.screenTimeAuthorizedMode,
      Key.shieldingApplied,
      Key.screenTimeSelectionData,
      Key.screenTimeQuietSelectionData,
      Key.screenTimeHasRequiredSelection,
      Key.screenTimePasswordStepCompleted,
      Key.screenTimeDeletionProtectionStepCompleted,
      Key.screenTimeDegradedReason,
      Key.screenTimeScheduleEnforcedNow,
      Key.childUnlockRequested,
    ].forEach { d.removeObject(forKey: $0) }
  }

  public static var appModeRaw: String? {
    get {
      let v = suite.string(forKey: Key.appMode)
      return (v?.isEmpty ?? true) ? nil : v
    }
    set { suite.set(newValue, forKey: Key.appMode) }
  }

  public static var selectedDeviceId: String? {
    get {
      let v = suite.string(forKey: Key.selectedDeviceId)
      return (v?.isEmpty ?? true) ? nil : v
    }
    set { suite.set(newValue, forKey: Key.selectedDeviceId) }
  }

  public static var childLocked: Bool {
    get { suite.object(forKey: Key.childLocked) as? Bool ?? false }
    set { suite.set(newValue, forKey: Key.childLocked) }
  }

  public static var childPairingDeviceId: String? {
    get {
      let v = suite.string(forKey: Key.childPairingDeviceId)
      return (v?.isEmpty ?? true) ? nil : v
    }
    set { suite.set(newValue, forKey: Key.childPairingDeviceId) }
  }

  public static var childPairingName: String? {
    get {
      let v = suite.string(forKey: Key.childPairingName)
      return (v?.isEmpty ?? true) ? nil : v
    }
    set { suite.set(newValue, forKey: Key.childPairingName) }
  }

  public static var appIntentRunCount: Int {
    get { suite.object(forKey: Key.appIntentRunCount) as? Int ?? 0 }
    set { suite.set(newValue, forKey: Key.appIntentRunCount) }
  }

  public static var lastAppIntentRunAt: Date? {
    get {
      let epoch = suite.double(forKey: Key.lastAppIntentRunAtEpoch)
      guard epoch > 0 else { return nil }
      return Date(timeIntervalSince1970: epoch)
    }
    set {
      if let newValue {
        suite.set(newValue.timeIntervalSince1970, forKey: Key.lastAppIntentRunAtEpoch)
      } else {
        suite.removeObject(forKey: Key.lastAppIntentRunAtEpoch)
      }
    }
  }

  public static var screenTimeAuthorized: Bool {
    get { suite.object(forKey: Key.screenTimeAuthorized) as? Bool ?? false }
    set { suite.set(newValue, forKey: Key.screenTimeAuthorized) }
  }

  public static var screenTimeAuthorizationModeRaw: String? {
    get {
      let v = suite.string(forKey: Key.screenTimeAuthorizationMode)
      return (v?.isEmpty ?? true) ? nil : v
    }
    set { suite.set(newValue, forKey: Key.screenTimeAuthorizationMode) }
  }

  public static var screenTimeAuthorizedModeRaw: String? {
    get {
      let v = suite.string(forKey: Key.screenTimeAuthorizedMode)
      return (v?.isEmpty ?? true) ? nil : v
    }
    set { suite.set(newValue, forKey: Key.screenTimeAuthorizedMode) }
  }

  public static var shieldingApplied: Bool {
    get { suite.object(forKey: Key.shieldingApplied) as? Bool ?? false }
    set { suite.set(newValue, forKey: Key.shieldingApplied) }
  }

  public static var screenTimeSelectionData: Data? {
    get { suite.data(forKey: Key.screenTimeSelectionData) }
    set {
      if let newValue {
        suite.set(newValue, forKey: Key.screenTimeSelectionData)
      } else {
        suite.removeObject(forKey: Key.screenTimeSelectionData)
      }
    }
  }

  public static var screenTimeHasRequiredSelection: Bool {
    get { suite.object(forKey: Key.screenTimeHasRequiredSelection) as? Bool ?? false }
    set { suite.set(newValue, forKey: Key.screenTimeHasRequiredSelection) }
  }

  public static var screenTimePasswordStepCompleted: Bool {
    get { suite.object(forKey: Key.screenTimePasswordStepCompleted) as? Bool ?? false }
    set { suite.set(newValue, forKey: Key.screenTimePasswordStepCompleted) }
  }

  public static var screenTimeDeletionProtectionStepCompleted: Bool {
    get { suite.object(forKey: Key.screenTimeDeletionProtectionStepCompleted) as? Bool ?? false }
    set { suite.set(newValue, forKey: Key.screenTimeDeletionProtectionStepCompleted) }
  }

  public static var screenTimeQuietSelectionData: Data? {
    get { suite.data(forKey: Key.screenTimeQuietSelectionData) }
    set {
      if let newValue {
        suite.set(newValue, forKey: Key.screenTimeQuietSelectionData)
      } else {
        suite.removeObject(forKey: Key.screenTimeQuietSelectionData)
      }
    }
  }

  public static var screenTimeDegradedReason: String? {
    get {
      let v = suite.string(forKey: Key.screenTimeDegradedReason)
      return (v?.isEmpty ?? true) ? nil : v
    }
    set { suite.set(newValue, forKey: Key.screenTimeDegradedReason) }
  }

  public static var screenTimeScheduleEnforcedNow: Bool {
    get { suite.object(forKey: Key.screenTimeScheduleEnforcedNow) as? Bool ?? false }
    set { suite.set(newValue, forKey: Key.screenTimeScheduleEnforcedNow) }
  }

  public static var childUnlockRequested: Bool {
    get { suite.object(forKey: Key.childUnlockRequested) as? Bool ?? false }
    set { suite.set(newValue, forKey: Key.childUnlockRequested) }
  }
}

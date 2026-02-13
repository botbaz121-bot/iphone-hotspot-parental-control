import Foundation

public enum AppDefaults {
  private static let defaults = UserDefaults.standard

  private enum Key {
    static let onboardingCompleted = "hotspotParent.onboarding.completed"
    static let appleUserID = "hotspotParent.appleUserID"
    static let enrollmentToken = "hotspotParent.enrollmentToken"
    static let lastCheckInEpoch = "hotspotParent.lastCheckInEpoch"
    static let policyHotspotOff = "hotspotParent.policy.hotspotOff"
    static let apiBaseURL = "hotspotParent.api.baseURL"
    static let adminToken = "hotspotParent.api.adminToken"
    static let parentSessionToken = "hotspotParent.parent.sessionToken"
    static let deviceId = "hotspotParent.device.id"

    static let adsRemoved = "spotcheck.iap.adsRemoved"
  }

  public static var onboardingCompleted: Bool {
    get { defaults.object(forKey: Key.onboardingCompleted) as? Bool ?? false }
    set { defaults.set(newValue, forKey: Key.onboardingCompleted) }
  }

  public static var appleUserID: String? {
    get {
      let v = defaults.string(forKey: Key.appleUserID)
      return (v?.isEmpty ?? true) ? nil : v
    }
    set {
      defaults.set(newValue, forKey: Key.appleUserID)
    }
  }

  public static var enrollmentToken: String? {
    get {
      let v = defaults.string(forKey: Key.enrollmentToken)
      return (v?.isEmpty ?? true) ? nil : v
    }
    set {
      defaults.set(newValue, forKey: Key.enrollmentToken)
    }
  }

  public static var lastCheckIn: Date? {
    get {
      let epoch = defaults.double(forKey: Key.lastCheckInEpoch)
      guard epoch > 0 else { return nil }
      return Date(timeIntervalSince1970: epoch)
    }
    set {
      if let newValue {
        defaults.set(newValue.timeIntervalSince1970, forKey: Key.lastCheckInEpoch)
      } else {
        defaults.removeObject(forKey: Key.lastCheckInEpoch)
      }
    }
  }

  public static var policyHotspotOff: Bool {
    get { defaults.object(forKey: Key.policyHotspotOff) as? Bool ?? true }
    set { defaults.set(newValue, forKey: Key.policyHotspotOff) }
  }

  public static var apiBaseURL: String {
    get { defaults.string(forKey: Key.apiBaseURL) ?? "https://hotspot.abomb.co.uk" }
    set { defaults.set(newValue, forKey: Key.apiBaseURL) }
  }

  public static var adminToken: String? {
    get {
      let v = defaults.string(forKey: Key.adminToken)
      return (v?.isEmpty ?? true) ? nil : v
    }
    set { defaults.set(newValue, forKey: Key.adminToken) }
  }

  public static var parentSessionToken: String? {
    get {
      let v = defaults.string(forKey: Key.parentSessionToken)
      return (v?.isEmpty ?? true) ? nil : v
    }
    set { defaults.set(newValue, forKey: Key.parentSessionToken) }
  }

  public static var deviceId: String? {
    get {
      let v = defaults.string(forKey: Key.deviceId)
      return (v?.isEmpty ?? true) ? nil : v
    }
    set { defaults.set(newValue, forKey: Key.deviceId) }
  }

  // MARK: - IAP (stub)

  public static var adsRemoved: Bool {
    get { defaults.object(forKey: Key.adsRemoved) as? Bool ?? false }
    set { defaults.set(newValue, forKey: Key.adsRemoved) }
  }

  public static func resetAll() {
    defaults.removeObject(forKey: Key.onboardingCompleted)
    defaults.removeObject(forKey: Key.appleUserID)
    defaults.removeObject(forKey: Key.enrollmentToken)
    defaults.removeObject(forKey: Key.lastCheckInEpoch)
    defaults.removeObject(forKey: Key.policyHotspotOff)
    defaults.removeObject(forKey: Key.apiBaseURL)
    defaults.removeObject(forKey: Key.adminToken)
    defaults.removeObject(forKey: Key.parentSessionToken)
    defaults.removeObject(forKey: Key.deviceId)
    defaults.removeObject(forKey: Key.adsRemoved)
  }
}

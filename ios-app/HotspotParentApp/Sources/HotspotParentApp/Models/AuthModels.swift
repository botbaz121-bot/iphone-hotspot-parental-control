import Foundation

public struct AppleNativeSignInRequest: Encodable {
  public var identityToken: String
  public var email: String?
  public var fullName: String?

  public init(identityToken: String, email: String?, fullName: String?) {
    self.identityToken = identityToken
    self.email = email
    self.fullName = fullName
  }
}

public struct AppleNativeSignInResponse: Decodable {
  public var ok: Bool
  public var sessionToken: String

  public struct Parent: Decodable {
    public var id: String
    public var email: String?
    public var appleSubHash: String
  }

  public var parent: Parent
}

public struct DashboardResponse: Decodable {
  public var devices: [DashboardDevice]
}

public struct DashboardDevice: Decodable {
  public var id: String
  public var name: String
  public var device_token: String
  public var last_event_at: String?
  public var gap: Bool
  public var enforce: Bool
  public var inQuietHours: Bool
  public var shouldBeRunning: Bool
  public var gapMs: Int

  public var actions: Actions
  public struct Actions: Decodable {
    public var setHotspotOff: Bool
    public var setWifiOff: Bool
    public var setMobileDataOff: Bool
    public var rotatePassword: Bool
  }

  public var quietHours: QuietHours?
  public struct QuietHours: Decodable {
    public var start: String?
    public var end: String?
    public var tz: String?
  }
}

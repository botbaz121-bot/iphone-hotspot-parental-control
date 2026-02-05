import Foundation

public struct Healthz: Codable {
  public var ok: Bool
}

public struct Device: Codable, Identifiable {
  public var id: String
  public var name: String
  public var device_token: String
  public var created_at: String
  public var last_seen_at: String?
}

public struct CreateDeviceRequest: Codable {
  public var name: String?
}

public struct CreateDeviceResponse: Codable {
  public var id: String
  public var name: String
  public var deviceToken: String
  public var deviceSecret: String
}

public struct PairingCodeResponse: Codable {
  public var code: String
  public var expiresAt: Int
}

public struct DevicePolicy: Codable {
  public var enforce: Bool
  public var set_hotspot_off: Bool
  public var rotate_password: Bool
  public var quiet_start: String?
  public var quiet_end: String?
  public var tz: String?
  public var gap_ms: Int?
}

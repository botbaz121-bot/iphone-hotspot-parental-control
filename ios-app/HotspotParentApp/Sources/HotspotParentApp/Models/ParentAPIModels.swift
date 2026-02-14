import Foundation

public struct UpdatePolicyRequest: Encodable {
  public var enforce: Bool?
  public var setHotspotOff: Bool?
  public var rotatePassword: Bool?
  public var quietStart: String?
  public var quietEnd: String?
  public var tz: String?
  public var gapMinutes: Int?

  public init(
    enforce: Bool? = nil,
    setHotspotOff: Bool? = nil,
    rotatePassword: Bool? = nil,
    quietStart: String? = nil,
    quietEnd: String? = nil,
    tz: String? = nil,
    gapMinutes: Int? = nil
  ) {
    self.enforce = enforce
    self.setHotspotOff = setHotspotOff
    self.rotatePassword = rotatePassword
    self.quietStart = quietStart
    self.quietEnd = quietEnd
    self.tz = tz
    self.gapMinutes = gapMinutes
  }
}

public struct OkResponse: Decodable {
  public var ok: Bool
}

public struct UpdateDeviceRequest: Encodable {
  public var name: String?
  public var icon: String?

  public init(name: String? = nil, icon: String? = nil) {
    self.name = name
    self.icon = icon
  }
}

public struct EventsResponse: Decodable {
  public var events: [DeviceEventRow]
}

public struct DeviceEventRow: Decodable {
  public var id: String
  public var ts: Int
  public var trigger: String
  public var shortcut_version: String?
  public var actions_attempted: [String]
  public var result_ok: Int
  public var result_errors: [String]
  public var created_at: String
}

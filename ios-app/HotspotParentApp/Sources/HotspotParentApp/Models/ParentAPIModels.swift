import Foundation

public struct UpdatePolicyRequest: Encodable {
  public var setHotspotOff: Bool?
  public var rotatePassword: Bool?
  public var setWifiOff: Bool?
  public var setMobileDataOff: Bool?
  public var quietStart: String?
  public var quietEnd: String?
  public var quietDays: [String: QuietDayWindow]?
  public var tz: String?
  public var gapMinutes: Int?

  public struct QuietDayWindow: Encodable {
    public var start: String
    public var end: String

    public init(start: String, end: String) {
      self.start = start
      self.end = end
    }
  }

  public init(
    setHotspotOff: Bool? = nil,
    rotatePassword: Bool? = nil,
    setWifiOff: Bool? = nil,
    setMobileDataOff: Bool? = nil,
    quietStart: String? = nil,
    quietEnd: String? = nil,
    quietDays: [String: QuietDayWindow]? = nil,
    tz: String? = nil,
    gapMinutes: Int? = nil
  ) {
    self.setHotspotOff = setHotspotOff
    self.rotatePassword = rotatePassword
    self.setWifiOff = setWifiOff
    self.setMobileDataOff = setMobileDataOff
    self.quietStart = quietStart
    self.quietEnd = quietEnd
    self.quietDays = quietDays
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

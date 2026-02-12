import Foundation

// MARK: - Shared app models (v1A)

public enum AppMode: String, Codable, CaseIterable {
  case parent
  case childSetup
}

public enum DeviceStatus: String, Codable {
  case ok
  case stale
  case setup
}

public struct QuietHours: Codable, Equatable {
  public var start: String? // "HH:mm"
  public var end: String?
  public var tz: String?

  public init(start: String? = nil, end: String? = nil, tz: String? = nil) {
    self.start = start
    self.end = end
    self.tz = tz
  }
}

public struct DevicePolicyView: Codable, Equatable {
  public var enforce: Bool
  public var hotspotOff: Bool
  public var rotatePassword: Bool
  public var quiet: QuietHours?
  public var gapMs: Int

  public init(
    enforce: Bool = true,
    hotspotOff: Bool = true,
    rotatePassword: Bool = false,
    quiet: QuietHours? = nil,
    gapMs: Int = 10_000
  ) {
    self.enforce = enforce
    self.hotspotOff = hotspotOff
    self.rotatePassword = rotatePassword
    self.quiet = quiet
    self.gapMs = gapMs
  }
}

public struct DeviceEvent: Identifiable, Codable, Equatable {
  public var id: String
  public var ts: Date
  public var trigger: String
  public var actionsAttempted: [String]
  public var ok: Bool
  public var errors: [String]

  public init(
    id: String,
    ts: Date,
    trigger: String,
    actionsAttempted: [String] = [],
    ok: Bool,
    errors: [String] = []
  ) {
    self.id = id
    self.ts = ts
    self.trigger = trigger
    self.actionsAttempted = actionsAttempted
    self.ok = ok
    self.errors = errors
  }
}

public struct ManagedDevice: Identifiable, Codable, Equatable {
  public var id: String
  public var name: String
  public var lastSeenAt: Date?
  public var lastEventAt: Date?
  public var status: DeviceStatus
  public var policy: DevicePolicyView
  public var recentEvents: [DeviceEvent]

  public init(
    id: String,
    name: String,
    lastSeenAt: Date? = nil,
    lastEventAt: Date? = nil,
    status: DeviceStatus = .setup,
    policy: DevicePolicyView = .init(),
    recentEvents: [DeviceEvent] = []
  ) {
    self.id = id
    self.name = name
    self.lastSeenAt = lastSeenAt
    self.lastEventAt = lastEventAt
    self.status = status
    self.policy = policy
    self.recentEvents = recentEvents
  }
}

public struct HotspotConfig: Codable, Equatable {
  public var apiBaseURL: String
  public var deviceToken: String
  public var deviceSecret: String

  public init(apiBaseURL: String, deviceToken: String, deviceSecret: String) {
    self.apiBaseURL = apiBaseURL
    self.deviceToken = deviceToken
    self.deviceSecret = deviceSecret
  }
}

public struct Healthz: Codable {
  public var ok: Bool
}

// MARK: - Backend admin/dev models (existing)

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

// MARK: - Public pairing endpoint

public struct PairDeviceRequest: Codable {
  public var code: String

  public init(code: String) {
    self.code = code
  }
}

public struct PairDeviceResponse: Codable {
  public var deviceId: String
  public var name: String
  public var deviceToken: String
  public var deviceSecret: String
}

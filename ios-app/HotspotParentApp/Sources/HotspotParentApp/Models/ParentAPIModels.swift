import Foundation

public struct UpdatePolicyRequest: Encodable {
  public var activateProtection: Bool?
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
    public var dailyLimitMinutes: Int?

    public init(start: String, end: String, dailyLimitMinutes: Int? = nil) {
      self.start = start
      self.end = end
      self.dailyLimitMinutes = dailyLimitMinutes
    }
  }

  public init(
    activateProtection: Bool? = nil,
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
    self.activateProtection = activateProtection
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

public struct ExtraTimeCreateRequest: Encodable {
  public var minutes: Int
  public var reason: String?

  public init(minutes: Int, reason: String? = nil) {
    self.minutes = minutes
    self.reason = reason
  }
}

public struct ExtraTimeCreateResponse: Decodable {
  public var ok: Bool
  public var requestId: String
  public var status: String?
}

public struct ExtraTimeDecisionRequest: Encodable {
  public var decision: String
  public var grantedMinutes: Int?

  public init(decision: String, grantedMinutes: Int? = nil) {
    self.decision = decision
    self.grantedMinutes = grantedMinutes
  }
}

public struct PushRegisterRequest: Encodable {
  public var deviceToken: String
  public var platform: String

  public init(deviceToken: String, platform: String = "ios") {
    self.deviceToken = deviceToken
    self.platform = platform
  }
}

public struct ExtraTimeRequestsResponse: Decodable {
  public var requests: [ExtraTimeRequestRow]
}

public struct ExtraTimeRequestRow: Decodable {
  public var id: String
  public var deviceId: String
  public var deviceName: String
  public var requestedMinutes: Int
  public var reason: String?
  public var status: String
  public var requestedAt: Int
  public var resolvedAt: Int?
  public var resolvedBy: String?
  public var grantedMinutes: Int?
  public var startsAt: Int?
  public var endsAt: Int?
}

public struct HouseholdMembersResponse: Decodable {
  public var members: [HouseholdMember]
}

public struct HouseholdMember: Decodable {
  public var id: String
  public var parentId: String
  public var email: String?
  public var displayName: String?
  public var role: String
  public var status: String
  public var createdAt: String
}

public struct HouseholdInvitesResponse: Decodable {
  public var invites: [HouseholdInvite]
}

public struct HouseholdInvite: Decodable {
  public var id: String
  public var email: String?
  public var inviteName: String?
  public var token: String
  public var code: String
  public var status: String
  public var expiresAt: Int
  public var acceptedAt: Int?
  public var revokedAt: Int?
  public var createdAt: String
  public var invitedByEmail: String?
}

public struct HouseholdInviteAcceptCodeRequest: Encodable {
  public var code: String

  public init(code: String) {
    self.code = code
  }
}

public struct HouseholdInviteRenameRequest: Encodable {
  public var inviteName: String

  public init(inviteName: String) {
    self.inviteName = inviteName
  }
}

public struct ParentMeResponse: Decodable {
  public struct Parent: Decodable {
    public var id: String
    public var email: String?
    public var displayName: String?
  }

  public struct Household: Decodable {
    public var id: String
    public var name: String?
    public var role: String
  }

  public var ok: Bool
  public var parent: Parent
  public var household: Household
}

public struct ParentProfileUpdateRequest: Encodable {
  public var displayName: String

  public init(displayName: String) {
    self.displayName = displayName
  }
}

public struct HouseholdsResponse: Decodable {
  public var ok: Bool
  public var households: [ParentHousehold]
  public var activeHouseholdId: String
}

public struct ParentHousehold: Decodable {
  public var id: String
  public var name: String?
  public var role: String
  public var status: String
  public var active: Bool
}

public struct SetActiveHouseholdRequest: Encodable {
  public var householdId: String

  public init(householdId: String) {
    self.householdId = householdId
  }
}

public struct CreateHouseholdInviteRequest: Encodable {
  public var email: String?
  public var inviteName: String?

  public init(email: String? = nil, inviteName: String? = nil) {
    self.email = email
    self.inviteName = inviteName
  }
}

public struct CreateHouseholdInviteResponse: Decodable {
  public struct Invite: Decodable {
    public var token: String
    public var code: String
    public var email: String?
    public var inviteName: String?
    public var expiresAt: Int
  }

  public var ok: Bool
  public var invite: Invite
}

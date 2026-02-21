import Foundation

public final class HotspotAPIClient {
  public let api: API

  public init(api: API) {
    self.api = api
  }

  private func parentHeaders() -> [String: String] {
    guard let token = api.parentSessionToken, !token.isEmpty else { return [:] }
    return ["Authorization": "Bearer \(token)"]
  }

  private func adminHeaders() -> [String: String] {
    guard let token = api.adminToken, !token.isEmpty else { return [:] }
    return ["Authorization": "Bearer \(token)"]
  }

  private func parentOrAdminHeaders() -> [String: String] {
    let p = parentHeaders()
    if !p.isEmpty { return p }
    return adminHeaders()
  }

  public func healthz() async throws -> Healthz {
    try await HTTP.getJSON(api.url("/healthz"))
  }

  // MARK: - Auth

  public func signInWithAppleNative(identityToken: String, email: String?, fullName: String?) async throws -> AppleNativeSignInResponse {
    let req = AppleNativeSignInRequest(identityToken: identityToken, email: email, fullName: fullName)
    return try await HTTP.postJSON(api.url("/auth/apple/native"), body: req)
  }

  // MARK: - Public endpoints (v1A)

  public func pairDevice(code: String) async throws -> PairDeviceResponse {
    try await HTTP.postJSON(api.url("/pair"), body: PairDeviceRequest(code: code))
  }

  // MARK: - Parent API (v1B)

  public func dashboard() async throws -> DashboardResponse {
    try await HTTP.getJSON(api.url("/api/dashboard"), headers: parentOrAdminHeaders())
  }

  public func me() async throws -> ParentMeResponse {
    try await HTTP.getJSON(api.url("/api/me"), headers: parentHeaders())
  }

  public func updateMyProfile(displayName: String) async throws {
    let req = ParentProfileUpdateRequest(displayName: displayName)
    let _: OkResponse = try await HTTP.patchJSON(api.url("/api/me/profile"), body: req, headers: parentHeaders())
  }

  public func householdMembers() async throws -> HouseholdMembersResponse {
    try await HTTP.getJSON(api.url("/api/household/members"), headers: parentHeaders())
  }

  public func householdInvites() async throws -> HouseholdInvitesResponse {
    try await HTTP.getJSON(api.url("/api/household/invites"), headers: parentHeaders())
  }

  public func acceptInviteCode(_ code: String) async throws {
    let req = HouseholdInviteAcceptCodeRequest(code: code)
    let _: OkResponse = try await HTTP.postJSON(api.url("/api/household/invite-code/accept"), body: req, headers: parentHeaders())
  }

  public func renameInvite(inviteId: String, inviteName: String) async throws {
    let req = HouseholdInviteRenameRequest(inviteName: inviteName)
    let _: OkResponse = try await HTTP.patchJSON(api.url("/api/household/invites/\(inviteId)"), body: req, headers: parentHeaders())
  }

  public func deleteInvite(inviteId: String) async throws {
    let _: OkResponse = try await HTTP.deleteJSON(api.url("/api/household/invites/\(inviteId)"), headers: parentHeaders())
  }

  public func deleteHouseholdMember(memberId: String) async throws {
    let _: OkResponse = try await HTTP.deleteJSON(api.url("/api/household/members/\(memberId)"), headers: parentHeaders())
  }

  public func listDevices() async throws -> [Device] {
    try await HTTP.getJSON(api.url("/api/devices"), headers: parentOrAdminHeaders())
  }

  public func createDevice(name: String) async throws -> CreateDeviceResponse {
    try await HTTP.postJSON(api.url("/api/devices"), body: CreateDeviceRequest(name: name), headers: parentOrAdminHeaders())
  }

  public func createPairingCode(deviceId: String) async throws -> PairingCodeResponse {
    try await HTTP.postJSON(api.url("/api/devices/\(deviceId)/pairing-code"), body: [String: String](), headers: parentOrAdminHeaders())
  }

  public func updateDevice(deviceId: String, patch: UpdateDeviceRequest) async throws {
    let _: OkResponse = try await HTTP.patchJSON(api.url("/api/devices/\(deviceId)"), body: patch, headers: parentOrAdminHeaders())
  }

  public func deleteDevice(deviceId: String) async throws {
    let _: OkResponse = try await HTTP.deleteJSON(api.url("/api/devices/\(deviceId)"), headers: parentOrAdminHeaders())
  }

  public func updatePolicy(deviceId: String, patch: UpdatePolicyRequest) async throws {
    let _: OkResponse = try await HTTP.patchJSON(api.url("/api/devices/\(deviceId)/policy"), body: patch, headers: parentOrAdminHeaders())
  }

  public func events(deviceId: String) async throws -> EventsResponse {
    try await HTTP.getJSON(api.url("/api/devices/\(deviceId)/events"), headers: parentOrAdminHeaders())
  }

  public func registerParentPushToken(_ deviceToken: String) async throws {
    let req = PushRegisterRequest(deviceToken: deviceToken, platform: "ios")
    let _: OkResponse = try await HTTP.postJSON(api.url("/api/push/register"), body: req, headers: parentHeaders())
  }

  public func registerChildPushToken(deviceSecret: String, deviceToken: String) async throws {
    let req = PushRegisterRequest(deviceToken: deviceToken, platform: "ios")
    let headers: [String: String] = ["Authorization": "Bearer \(deviceSecret)"]
    let _: OkResponse = try await HTTP.postJSON(api.url("/api/push/register-child"), body: req, headers: headers)
  }

  public func requestExtraTime(deviceSecret: String, minutes: Int, reason: String?) async throws -> ExtraTimeCreateResponse {
    var headers: [String: String] = ["Authorization": "Bearer \(deviceSecret)"]
    headers["Content-Type"] = "application/json"
    let req = ExtraTimeCreateRequest(minutes: minutes, reason: reason)
    return try await HTTP.postJSON(api.url("/extra-time/request"), body: req, headers: headers)
  }

  public func grantExtraTime(deviceId: String, minutes: Int, reason: String? = nil) async throws -> ExtraTimeCreateResponse {
    let req = ExtraTimeCreateRequest(minutes: minutes, reason: reason)
    return try await HTTP.postJSON(api.url("/api/devices/\(deviceId)/extra-time/grant"), body: req, headers: parentOrAdminHeaders())
  }

  public func decideExtraTimeRequest(requestId: String, approve: Bool, grantedMinutes: Int?) async throws -> OkResponse {
    let req = ExtraTimeDecisionRequest(decision: approve ? "approve" : "deny", grantedMinutes: grantedMinutes)
    return try await HTTP.postJSON(api.url("/api/extra-time/requests/\(requestId)/decision"), body: req, headers: parentOrAdminHeaders())
  }

  public func extraTimeRequests(status: String = "pending", deviceId: String? = nil) async throws -> ExtraTimeRequestsResponse {
    var parts: [String] = []
    parts.append("status=\(status.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? status)")
    if let deviceId, !deviceId.isEmpty {
      parts.append("deviceId=\(deviceId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deviceId)")
    }
    let path = "/api/extra-time/requests" + (parts.isEmpty ? "" : "?\(parts.joined(separator: "&"))")
    return try await HTTP.getJSON(api.url(path), headers: parentOrAdminHeaders())
  }
}

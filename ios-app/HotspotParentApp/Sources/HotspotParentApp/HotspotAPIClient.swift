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

  public func listDevices() async throws -> [Device] {
    try await HTTP.getJSON(api.url("/api/devices"), headers: parentOrAdminHeaders())
  }

  public func createDevice(name: String?) async throws -> CreateDeviceResponse {
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
}

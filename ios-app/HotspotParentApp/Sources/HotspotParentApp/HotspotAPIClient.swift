import Foundation

public final class HotspotAPIClient {
  public let api: API

  public init(api: API) {
    self.api = api
  }

  private func adminHeaders() -> [String: String] {
    guard let token = api.adminToken, !token.isEmpty else { return [:] }
    return ["Authorization": "Bearer \(token)"]
  }

  public func healthz() async throws -> Healthz {
    try await HTTP.getJSON(api.url("/healthz"))
  }

  // MARK: - Public endpoints (v1A)

  public func pairDevice(code: String, name: String?) async throws -> PairDeviceResponse {
    try await HTTP.postJSON(api.url("/pair"), body: PairDeviceRequest(code: code, name: name))
  }

  // MARK: - Admin (dev only)

  public func listDevices() async throws -> [Device] {
    try await HTTP.getJSON(api.url("/api/devices"), headers: adminHeaders())
  }

  public func createDevice(name: String?) async throws -> CreateDeviceResponse {
    try await HTTP.postJSON(api.url("/api/devices"), body: CreateDeviceRequest(name: name), headers: adminHeaders())
  }

  public func createPairingCode(deviceId: String) async throws -> PairingCodeResponse {
    try await HTTP.postJSON(api.url("/api/devices/\(deviceId)/pairing-code"), body: [String: String](), headers: adminHeaders())
  }
}

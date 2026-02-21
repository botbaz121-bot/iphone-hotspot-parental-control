import Foundation

public struct API {
  public var baseURL: URL
  public var parentSessionToken: String?
  public var adminToken: String? // dev only; don't ship to prod

  public init(baseURL: URL, parentSessionToken: String? = nil, adminToken: String? = nil) {
    self.baseURL = baseURL
    self.parentSessionToken = parentSessionToken
    self.adminToken = adminToken
  }

  public func url(_ path: String) -> URL {
    if path.hasPrefix("http://") || path.hasPrefix("https://") {
      return URL(string: path)!
    }
    let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
    // Keep query strings intact (appendingPathComponent would escape "?" to "%3F").
    if normalized.contains("?") {
      let base = baseURL.absoluteString.hasSuffix("/") ? baseURL.absoluteString : baseURL.absoluteString + "/"
      return URL(string: base + normalized)!
    }
    return baseURL.appendingPathComponent(normalized)
  }
}

public enum APIError: Error, CustomStringConvertible {
  case invalidResponse
  case httpStatus(Int, String)

  public var description: String {
    switch self {
      case .invalidResponse: return "invalidResponse"
      case .httpStatus(let code, let body): return "httpStatus(\(code)): \(body)"
    }
  }

  public var userMessage: String {
    switch self {
      case .invalidResponse:
        return "Couldn’t reach the server. Please try again."
      case .httpStatus(let code, let body):
        // Try to parse {"error":"..."}
        let err = APIError.parseErrorCode(body)

        if err == "invalid_code" || err == "invalid_pairing_code" {
          return "That pairing code is invalid or expired. Ask the parent phone to generate a new one."
        }
        if err == "invite_not_pending" {
          return "That invite is no longer pending."
        }
        if err == "invite_expired" {
          return "That invite code has expired. Ask for a new one."
        }
        if err == "invite_revoked" {
          return "That invite was cancelled."
        }
        if err == "owner_required" {
          return "Only the household owner can remove a parent."
        }
        if err == "cannot_delete_owner" {
          return "The household owner can’t be removed."
        }
        if code == 401 {
          return "You’re not authorized. Please sign in again and try."
        }
        if code == 404 {
          return "Not found. Please check the code and try again."
        }
        return "Request failed (\(code)). Please try again."
    }
  }

  private static func parseErrorCode(_ body: String) -> String? {
    guard let data = body.data(using: .utf8) else { return nil }
    if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      if let e = obj["error"] as? String { return e }
    }
    return nil
  }
}

public struct HTTP {
  public static func getJSON<T: Decodable>(_ url: URL, headers: [String: String] = [:]) async throws -> T {
    var req = URLRequest(url: url)
    req.httpMethod = "GET"
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse else { throw APIError.invalidResponse }
    if !(200..<300).contains(http.statusCode) {
      let body = String(data: data, encoding: .utf8) ?? ""
      throw APIError.httpStatus(http.statusCode, body)
    }
    return try JSONDecoder().decode(T.self, from: data)
  }

  public static func postJSON<T: Decodable>(_ url: URL, body: Encodable, headers: [String: String] = [:]) async throws -> T {
    try await requestJSON(url, method: "POST", body: body, headers: headers)
  }

  public static func patchJSON<T: Decodable>(_ url: URL, body: Encodable, headers: [String: String] = [:]) async throws -> T {
    try await requestJSON(url, method: "PATCH", body: body, headers: headers)
  }

  public static func deleteJSON<T: Decodable>(_ url: URL, headers: [String: String] = [:]) async throws -> T {
    var req = URLRequest(url: url)
    req.httpMethod = "DELETE"
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse else { throw APIError.invalidResponse }
    if !(200..<300).contains(http.statusCode) {
      let body = String(data: data, encoding: .utf8) ?? ""
      throw APIError.httpStatus(http.statusCode, body)
    }
    return try JSONDecoder().decode(T.self, from: data)
  }

  private static func requestJSON<T: Decodable>(_ url: URL, method: String, body: Encodable, headers: [String: String]) async throws -> T {
    var req = URLRequest(url: url)
    req.httpMethod = method
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

    req.httpBody = try JSONEncoder().encode(AnyEncodable(body))

    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse else { throw APIError.invalidResponse }
    if !(200..<300).contains(http.statusCode) {
      let body = String(data: data, encoding: .utf8) ?? ""
      throw APIError.httpStatus(http.statusCode, body)
    }
    return try JSONDecoder().decode(T.self, from: data)
  }
}

public struct AnyEncodable: Encodable {
  private let encodeFn: (Encoder) throws -> Void
  public init(_ value: Encodable) { self.encodeFn = value.encode }
  public func encode(to encoder: Encoder) throws { try encodeFn(encoder) }
}

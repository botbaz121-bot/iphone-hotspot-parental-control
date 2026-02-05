import Foundation

public struct API {
  public var baseURL: URL
  public var adminToken: String? // for admin endpoints; don't ship to prod

  public init(baseURL: URL, adminToken: String? = nil) {
    self.baseURL = baseURL
    self.adminToken = adminToken
  }

  public func url(_ path: String) -> URL {
    if path.hasPrefix("http://") || path.hasPrefix("https://") {
      return URL(string: path)!
    }
    return baseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
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
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
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

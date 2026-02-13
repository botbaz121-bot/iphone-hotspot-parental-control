import Foundation

#if canImport(AppIntents)
import AppIntents
#endif

/// App Intent used by the Shortcut to fetch the current policy from the backend.
///
/// Rationale: Some iOS/Shortcuts setups treat Web "Get Contents of URL" as an inter-app operation
/// and prompt/block when the default browser is Chrome. Performing the network call inside the app
/// avoids any Chrome handoff and keeps secrets out of Shortcuts variables.
#if canImport(AppIntents)
public struct FetchHotspotPolicyIntent: AppIntent {
  public static var title: LocalizedStringResource = "Fetch Hotspot Policy"
  public static var description = IntentDescription(
    "Fetches the current policy from the backend and returns it as JSON for the SpotCheck Shortcut."
  )

  public init() {}

  public func perform() async throws -> some IntentResult & ReturnsValue<String> {
    // Telemetry
    SharedDefaults.appIntentRunCount += 1
    SharedDefaults.lastAppIntentRunAt = Date()

    let cfg = try KeychainStore.getCodable(HotspotConfig.self, account: KeychainAccounts.hotspotConfig)

    guard let cfg else {
      let payload: [String: String] = [
        "error": "missing_config",
        "help": "Open the SpotCheck app on the child phone and pair it first."
      ]
      let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
      let json = String(data: data, encoding: .utf8) ?? "{\"error\":\"missing_config\"}"
      return .result(value: json)
    }

    guard let base = URL(string: cfg.apiBaseURL) else {
      return .result(value: "{\"error\":\"invalid_base_url\"}")
    }

    let url = base.appendingPathComponent("policy")

    var req = URLRequest(url: url)
    req.httpMethod = "GET"
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    // Backend supports shortcut-friendly bearer auth where bearer == device_secret
    req.setValue("Bearer \(cfg.deviceSecret)", forHTTPHeaderField: "Authorization")
    // Extra: browser-like UA can help with some WAF/CDN rules
    req.setValue("SpotCheckShortcut/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

    let (data, resp) = try await URLSession.shared.data(for: req)
    let code = (resp as? HTTPURLResponse)?.statusCode ?? 0

    // Always return JSON string; if backend returned HTML, surface that as an error.
    if !(200...299).contains(code) {
      let body = String(data: data, encoding: .utf8) ?? ""
      let payload: [String: Any] = [
        "error": "http_\(code)",
        "body": body
      ]
      let out = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
      return .result(value: String(data: out, encoding: .utf8) ?? "{\"error\":\"http_\(code)\"}")
    }

    // Best effort: verify it's JSON-ish (starts with { or [)
    let trimmed = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !(trimmed.hasPrefix("{") || trimmed.hasPrefix("[")) {
      let payload: [String: Any] = [
        "error": "non_json_response",
        "body": trimmed
      ]
      let out = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
      return .result(value: String(data: out, encoding: .utf8) ?? "{\"error\":\"non_json_response\"}")
    }

    return .result(value: trimmed)
  }
}

// Note: We intentionally do NOT provide App Shortcuts suggestions here.
// The intents remain callable from Shortcuts without this, and it avoids
// AppIntents metadata export errors on some toolchains.
#endif

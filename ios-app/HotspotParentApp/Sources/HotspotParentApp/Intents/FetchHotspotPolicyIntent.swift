import Foundation

#if canImport(AppIntents)
import AppIntents
#endif
#if canImport(UserNotifications)
import UserNotifications
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

  private static let cacheKey = "last_policy_json"
  private static let cacheTsKey = "last_policy_cached_at"
  private static let dailyLimitWarnKey = "daily_limit_warned_day_key"

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
      let enriched = Self.appendScreenTimeAuthMode(json) ?? json
      return .result(value: enriched)
    }

    guard let base = URL(string: cfg.apiBaseURL) else {
      let payload: [String: Any] = ["error": "invalid_base_url"]
      let raw = (try? JSONSerialization.data(withJSONObject: payload, options: []))
        .flatMap { String(data: $0, encoding: .utf8) }
        ?? "{\"error\":\"invalid_base_url\"}"
      let out = Self.appendScreenTimeAuthMode(raw) ?? raw
      return .result(value: out)
    }

    let url = base.appendingPathComponent("policy")

    do {
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
        throw NSError(domain: "SpotCheck", code: code, userInfo: [NSLocalizedDescriptionKey: body])
      }

      // Best effort: verify it's JSON-ish (starts with { or [)
      let trimmed = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if !(trimmed.hasPrefix("{") || trimmed.hasPrefix("[")) {
        throw NSError(domain: "SpotCheck", code: 0, userInfo: [NSLocalizedDescriptionKey: trimmed])
      }

      // Cache last-known-good policy strictly.
      SharedDefaults.suite.set(trimmed, forKey: Self.cacheKey)
      SharedDefaults.suite.set(Date().timeIntervalSince1970, forKey: Self.cacheTsKey)
      await Self.maybeNotifyDailyLimitFiveMinutesRemaining(policyJSON: trimmed, deviceToken: cfg.deviceToken)

      let out = Self.appendScreenTimeAuthMode(trimmed) ?? trimmed
      return .result(value: out)
    } catch {
      // Strict offline: fall back to cached policy if present.
      if let cached = SharedDefaults.suite.string(forKey: Self.cacheKey) {
        var obj: [String: Any] = [:]
        if let d = cached.data(using: .utf8),
           let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
          obj = o
        }
        obj["offline"] = true
        let ts = SharedDefaults.suite.double(forKey: Self.cacheTsKey)
        if ts > 0 {
          obj["cachedAt"] = Int(ts * 1000)
        }
        Self.addScreenTimeAuthMode(to: &obj)

        let out = (try? JSONSerialization.data(withJSONObject: obj, options: []))
          .flatMap { String(data: $0, encoding: .utf8) }
          ?? cached

        await Self.maybeNotifyDailyLimitFiveMinutesRemaining(policyJSON: out, deviceToken: cfg.deviceToken)

        return .result(value: out)
      }

      let payload: [String: Any] = [
        "error": "offline_no_cache",
        "help": "No internet connection and no cached policy yet. Connect to the internet once to cache the policy.",
        "detail": String(describing: error)
      ]
      var enriched = payload
      Self.addScreenTimeAuthMode(to: &enriched)
      let out = try JSONSerialization.data(withJSONObject: enriched, options: [.prettyPrinted])
      return .result(value: String(data: out, encoding: .utf8) ?? "{\"error\":\"offline_no_cache\"}")
    }
  }

  private static func appendScreenTimeAuthMode(_ rawJSON: String) -> String? {
    guard let data = rawJSON.data(using: .utf8),
          var obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }
    Self.addScreenTimeAuthMode(to: &obj)
    guard let out = try? JSONSerialization.data(withJSONObject: obj, options: []) else { return nil }
    return String(data: out, encoding: .utf8)
  }

  private static func addScreenTimeAuthMode(to obj: inout [String: Any]) {
    let mode = SharedDefaults.screenTimeAuthorizationModeRaw ?? "individual"
    obj["screenTimeAuthorizationMode"] = mode
    obj["screenTimeIsIndividualMode"] = (mode == "individual")
  }

  private static func maybeNotifyDailyLimitFiveMinutesRemaining(policyJSON: String, deviceToken: String) async {
    #if canImport(UserNotifications)
    guard let data = policyJSON.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let daily = obj["dailyLimit"] as? [String: Any]
    else {
      return
    }

    let remaining = intValue(daily["remainingMinutes"])
    let limit = intValue(daily["limitMinutes"])
    let used = intValue(daily["usedMinutes"])
    let dayKey = (daily["dayKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let reached = (daily["reached"] as? Bool) ?? false
    let enforce = (obj["enforce"] as? Bool) ?? false

    guard limit > 0, used >= 0, remaining > 0, remaining <= 5, !reached, !enforce, let dayKey, !dayKey.isEmpty else {
      return
    }

    let dedupeKey = "\(deviceToken)|\(dayKey)"
    let alreadyWarned = SharedDefaults.suite.string(forKey: Self.dailyLimitWarnKey)
    if alreadyWarned == dedupeKey { return }

    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
      return
    }

    let content = UNMutableNotificationContent()
    content.title = "SpotChecker"
    content.body = "5 minutes left today (\(used)m of \(limit)m used)."
    content.sound = .default

    let req = UNNotificationRequest(
      identifier: "spotchecker.daily-limit.\(dayKey)",
      content: content,
      trigger: nil
    )
    do {
      try await center.add(req)
      SharedDefaults.suite.set(dedupeKey, forKey: Self.dailyLimitWarnKey)
    } catch {
      // best effort
    }
    #endif
  }

  private static func intValue(_ any: Any?) -> Int {
    if let v = any as? Int { return v }
    if let v = any as? Double { return Int(v) }
    if let v = any as? NSNumber { return v.intValue }
    return -1
  }
}

// Note: We intentionally do NOT provide App Shortcuts suggestions here.
// The intents remain callable from Shortcuts without this, and it avoids
// AppIntents metadata export errors on some toolchains.
#endif

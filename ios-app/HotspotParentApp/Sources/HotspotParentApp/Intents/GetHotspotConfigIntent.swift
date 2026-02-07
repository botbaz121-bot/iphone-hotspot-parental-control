import Foundation

#if canImport(AppIntents)
import AppIntents
#endif

#if canImport(SwiftUI)
import SwiftUI
#endif

/// App Intent used by the Shortcut to fetch backend credentials/config.
///
/// v1 contract: returns a JSON string with keys:
/// - apiBaseURL
/// - deviceToken
/// - deviceSecret
#if canImport(AppIntents)
public struct GetHotspotConfigIntent: AppIntent {
  public static var title: LocalizedStringResource = "Get Hotspot Config"
  public static var description = IntentDescription(
    "Returns the backend config (base URL + device credentials) as JSON for the SpotCheck Shortcut."
  )

  public init() {}

  public func perform() async throws -> some IntentResult & ReturnsValue<String> {
    // Record telemetry in the shared app group defaults.
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

    let payload: [String: String] = [
      "apiBaseURL": cfg.apiBaseURL,
      "deviceToken": cfg.deviceToken,
      "deviceSecret": cfg.deviceSecret,
    ]
    let data = try JSONSerialization.data(withJSONObject: payload, options: [])
    let json = String(data: data, encoding: .utf8) ?? "{}"
    return .result(value: json)
  }
}

/// Optional App Shortcuts suggestions (surface in Shortcuts app).
public struct SpotCheckAppShortcuts: AppShortcutsProvider {
  public static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: GetHotspotConfigIntent(),
      phrases: ["Get Hotspot config from \(.applicationName)", "SpotCheck config"],
      shortTitle: "Get Config",
      systemImageName: "key.fill"
    )
  }
}
#endif

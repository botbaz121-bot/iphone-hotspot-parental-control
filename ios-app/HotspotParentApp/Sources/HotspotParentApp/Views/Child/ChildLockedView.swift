import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

public struct ChildLockedView: View {
  @EnvironmentObject private var model: AppModel
  @State private var signInError: String?
  @State private var showError = false
  @State private var policyBusy = false
  @State private var statusMessage: String = "Checking protection status..."
  @State private var extraTimeMinutes: Int = 15
  @State private var extraTimeBusy = false
  @State private var extraTimeMessage: String?
  @State private var didInitialAutoUpdate = false

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        headerCard
        if canRequestExtraTime {
          extraTimeCard
        }
      }
      .padding(.top, 22)
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
    .alert("Unlock failed", isPresented: $showError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(signInError ?? "Unknown error")
    }
    .onAppear {
      statusMessage = friendlyProtectionMessage()
      if !didInitialAutoUpdate {
        didInitialAutoUpdate = true
        Task { await refreshPolicy() }
      }
    }
  }

  private var headerCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("SpotChecker")
            .font(.largeTitle.bold())
          Text(statusMessage)
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        }

        Spacer()

        Text("Ready")
          .font(.system(size: 13, weight: .medium))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.green.opacity(0.18))
          .foregroundStyle(.green)
          .clipShape(RoundedRectangle(cornerRadius: 999))
      }

      Button {
        Task { await unlockWithApple() }
      } label: {
        Label("Unlock", systemImage: "arrow.right")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)

      Button {
        Task { await refreshPolicy() }
      } label: {
        Label(policyBusy ? "Refreshing Status…" : "Refresh Status", systemImage: "arrow.clockwise")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .disabled(policyBusy)

    }
    .padding(18)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  private var extraTimeCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Need more time?")
        .font(.system(size: 16, weight: .semibold))
      Text("Request extra time from parent.")
        .font(.system(size: 14))
        .foregroundStyle(.secondary)

      HStack(spacing: 10) {
        Text("Amount")
          .font(.system(size: 15, weight: .semibold))
        Spacer()
        Picker("Minutes", selection: $extraTimeMinutes) {
          ForEach(Array(stride(from: 5, through: 120, by: 5)), id: \.self) { m in
            Text("\(m) min").tag(m)
          }
        }
        .pickerStyle(.menu)
      }

      Button {
        Task { await requestExtraTime() }
      } label: {
        Label(extraTimeBusy ? "Requesting..." : "Request extra time", systemImage: "clock.badge.questionmark")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .disabled(extraTimeBusy)

      if let extraTimeMessage {
        Text(extraTimeMessage)
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
          .italic()
      }
    }
    .padding(18)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  @MainActor
  private func unlockWithApple() async {
    signInError = nil

    // If already signed in, no need to show the dialog.
    if model.isSignedIn {
      model.unlockChildSetup()
      return
    }

    #if canImport(AuthenticationServices)
    do {
      let coord = AppleSignInCoordinator()
      let creds = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<AppleSignInCoordinator.AppleCredentials, Error>) in
        coord.start { result in cont.resume(with: result) }
      }

      try await model.signInWithApple(
        identityToken: creds.identityToken,
        appleUserID: creds.userID,
        email: creds.email,
        fullName: creds.fullName
      )

      model.unlockChildSetup()
    } catch {
      signInError = String(describing: error)
      showError = true
    }
    #else
    signInError = "Sign in with Apple unavailable on this build target."
    showError = true
    #endif
  }

  @MainActor
  private func refreshPolicy() async {
    policyBusy = true
    defer { policyBusy = false }
    await model.reconcileScreenTimeProtection()
    statusMessage = friendlyProtectionMessage()
  }

  @MainActor
  private func requestExtraTime() async {
    extraTimeBusy = true
    defer { extraTimeBusy = false }
    do {
      try await model.childRequestExtraTime(minutes: extraTimeMinutes)
      extraTimeMessage = "Request sent to parent."
    } catch {
      extraTimeMessage = "Could not send request."
    }
  }

  private func friendlyProtectionMessage(now: Date = Date()) -> String {
    if !model.screenTimeAuthorized {
      return "Protection is currently off. Screen Time permission is not enabled."
    }

    if let backend = backendStatusMessage(), !backend.isEmpty {
      return backend
    }

    let boundary = nextScheduleBoundary(after: now, protectionOnNow: model.screenTimeScheduleEnforcedNow)
    if model.screenTimeScheduleEnforcedNow {
      if let boundary {
        return "Protection is currently on and scheduled to end \(formatFriendlyBoundary(boundary, now: now))."
      }
      return "Protection is currently on."
    }

    if let boundary {
      return "Protection is currently off and scheduled to start \(formatFriendlyBoundary(boundary, now: now))."
    }
    return "Protection is currently off."
  }

  private func backendStatusMessage() -> String? {
    guard let raw = SharedDefaults.suite.string(forKey: "last_policy_json"),
          let data = raw.data(using: .utf8),
          let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    else {
      return nil
    }
    let text = (obj["statusMessage"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    return (text?.isEmpty ?? true) ? nil : text
  }

  private var isProtectionCurrentlyOn: Bool {
    if !model.screenTimeAuthorized { return false }
    return model.screenTimeScheduleEnforcedNow
  }

  private var canRequestExtraTime: Bool {
    if let policy = backendPolicyState() {
      return policy.enforce && policy.hasConfiguredProtections
    }
    // Fallback when backend policy cache is unavailable.
    return isProtectionCurrentlyOn
  }

  private func backendPolicyState() -> (enforce: Bool, hasConfiguredProtections: Bool)? {
    guard let raw = SharedDefaults.suite.string(forKey: "last_policy_json"),
          let data = raw.data(using: .utf8),
          let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    else {
      return nil
    }

    let enforce = (obj["enforce"] as? Bool) ?? false
    if let actions = obj["actions"] as? [String: Any] {
      let hasConfigured = (actions["activateProtection"] as? Bool ?? false)
        || (actions["setHotspotOff"] as? Bool ?? false)
        || (actions["setWifiOff"] as? Bool ?? false)
        || (actions["setMobileDataOff"] as? Bool ?? false)
      return (enforce, hasConfigured)
    }

    return (enforce, enforce)
  }

  private func nextScheduleBoundary(after now: Date, protectionOnNow: Bool) -> Date? {
    guard let raw = SharedDefaults.suite.string(forKey: "last_policy_json"),
          let data = raw.data(using: .utf8),
          let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    else {
      return nil
    }

    if let quietDays = obj["quietDays"] as? [String: [String: Any]] {
      return nextBoundaryFromQuietDays(quietDays, after: now, protectionOnNow: protectionOnNow)
    }

    if let quiet = obj["quietHours"] as? [String: Any],
       let start = quiet["start"] as? String,
       let end = quiet["end"] as? String {
      var daily: [String: [String: Any]] = [:]
      for key in ["sun", "mon", "tue", "wed", "thu", "fri", "sat"] {
        daily[key] = ["start": start, "end": end]
      }
      return nextBoundaryFromQuietDays(daily, after: now, protectionOnNow: protectionOnNow)
    }

    return nil
  }

  private func nextBoundaryFromQuietDays(
    _ quietDays: [String: [String: Any]],
    after now: Date,
    protectionOnNow: Bool
  ) -> Date? {
    let calendar = Calendar.current
    let todayStart = calendar.startOfDay(for: now)
    let weekdayKeys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]

    var candidates: [Date] = []
    for dayOffset in 0...7 {
      guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) else { continue }
      let weekday = calendar.component(.weekday, from: dayDate)
      let key = weekdayKeys[max(0, min(weekday - 1, 6))]
      guard let window = quietDays[key],
            let startRaw = window["start"] as? String,
            let endRaw = window["end"] as? String,
            let start = date(on: dayDate, hhmm: startRaw),
            let endBase = date(on: dayDate, hhmm: endRaw)
      else { continue }

      let end = endBase <= start ? calendar.date(byAdding: .day, value: 1, to: endBase) ?? endBase : endBase

      let wanted = protectionOnNow ? end : start
      if wanted > now {
        candidates.append(wanted)
      }
    }

    return candidates.min()
  }

  private func date(on day: Date, hhmm: String) -> Date? {
    let parts = hhmm.split(separator: ":")
    guard parts.count == 2,
          let h = Int(parts[0]),
          let m = Int(parts[1]) else { return nil }
    return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: day)
  }

  private func formatFriendlyTime(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = .current
    f.timeZone = .current
    f.dateStyle = .none
    f.timeStyle = .short
    return f.string(from: date)
  }

  private func formatFriendlyBoundary(_ date: Date, now: Date) -> String {
    let cal = Calendar.current
    let time = formatFriendlyTime(date)

    if cal.isDate(date, inSameDayAs: now) {
      return "at \(time)"
    }
    if let tomorrow = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(date, inSameDayAs: tomorrow) {
      return "tomorrow at \(time)"
    }

    let f = DateFormatter()
    f.locale = .current
    f.timeZone = .current
    f.setLocalizedDateFormatFromTemplate("EEE d MMM")
    return "on \(f.string(from: date)) at \(time)"
  }
}

#Preview {
  ChildLockedView()
    .environmentObject(AppModel())
}
#endif

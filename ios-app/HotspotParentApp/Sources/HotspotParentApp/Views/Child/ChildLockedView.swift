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

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        headerCard
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
    }
  }

  private var headerCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("SpotChecker Complete")
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
        Label(policyBusy ? "Updating…" : "Update", systemImage: "arrow.clockwise")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .disabled(policyBusy)
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

  private func friendlyProtectionMessage(now: Date = Date()) -> String {
    if !model.screenTimeAuthorized {
      return "Protection is currently off. Screen Time permission is not enabled."
    }

    if let reason = model.screenTimeDegradedReason?.lowercased(), reason.contains("disabled by parent") {
      return "Protection is currently off. The parent has disabled protection."
    }

    let boundary = nextScheduleBoundary(after: now, protectionOnNow: model.screenTimeScheduleEnforcedNow)
    if model.screenTimeScheduleEnforcedNow {
      if let boundary {
        return "Protection is currently on and scheduled to end at \(formatFriendlyTime(boundary))."
      }
      return "Protection is currently on."
    }

    if let boundary {
      return "Protection is currently off and scheduled to start at \(formatFriendlyTime(boundary))."
    }
    return "Protection is currently off."
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
}

#Preview {
  ChildLockedView()
    .environmentObject(AppModel())
}
#endif

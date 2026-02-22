import DeviceActivity
import Foundation

final class UsageMonitorExtension: DeviceActivityMonitor {
  private let appGroupID = "group.com.bazapps.hotspotparent"
  private let usedMinutesKey = "spotcheck.screentime.reportedUsedMinutes"
  private let reportedAtEpochKey = "spotcheck.screentime.reportedAtEpoch"

  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    storeUsage(minutes: 0)
  }

  override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
    super.eventDidReachThreshold(event, activity: activity)
    let mins = Self.minutesFrom(eventName: event.rawValue)
    guard mins >= 0 else { return }
    storeUsage(minutes: mins)
  }

  private func storeUsage(minutes: Int) {
    guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
    defaults.set(max(0, minutes), forKey: usedMinutesKey)
    defaults.set(Date().timeIntervalSince1970, forKey: reportedAtEpochKey)
  }

  private static func minutesFrom(eventName: String) -> Int {
    // Expected format: usage_5, usage_10, ...
    let suffix = eventName.replacingOccurrences(of: "usage_", with: "")
    return Int(suffix) ?? -1
  }
}

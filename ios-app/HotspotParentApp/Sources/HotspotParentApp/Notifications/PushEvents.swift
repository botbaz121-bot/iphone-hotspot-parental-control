import Foundation

public enum PushEventNames {
  public static let didRegisterDeviceToken = Notification.Name("spotcheck.push.didRegisterDeviceToken")
  public static let didReceiveExtraTimeRequest = Notification.Name("spotcheck.push.didReceiveExtraTimeRequest")
}

public struct ExtraTimePushPayload {
  public var deviceId: String
  public var requestId: String?
  public var requestedMinutes: Int

  public init(deviceId: String, requestId: String?, requestedMinutes: Int) {
    self.deviceId = deviceId
    self.requestId = requestId
    self.requestedMinutes = requestedMinutes
  }

  public static func fromUserInfo(_ userInfo: [AnyHashable: Any]) -> ExtraTimePushPayload? {
    let type = String(describing: userInfo["type"] ?? "")
    guard type == "extra_time_request" else { return nil }
    guard let deviceId = userInfo["deviceId"] as? String, !deviceId.isEmpty else { return nil }

    let requestId = userInfo["requestId"] as? String
    let minutes: Int = {
      if let n = userInfo["requestedMinutes"] as? NSNumber { return n.intValue }
      if let s = userInfo["requestedMinutes"] as? String, let n = Int(s) { return n }
      return 15
    }()

    return ExtraTimePushPayload(
      deviceId: deviceId,
      requestId: requestId,
      requestedMinutes: max(5, min(240, (minutes / 5) * 5))
    )
  }
}

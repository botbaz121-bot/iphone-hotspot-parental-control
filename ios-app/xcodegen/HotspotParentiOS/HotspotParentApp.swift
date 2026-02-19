import SwiftUI
import HotspotParentApp
import UIKit
import UserNotifications

final class HotspotAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
    return true
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    NotificationCenter.default.post(
      name: PushEventNames.didRegisterDeviceToken,
      object: nil,
      userInfo: ["token": hex]
    )
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    // Best-effort: push is optional for core functionality.
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    if let payload = ExtraTimePushPayload.fromUserInfo(userInfo) {
      AppDefaults.pendingExtraTimeDeviceId = payload.deviceId
      AppDefaults.pendingExtraTimeRequestId = payload.requestId
      AppDefaults.pendingExtraTimeMinutes = payload.requestedMinutes
      NotificationCenter.default.post(
        name: PushEventNames.didReceiveExtraTimeRequest,
        object: nil,
        userInfo: [
          "deviceId": payload.deviceId,
          "requestedMinutes": payload.requestedMinutes,
          "requestId": payload.requestId ?? ""
        ]
      )
    }
    completionHandler()
  }
}

@main
struct HotspotParentAppMain: App {
  @UIApplicationDelegateAdaptor(HotspotAppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      AppShellView()
    }
  }
}

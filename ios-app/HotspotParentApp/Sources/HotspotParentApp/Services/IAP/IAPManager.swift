import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif

/// Minimal In‑App Purchase state container.
///
/// v1A: **No StoreKit wiring yet** — this is a lightweight stub to support UI + persistence.
@MainActor
public final class IAPManager: ObservableObject {
  public static let shared = IAPManager()

  @Published public private(set) var adsRemoved: Bool {
    didSet { AppDefaults.adsRemoved = adsRemoved }
  }

  private init() {
    self.adsRemoved = AppDefaults.adsRemoved
  }

  public func purchaseRemoveAds() async {
    // TODO(v1B): Integrate StoreKit 2 purchase flow for product id "spotcheck.remove_ads".
    // For now, we keep a local toggle so the UI can be exercised.
    adsRemoved = true
  }

  public func restorePurchases() async {
    // TODO(v1B): StoreKit 2 restore/transaction refresh.
  }

  public func setAdsRemovedForDebug(_ value: Bool) {
    adsRemoved = value
  }
}

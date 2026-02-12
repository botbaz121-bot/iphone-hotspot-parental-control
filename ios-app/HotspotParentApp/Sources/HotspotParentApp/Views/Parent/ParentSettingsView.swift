import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentSettingsView: View {
  @EnvironmentObject private var model: AppModel
  @StateObject private var iap = IAPManager.shared
  @State private var iapStatus: String?

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        ModeSettingsCardView()
          .environmentObject(model)

        accountCard

        iapCard

        debugCard
      }
      .padding(.top, 22)
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
  }

  private var accountCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Account")
        .font(.headline)

      HStack {
        Text("Signed in")
          .font(.footnote)
          .foregroundStyle(.secondary)
        Spacer()
        Text(model.isSignedIn ? "Yes" : "No")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(model.isSignedIn ? .green : .secondary)
      }

      Button(role: .destructive) {
        model.signOut()
      } label: {
        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .tint(.red)
      .disabled(!model.isSignedIn)
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  private var iapCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("In-app purchase")
        .font(.headline)

      Text("Remove ads from the parent experience.")
        .font(.footnote)
        .foregroundStyle(.secondary)

      Button {
        Task {
          iapStatus = nil
          await iap.purchaseRemoveAds()
          await MainActor.run {
            model.adsRemoved = iap.adsRemoved
            iapStatus = iap.adsRemoved ? "Purchased" : "Not purchased"
          }
        }
      } label: {
        Label("Remove ads (mock)", systemImage: "clock")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .tint(.blue)

      if let iapStatus {
        Text(iapStatus)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  private var debugCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Debug")
        .font(.headline)

      Text("Static prototype. No server, no push, no background tasks.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }
}

#Preview {
  ParentSettingsView()
    .environmentObject(AppModel())
}
#endif

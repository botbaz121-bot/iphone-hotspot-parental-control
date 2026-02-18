import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct PairingEntryView: View {
  @EnvironmentObject private var model: AppModel

  @State private var code: String = ""
  @State private var busy = false
  @State private var errorText: String?

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("Pairing")
          .font(.system(size: 34, weight: .bold))
          .padding(.top, 2)

        SettingsGroup("Enter pairing code") {
          VStack(alignment: .leading, spacing: 10) {
            TextField("Code", text: $code)
              .textInputAutocapitalization(.characters)
              .autocorrectionDisabled()
              .font(.system(.body, design: .monospaced))
              .padding(.vertical, 10)
              .padding(.horizontal, 12)
              .background(Color.white.opacity(0.04))
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .stroke(Color.white.opacity(0.08), lineWidth: 1)
              )
              .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
              busy = true
              errorText = nil
              Task {
                defer { busy = false }
                do {
                  let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                  try await model.pairChildDevice(code: trimmed)
                  // Refresh any derived state
                  model.syncFromSharedDefaults()
                  errorText = "Paired successfully."
                } catch {
                  if let apiErr = error as? APIError {
                    errorText = apiErr.userMessage
                  } else {
                    errorText = "Pairing failed. Please try again."
                  }
                }
              }
            } label: {
              Text(busy ? "Pairing…" : "Pair")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(busy || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
          .padding(.vertical, 10)
          .padding(.horizontal, 12)
        }

        if model.loadHotspotConfig() != nil {
          SettingsGroup("Paired") {
            SettingsRow(
              systemIcon: "iphone",
              title: model.childPairedDeviceName ?? "Child phone",
              subtitle: "This phone is paired",
              rightText: "Paired",
              showsChevron: false,
              action: nil
            )
          }

          Button(role: .destructive) {
            model.unpairChildDevice()
            model.syncFromSharedDefaults()
          } label: {
            Label("Unpair", systemImage: "link.badge.minus")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .tint(.red)
        }

        if let errorText {
          Text(errorText)
            .foregroundStyle(errorText.contains("success") ? .green : .red)
            .font(.system(size: 14))
        }

      }
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    PairingEntryView()
      .environmentObject(AppModel())
  }
}
#endif

import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct AddDeviceSheetView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss

  @State private var deviceName: String = ""
  @State private var pairingCode: String?
  @State private var status: String?
  @State private var loading: Bool = false

  public init() {}

  private var trimmedDeviceName: String {
    deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          SettingsGroup("Device name") {
            VStack(alignment: .leading, spacing: 10) {
              TextField("Required", text: $deviceName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.04))
                .overlay(
                  RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

              Button {
                status = nil
                pairingCode = nil
                loading = true
                Task {
                  defer { loading = false }
                  do {
                    let out = try await model.createDeviceAndPairingCode(name: trimmedDeviceName)
                    pairingCode = out.code
                  } catch {
                    status = String(describing: error)
                  }
                }
              } label: {
                if loading {
                  HStack { Spacer(); ProgressView(); Spacer() }
                } else {
                  Label("Generate pairing code", systemImage: "qrcode")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
              }
              .buttonStyle(.borderedProminent)
              .tint(.blue)
              .disabled(!model.isSignedIn || loading || trimmedDeviceName.isEmpty)

              if trimmedDeviceName.isEmpty {
                Text("Device name is required.")
                  .font(.system(size: 14))
                  .foregroundStyle(.secondary)
              }

              if !model.isSignedIn {
                Text("Sign in first to enroll devices.")
                  .font(.system(size: 14))
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
          }

          if let code = pairingCode {
            SettingsGroup("Pairing code") {
              SettingsRow(
                systemIcon: "number",
                title: code,
                subtitle: "Open the child phone and enter this code in Settings.",
                rightText: nil,
                showsChevron: false,
                action: nil
              )
            }
          }

          if let status {
            Text(status)
              .font(.system(size: 14))
              .foregroundStyle(.red)
          }

        }
        .padding(.horizontal, 18)
        .padding(.bottom, 32)
      }
      .navigationTitle("Enroll")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
            .buttonStyle(.bordered)
            .tint(.white)
            .controlSize(.small)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}

#Preview {
  AddDeviceSheetView()
    .environmentObject(AppModel())
}
#endif

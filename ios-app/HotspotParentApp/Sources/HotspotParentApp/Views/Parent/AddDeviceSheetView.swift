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

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("Enroll a child device")
            .font(.title.bold())

          Text("This generates a short-lived pairing code. On the child phone: open the app → Child mode → Settings → enter the code.")
            .font(.footnote)
            .foregroundStyle(.secondary)

          TextField("Device name (optional)", text: $deviceName)
            .textFieldStyle(.roundedBorder)

          Button {
            status = nil
            pairingCode = nil
            loading = true
            Task {
              defer { loading = false }
              do {
                let out = try await model.createDeviceAndPairingCode(name: deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : deviceName)
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
            }
          }
          .buttonStyle(.borderedProminent)
          .disabled(!model.isSignedIn || loading)

          if !model.isSignedIn {
            Text("Sign in first to enroll devices.")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }

          if let code = pairingCode {
            VStack(alignment: .leading, spacing: 8) {
              Text("Pairing code")
                .font(.headline)
              Text(code)
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .textSelection(.enabled)
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
          }

          if let status {
            Text(status)
              .font(.footnote)
              .foregroundStyle(.red)
          }

          Button {
            model.setAppMode(.childSetup)
            dismiss()
          } label: {
            Label("Set up child phone now", systemImage: "clock")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }
        .padding()
      }
      .navigationTitle("Enroll")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
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

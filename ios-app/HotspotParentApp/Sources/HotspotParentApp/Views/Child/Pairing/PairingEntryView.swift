import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct PairingEntryView: View {
  @EnvironmentObject private var model: AppModel

  @State private var code: String = ""
  @State private var name: String = "Child iPhone"
  @State private var busy = false
  @State private var errorText: String?

  public init() {}

  public var body: some View {
    Form {
      Section("Enter pairing code") {
        TextField("Code", text: $code)
          .textInputAutocapitalization(.characters)
          .autocorrectionDisabled()
          .font(.system(.body, design: .monospaced))

        TextField("Device name (optional)", text: $name)

        Button {
          busy = true
          errorText = nil
          Task {
            defer { busy = false }
            do {
              let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
              try await model.pairChildDevice(code: trimmed, name: name.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
              errorText = "Pairing failed: \(error)"
            }
          }
        } label: {
          Text(busy ? "Pairing…" : "Pair")
        }
        .disabled(busy || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }

      if let cfg = model.loadHotspotConfig() {
        Section("Current pairing") {
          LabeledContent("API") {
            Text(cfg.apiBaseURL)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          LabeledContent("Device") {
            Text(model.childPairedDeviceName ?? "—")
          }
          LabeledContent("Device id") {
            Text(model.childPairedDeviceId ?? "—")
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
      }

      if let errorText {
        Section {
          Text(errorText)
            .foregroundStyle(.red)
            .font(.footnote)
        }
      }

      #if DEBUG
      Section("Debug") {
        Button("Simulate Shortcut run") {
          model.recordIntentRun()
        }
      }
      #endif
    }
    .navigationTitle("Pairing")
  }
}

#Preview {
  NavigationStack {
    PairingEntryView()
      .environmentObject(AppModel())
  }
}
#endif

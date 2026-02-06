import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct EnrollmentView: View {
  @EnvironmentObject private var model: AppModel

  @State private var copied = false
  @State private var pairingBusy = false
  @State private var pairingError: String?

  public init() {}

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          LocalTokenCard

          BackendPairingCard

          Text("Use the token/QR code in the Child app to enroll the device.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
      }
      .navigationTitle("Enroll")
    }
  }

  private var LocalTokenCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Local enrollment token")
        .font(.headline)

      Text(model.enrollmentToken)
        .font(.system(.title3, design: .monospaced))
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)

      HStack {
        Button(copied ? "Copied" : "Copy") {
          #if canImport(UIKit)
          UIPasteboard.general.string = model.enrollmentToken
          #endif
          copied = true
          Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            copied = false
          }
        }
        .buttonStyle(.bordered)

        Button("Regenerate") {
          model.regenerateEnrollmentToken()
        }
        .buttonStyle(.bordered)
      }

      QRCodeCard(title: "Local token QR", text: model.enrollmentToken)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }

  private var BackendPairingCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Backend pairing code (optional)")
        .font(.headline)

      Text("If you configure an API base URL + admin token in Settings, you can generate a short-lived pairing code from the backend.")
        .font(.footnote)
        .foregroundStyle(.secondary)

      LabeledContent("Device id") {
        Text(model.deviceId ?? "—")
          .font(.system(.footnote, design: .monospaced))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      if let code = model.pairingCode {
        LabeledContent("Pairing code") {
          Text(code)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
        }

        if let exp = model.pairingCodeExpiresAt {
          LabeledContent("Expires") {
            Text(exp, style: .relative)
              .foregroundStyle(.secondary)
          }
        }

        QRCodeCard(title: "Pairing code QR", text: code)
      } else {
        Text("No pairing code yet.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      if let pairingError {
        Text(pairingError)
          .font(.footnote)
          .foregroundStyle(.red)
      }

      HStack {
        Button {
          pairingError = nil
          pairingBusy = true
          Task {
            defer { pairingBusy = false }
            do {
              try await model.createBackendDeviceIfNeeded(name: "Parent")
              try await model.refreshPairingCode()
            } catch {
              pairingError = "Backend pairing failed: \(error)"
            }
          }
        } label: {
          Text(pairingBusy ? "Working…" : "Generate pairing code")
        }
        .buttonStyle(.bordered)
        .disabled(pairingBusy)

        Button("Clear") {
          model.clearPairingCode()
          pairingError = nil
        }
        .buttonStyle(.bordered)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

private struct QRCodeCard: View {
  let title: String
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.subheadline.bold())

      #if canImport(UIKit)
      if let img = QRCode.image(from: text) {
        Image(uiImage: img)
          .interpolation(.none)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: 240)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 6)
          .accessibilityLabel("QR code")
      } else {
        Text("Unable to generate QR.")
          .foregroundStyle(.secondary)
      }
      #else
      Text("QR requires UIKit")
        .foregroundStyle(.secondary)
      #endif
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 8)
  }
}

#Preview {
  EnrollmentView()
    .environmentObject(AppModel())
}
#endif

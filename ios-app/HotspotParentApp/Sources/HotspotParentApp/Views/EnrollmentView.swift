import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct EnrollmentView: View {
  @EnvironmentObject private var model: AppModel
  @State private var copied = false

  public init() {}

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Enrollment token")
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
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
          .background(.thinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 16))

          QRCodeCard(text: model.enrollmentToken)

          VStack(alignment: .leading, spacing: 10) {
            Text("Backend pairing (dev)")
              .font(.headline)

            Button("Create device + pairing code") {
              Task { await model.createDeviceAndPair() }
            }
            .buttonStyle(.borderedProminent)

            if let code = model.pairingCode {
              Text("Pairing code")
                .font(.subheadline)
                .foregroundStyle(.secondary)
              Text(code)
                .font(.system(.title2, design: .monospaced).bold())
                .textSelection(.enabled)
            } else {
              Text("Requires admin token in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if let s = model.apiStatus {
              Text(s)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
          .background(.thinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 16))

          Text("Use this token/QR code in the Child app to enroll the device.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
      }
      .navigationTitle("Enroll")
    }
  }
}

private struct QRCodeCard: View {
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("QR")
        .font(.headline)

      #if canImport(UIKit)
      if let img = QRCode.image(from: text) {
        Image(uiImage: img)
          .interpolation(.none)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: 280)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 6)
          .accessibilityLabel("Enrollment QR code")
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
    .padding()
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

#Preview {
  EnrollmentView()
    .environmentObject(AppModel())
}
#endif

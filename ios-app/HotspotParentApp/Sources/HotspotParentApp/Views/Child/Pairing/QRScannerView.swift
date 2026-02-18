import Foundation

#if canImport(SwiftUI)
import SwiftUI

/// Placeholder for a future QR scanner implementation (AVFoundation).
///
/// v1A keeps manual pairing entry as the primary path.
public struct QRScannerView: View {
  public init() {}

  public var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "qrcode.viewfinder")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)

      Text("QR scanning not implemented in v1A")
        .font(.headline)

      Text("Use manual pairing code entry for now.")
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
    }
    .padding()
    .navigationTitle("Scan QR")
  }
}

#Preview {
  NavigationStack { QRScannerView() }
}
#endif

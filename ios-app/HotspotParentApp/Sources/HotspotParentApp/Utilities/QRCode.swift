import Foundation

#if canImport(UIKit)
import UIKit
import CoreImage.CIFilterBuiltins

public enum QRCode {
  public static func image(from string: String, scale: CGFloat = 10) -> UIImage? {
    let data = Data(string.utf8)
    let filter = CIFilter.qrCodeGenerator()
    filter.setValue(data, forKey: "inputMessage")

    guard let output = filter.outputImage else { return nil }

    // Scale up for readability.
    let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let context = CIContext()
    guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
    return UIImage(cgImage: cgImage)
  }
}
#endif

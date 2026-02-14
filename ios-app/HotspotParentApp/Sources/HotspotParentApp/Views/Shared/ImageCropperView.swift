import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(TOCropViewController)
import TOCropViewController
#endif

#if canImport(SwiftUI) && canImport(UIKit) && canImport(TOCropViewController)
public struct ImageCropperView: UIViewControllerRepresentable {
  public typealias UIViewControllerType = TOCropViewController

  public let image: UIImage
  public let onCropped: (UIImage) -> Void
  public let onCancel: () -> Void

  public init(image: UIImage, onCropped: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
    self.image = image
    self.onCropped = onCropped
    self.onCancel = onCancel
  }

  public func makeUIViewController(context: Context) -> TOCropViewController {
    let vc = TOCropViewController(croppingStyle: .default, image: image)
    vc.delegate = context.coordinator

    // Square crop for tiles.
    vc.aspectRatioPreset = .presetSquare
    vc.aspectRatioLockEnabled = true
    vc.resetAspectRatioEnabled = false

    return vc
  }

  public func updateUIViewController(_ uiViewController: TOCropViewController, context: Context) {
    _ = uiViewController
    _ = context
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator(onCropped: onCropped, onCancel: onCancel)
  }

  public final class Coordinator: NSObject, TOCropViewControllerDelegate {
    private let onCropped: (UIImage) -> Void
    private let onCancel: () -> Void

    init(onCropped: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
      self.onCropped = onCropped
      self.onCancel = onCancel
    }

    public func cropViewController(_ cropViewController: TOCropViewController, didFinishCancelled cancelled: Bool) {
      if cancelled {
        onCancel()
      }
    }

    public func cropViewController(_ cropViewController: TOCropViewController, didCropTo image: UIImage, withRect cropRect: CGRect, angle: Int) {
      _ = cropRect
      _ = angle
      onCropped(image)
    }
  }
}
#endif

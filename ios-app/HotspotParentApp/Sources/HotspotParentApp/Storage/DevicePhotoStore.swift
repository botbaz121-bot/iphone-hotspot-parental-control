import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Stores per-device photos locally on this phone.
///
/// We keep this local for now (no backend support yet) so parents can add a kid photo
/// without impacting pairing/auth.
public enum DevicePhotoStore {
  private static let dirName = "device_photos"

  private static func baseDir() throws -> URL {
    let base = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let dir = base.appendingPathComponent(dirName, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  private static func fileURL(deviceId: String) throws -> URL {
    try baseDir().appendingPathComponent("\(deviceId).jpg")
  }

  public static func setPhotoJPEG(deviceId: String, data: Data?) throws {
    let url = try fileURL(deviceId: deviceId)
    if let data {
      try data.write(to: url, options: [.atomic])
    } else {
      try? FileManager.default.removeItem(at: url)
    }
  }

  public static func getPhotoData(deviceId: String) -> Data? {
    do {
      let url = try fileURL(deviceId: deviceId)
      return try? Data(contentsOf: url)
    } catch {
      return nil
    }
  }

  #if canImport(UIKit)
  public static func getUIImage(deviceId: String) -> UIImage? {
    guard let data = getPhotoData(deviceId: deviceId) else { return nil }
    return UIImage(data: data)
  }
  #endif
}

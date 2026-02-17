import Foundation

#if canImport(SwiftUI)
import SwiftUI

/// Settings-style card for switching between Parent and Child experiences.
/// Designed to mimic the prototype's "This is a child phone" toggle.
public struct ModeSettingsCardView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Mode")
        .font(.headline)

      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("This is a child phone")
            .font(.subheadline.weight(.semibold))
          Text("Show the child setup experience on this device")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Toggle("", isOn: Binding(
          get: { (model.appMode ?? .parent) == .childSetup },
          set: { isChild in
            model.setAppMode(isChild ? .childSetup : .parent)
          }
        ))
        .labelsHidden()
      }
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }
}

#Preview {
  ModeSettingsCardView()
    .environmentObject(AppModel())
}
#endif

import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct AppModeSwitcherView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    Picker("Mode", selection: Binding(
      get: { model.appMode ?? .parent },
      set: { model.setAppMode($0) }
    )) {
      Text("Parent").tag(AppMode.parent)
      Text("Child").tag(AppMode.childSetup)
    }
    .pickerStyle(.segmented)
  }
}

#Preview {
  AppModeSwitcherView()
    .environmentObject(AppModel())
}
#endif

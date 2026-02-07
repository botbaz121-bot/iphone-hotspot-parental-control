import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct LandingView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          VStack(alignment: .leading, spacing: 6) {
            Text("SpotCheck")
              .font(.largeTitle.bold())
            Text("Hotspot enforcement via Shortcuts + setup checks")
              .font(.headline)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          VStack(spacing: 12) {
            Button {
              model.setAppMode(.parent)
            } label: {
              Label("Parent phone", systemImage: "person")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
              model.setAppMode(.childSetup)
            } label: {
              Label("Set up child phone", systemImage: "iphone")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("What this app can/can’t do")
              .font(.headline)
            Text("iOS apps cannot directly toggle Personal Hotspot via public APIs. SpotCheck uses Shortcuts for enforcement, and the app provides configuration + setup signals.")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          .padding()
          .background(.thinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 16))

          #if DEBUG
          VStack(alignment: .leading, spacing: 10) {
            Text("Debug")
              .font(.headline)

            Button(role: .destructive) {
              model.resetLocalData()
            } label: {
              Text("Reset local data")
            }
          }
          .padding()
          .background(.thinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 16))
          #endif
        }
        .padding()
      }
      .navigationTitle(" ")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

#Preview {
  LandingView()
    .environmentObject(AppModel())
}
#endif

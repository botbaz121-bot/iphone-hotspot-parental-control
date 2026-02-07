import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentDashboardView: View {
  @EnvironmentObject private var model: AppModel
  @State private var showingAddDevice = false

  public init() {}

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Parent Dashboard")
              .font(.title.bold())
            Text("v1A: this build focuses on child setup + Shortcut config. Policy editing in-app is deferred.")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }

          Button {
            showingAddDevice = true
          } label: {
            Label("Add device", systemImage: "plus")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)

          VStack(alignment: .leading, spacing: 10) {
            Text("How pairing works")
              .font(.headline)
            Text("During alpha, you can pair a child phone using a pairing code from the backend admin UI. The child phone stores credentials securely and exposes them to Shortcuts via an App Intent.")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          .padding()
          .background(.thinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 16))

          #if DEBUG
          VStack(alignment: .leading, spacing: 10) {
            Text("Backend health (debug)")
              .font(.headline)

            LabeledContent("Base URL") {
              Text(model.apiBaseURL)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            LabeledContent("Health") {
              switch model.backendHealthOK {
                case .none:
                  Text("—").foregroundStyle(.secondary)
                case .some(true):
                  Text("OK").foregroundStyle(.green)
                case .some(false):
                  Text("Down").foregroundStyle(.red)
              }
            }

            if let err = model.backendLastError {
              Text(err)
                .font(.footnote)
                .foregroundStyle(.red)
            }

            Button("Refresh") {
              Task { await model.refreshBackendStatus() }
            }
            .buttonStyle(.bordered)
          }
          .padding()
          .background(.thinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 16))
          #endif
        }
        .padding()
      }
      .navigationTitle("Dashboard")
      .sheet(isPresented: $showingAddDevice) {
        AddDeviceSheetView()
          .environmentObject(model)
      }
      .task {
        #if DEBUG
        await model.refreshBackendStatus()
        #endif
      }
    }
  }
}

#Preview {
  ParentDashboardView()
    .environmentObject(AppModel())
}
#endif

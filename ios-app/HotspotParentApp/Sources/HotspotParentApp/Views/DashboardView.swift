import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct DashboardView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    NavigationStack {
      List {
        Section("Device") {
          LabeledContent("Enrollment token") {
            Text(model.enrollmentToken)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }

          LabeledContent("Backend device id") {
            Text(model.deviceId ?? "—")
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }

          LabeledContent("Last check-in") {
            if let last = model.lastCheckIn {
              Text(last, style: .relative)
            } else {
              Text("Never")
                .foregroundStyle(.secondary)
            }
          }

          Button("Simulate check-in now") {
            model.recordCheckInNow()
          }
        }

        Section("Policy") {
          LabeledContent("Hotspot OFF") {
            Text(model.hotspotOffPolicyEnabled ? "Enforced" : "Not enforced")
              .foregroundStyle(model.hotspotOffPolicyEnabled ? .green : .secondary)
          }
        }

        Section("Backend") {
          LabeledContent("API base URL") {
            Text(model.apiBaseURL)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }

          LabeledContent("Health") {
            switch model.backendHealthOK {
              case .none:
                Text("—")
                  .foregroundStyle(.secondary)
              case .some(true):
                Text("OK")
                  .foregroundStyle(.green)
              case .some(false):
                Text("Down")
                  .foregroundStyle(.red)
            }
          }

          LabeledContent("Devices (admin)") {
            if let n = model.backendDeviceCount {
              Text("\(n)")
            } else {
              Text("—")
                .foregroundStyle(.secondary)
            }
          }

          if let err = model.backendLastError {
            Text(err)
              .font(.footnote)
              .foregroundStyle(.red)
          }

          HStack {
            Button("Refresh") {
              Task { await model.refreshBackendStatus() }
            }
            .buttonStyle(.bordered)

            if let t = model.backendLastRefresh {
              Spacer()
              Text(t, style: .time)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
      .navigationTitle("Dashboard")
      .task {
        await model.refreshBackendStatus()
      }
      .refreshable {
        await model.refreshBackendStatus()
      }
    }
  }
}

#Preview {
  DashboardView()
    .environmentObject(AppModel())
}
#endif

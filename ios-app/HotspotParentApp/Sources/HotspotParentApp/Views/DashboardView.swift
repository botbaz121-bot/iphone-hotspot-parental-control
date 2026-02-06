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

        Section("Backend") {
          Button("Test /healthz") {
            Task { await model.refreshHealthz() }
          }

          if let s = model.apiStatus {
            Text(s)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(.secondary)
          }
        }

        Section("Policy") {
          LabeledContent("Hotspot OFF") {
            Text(model.hotspotOffPolicyEnabled ? "Enforced" : "Not enforced")
              .foregroundStyle(model.hotspotOffPolicyEnabled ? .green : .secondary)
          }
        }
      }
      .navigationTitle("Dashboard")
    }
  }
}

#Preview {
  DashboardView()
    .environmentObject(AppModel())
}
#endif

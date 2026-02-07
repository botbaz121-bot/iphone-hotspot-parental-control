import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentDashboardView: View {
  @EnvironmentObject private var model: AppModel
  @State private var showingAddDevice = false
  @State private var showingShortcutHelp = false

  private var shortcutLooksStale: Bool {
    guard let last = model.lastAppIntentRunAt else { return true }
    return Date().timeIntervalSince(last) > 60 * 60 * 12
  }

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

          // Recent activity (based on App Intent telemetry written by the Shortcut)
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text("Recent activity")
                .font(.headline)

              Spacer()

              if shortcutLooksStale {
                Text("No recent run")
                  .font(.caption.weight(.semibold))
                  .padding(.horizontal, 10)
                  .padding(.vertical, 4)
                  .background(Color.orange.opacity(0.15))
                  .clipShape(Capsule())
              } else {
                Text("Active")
                  .font(.caption.weight(.semibold))
                  .padding(.horizontal, 10)
                  .padding(.vertical, 4)
                  .background(Color.green.opacity(0.15))
                  .clipShape(Capsule())
              }
            }

            LabeledContent("Shortcut runs") {
              Text("\(model.appIntentRunCount)")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
            }

            LabeledContent("Last run") {
              if let last = model.lastAppIntentRunAt {
                Text(last.formatted(date: .abbreviated, time: .shortened))
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              } else {
                Text("—")
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }
            }

            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 10) {
                recentChip(title: "Hotspot check", subtitle: "from Shortcut")
                recentChip(title: "Policy fetch", subtitle: "best-effort")
                recentChip(title: "Enforcement", subtitle: "in Shortcuts")
              }
              .padding(.vertical, 2)
            }
          }
          .padding()
          .background(.thinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 16))

          VStack(alignment: .leading, spacing: 10) {
            Text("Troubleshooting")
              .font(.headline)

            Button {
              showingShortcutHelp = true
            } label: {
              Label("Shortcut not running", systemImage: "wrench.and.screwdriver")
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
              model.resetLocalData()
            } label: {
              Label("Remove local pairing", systemImage: "trash")
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
          }
          .padding()
          .background(.thinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 16))

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
      .sheet(isPresented: $showingShortcutHelp) {
        ShortcutNotRunningSheetView()
      }
      .task {
        #if DEBUG
        await model.refreshBackendStatus()
        #endif
      }
    }
  }

  private func recentChip(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.footnote.weight(.semibold))
      Text(subtitle)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

#Preview {
  ParentDashboardView()
    .environmentObject(AppModel())
}
#endif

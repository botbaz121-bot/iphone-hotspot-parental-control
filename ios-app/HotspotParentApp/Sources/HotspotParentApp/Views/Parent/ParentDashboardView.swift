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

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
              ForEach(model.parentDevices, id: \.id) { d in
                Button {
                  model.selectedDeviceId = d.id
                } label: {
                  VStack(alignment: .leading, spacing: 6) {
                    Text(d.name)
                      .font(.headline)
                      .lineLimit(1)
                    Text(d.gap ? "Needs attention" : "OK")
                      .font(.caption.weight(.semibold))
                      .foregroundStyle(d.gap ? .orange : .green)
                    if let last = d.last_event_at {
                      Text("Last: \(last)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    } else {
                      Text("No events yet")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                  }
                  .padding(12)
                  .frame(width: 220, alignment: .leading)
                  .background(model.selectedDeviceId == d.id ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06))
                  .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
              }

              Button {
                showingAddDevice = true
              } label: {
                VStack(spacing: 8) {
                  Image(systemName: "plus")
                    .font(.title2)
                  Text("Enroll")
                    .font(.headline)
                }
                .frame(width: 140, height: 90)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
              }
              .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
          }

          // Parent backend status
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text("Backend")
                .font(.headline)
              Spacer()

              if model.parentLoading {
                ProgressView().scaleEffect(0.9)
              }

              Button("Refresh") {
                Task { await model.refreshParentDashboard() }
              }
              .buttonStyle(.bordered)
            }

            if let err = model.parentLastError {
              Text(err)
                .font(.footnote)
                .foregroundStyle(.red)
            } else if model.parentDevices.isEmpty {
              Text("No devices yet. Tap Enroll to create one and get a pairing code.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else {
              Text("Devices: \(model.parentDevices.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          }
          .padding()
          .background(.thinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 16))

          // Policy editor (selected device)
          if let d = model.selectedParentDevice {
            VStack(alignment: .leading, spacing: 10) {
              Text("Device rules")
                .font(.headline)

              Toggle("Enforce", isOn: Binding(
                get: { d.enforce },
                set: { v in Task { try? await model.updateSelectedDevicePolicy(enforce: v) } }
              ))

              Toggle("Hotspot OFF", isOn: .constant(true))
                .disabled(true)
              Toggle("Rotate password", isOn: .constant(true))
                .disabled(true)

              Text("Quiet hours + gap editing coming next (wired on backend).")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
          }

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
        await model.refreshParentDashboard()
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

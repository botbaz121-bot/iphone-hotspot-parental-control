import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentDashboardView: View {
  @EnvironmentObject private var model: AppModel
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
            Text("Dashboard")
              .font(.title.bold())
            Text("Set rules per child device, guide setup on the child phone, and get a simple tamper warning if it stops running.")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }

          DeviceCarouselView()
            .environmentObject(model)

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
            PolicyEditorCard(device: d)
              .environmentObject(model)
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
      .sheet(isPresented: $model.presentEnrollSheet) {
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

private struct PolicyEditorCard: View {
  @EnvironmentObject private var model: AppModel
  public var device: DashboardDevice

  @State private var quietStart: String
  @State private var quietEnd: String
  @State private var gapMinutesText: String
  @State private var pairingCode: String?
  @State private var status: String?

  private var isScheduleEnabled: Bool {
    let s = quietStart.isEmpty ? "12:00" : quietStart
    let e = quietEnd.isEmpty ? "12:00" : quietEnd
    return s != e
  }

  init(device: DashboardDevice) {
    self.device = device
    _quietStart = State(initialValue: device.quietHours?.start ?? "12:00")
    _quietEnd = State(initialValue: device.quietHours?.end ?? "12:00")
    _gapMinutesText = State(initialValue: String(max(1, Int(round(Double(device.gapMs) / 60000.0)))))
  }

  private func parseTimeOrDefault(_ hhmm: String) -> Date {
    let parts = hhmm.split(separator: ":")
    let h = parts.count > 0 ? Int(parts[0]) ?? 12 : 12
    let m = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
    return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
  }

  private func formatTime(_ d: Date) -> String {
    let c = Calendar.current.dateComponents([.hour, .minute], from: d)
    let h = c.hour ?? 12
    let m = c.minute ?? 0
    return String(format: "%02d:%02d", h, m)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Device rules")
          .font(.headline)
        Spacer()
        Button("Pair code") {
          status = nil
          pairingCode = nil
          Task {
            do {
              let out = try await model.createPairingCodeForSelectedDevice()
              pairingCode = out.code
            } catch {
              status = String(describing: error)
            }
          }
        }
        .buttonStyle(.bordered)
      }

      Toggle("Hotspot OFF", isOn: Binding(
        get: { device.actions.setHotspotOff },
        set: { v in Task { try? await model.updateSelectedDevicePolicy(setHotspotOff: v) } }
      ))

      Toggle("Set schedule", isOn: Binding(
        get: {
          let s = device.quietHours?.start ?? "12:00"
          let e = device.quietHours?.end ?? "12:00"
          return s != e
        },
        set: { enabled in
          Task {
            if enabled {
              try? await model.updateSelectedDevicePolicy(quietStart: "22:00", quietEnd: "07:00", tz: "Europe/Paris")
            } else {
              try? await model.updateSelectedDevicePolicy(quietStart: "12:00", quietEnd: "12:00", tz: "Europe/Paris")
            }
          }
        }
      ))

      if isScheduleEnabled {
        VStack(alignment: .leading, spacing: 8) {
          Text("Quiet hours")
            .font(.subheadline.weight(.semibold))

          HStack {
            DatePicker("Start", selection: Binding(
              get: { parseTimeOrDefault(quietStart) },
              set: { quietStart = formatTime($0) }
            ), displayedComponents: .hourAndMinute)
            .labelsHidden()

            DatePicker("End", selection: Binding(
              get: { parseTimeOrDefault(quietEnd) },
              set: { quietEnd = formatTime($0) }
            ), displayedComponents: .hourAndMinute)
            .labelsHidden()
          }

          Button("Save schedule") {
            Task {
              do {
                try await model.updateSelectedDevicePolicy(
                  quietStart: quietStart.trimmingCharacters(in: .whitespacesAndNewlines),
                  quietEnd: quietEnd.trimmingCharacters(in: .whitespacesAndNewlines),
                  tz: "Europe/Paris"
                )
              } catch {
                status = String(describing: error)
              }
            }
          }
          .buttonStyle(.bordered)
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Gap threshold")
          .font(.subheadline.weight(.semibold))

        HStack {
          TextField("Minutes", text: $gapMinutesText)
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
          Button("Save") {
            Task {
              do {
                let m = Int(gapMinutesText.trimmingCharacters(in: .whitespacesAndNewlines))
                if let m, m > 0 {
                  try await model.updateSelectedDevicePolicy(gapMinutes: m)
                }
              } catch {
                status = String(describing: error)
              }
            }
          }
          .buttonStyle(.bordered)
        }
      }

      if let code = pairingCode {
        Text("Pairing code: \(code)")
          .font(.system(.footnote, design: .monospaced))
          .textSelection(.enabled)
      }

      if let status {
        Text(status)
          .font(.footnote)
          .foregroundStyle(.red)
      }
    }
    .padding()
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

#Preview {
  ParentDashboardView()
    .environmentObject(AppModel())
}
#endif

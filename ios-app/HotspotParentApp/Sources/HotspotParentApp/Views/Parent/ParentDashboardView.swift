import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentDashboardView: View {
  @EnvironmentObject private var model: AppModel
  @State private var showingShortcutHelp = false

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        if !model.adsRemoved {
          adCard
        }

        DeviceCarouselView()
          .environmentObject(model)

        if let d = model.selectedParentDevice {
          PolicyEditorCard(device: d)
            .environmentObject(model)
        }

        recentActivityCard

        troubleshootingCard
      }
      .padding(.top, 22)
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
    .task {
      await model.refreshParentDashboard()
    }
    .sheet(isPresented: $model.presentEnrollSheet) {
      AddDeviceSheetView()
        .environmentObject(model)
    }
    .sheet(isPresented: $showingShortcutHelp) {
      ShortcutNotRunningSheetView()
    }
  }

  private var adCard: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("Ad")
          .font(.caption.weight(.medium))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.primary.opacity(0.08))
          .clipShape(RoundedRectangle(cornerRadius: 999))
        Spacer()
      }

      Text("SpeedifyPress — Make WordPress Fast")
        .font(.headline)

      Text("Real‑world performance audits + fixes. (Prototype placeholder)")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  private var recentActivityCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Recent activity")
        .font(.headline)

      VStack(alignment: .leading, spacing: 12) {
        Text("15:05 — Activity OK").font(.subheadline.weight(.semibold))
        Text("15:20 — Policy fetch OK").font(.subheadline.weight(.semibold))
        Text("15:35 — Policy run logged").font(.subheadline.weight(.semibold))
      }
      .foregroundStyle(.primary)

      Text("Tip: this list is scrollable; details are inline (no tap-to-open).")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  private var troubleshootingCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Troubleshooting")
        .font(.headline)

      Button {
        showingShortcutHelp = true
      } label: {
        Label("Shortcut not running", systemImage: "wrench.and.screwdriver")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)

      Button(role: .destructive) {
        model.resetLocalData()
      } label: {
        Label("Remove device", systemImage: "trash")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .tint(.red)
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
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
  @State private var status: String?

  private var isActive: Bool {
    // For now treat enforce as active if hotspotOff action is enabled.
    device.actions.setHotspotOff
  }

  init(device: DashboardDevice) {
    self.device = device
    _quietStart = State(initialValue: device.quietHours?.start ?? "22:00")
    _quietEnd = State(initialValue: device.quietHours?.end ?? "07:00")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Device rules")
            .font(.headline)
          Text("Last seen: 12m ago")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Text(isActive ? "Active" : "Inactive")
          .font(.caption.weight(.semibold))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background((isActive ? Color.green : Color.secondary).opacity(0.15))
          .foregroundStyle(isActive ? .green : .secondary)
          .clipShape(Capsule())
      }

      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Hotspot OFF")
            .font(.subheadline.weight(.semibold))
          Text("Shortcut turns off hotspot + rotates password")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Toggle("", isOn: Binding(
          get: { device.actions.setHotspotOff },
          set: { v in Task { try? await model.updateSelectedDevicePolicy(setHotspotOff: v) } }
        ))
        .labelsHidden()
      }

      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Set schedule")
            .font(.subheadline.weight(.semibold))
          Text("Quiet hours for this device")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Toggle("", isOn: Binding(
          get: {
            let s = device.quietHours?.start ?? "12:00"
            let e = device.quietHours?.end ?? "12:00"
            return s != e
          },
          set: { enabled in
            Task {
              if enabled {
                try? await model.updateSelectedDevicePolicy(quietStart: quietStart, quietEnd: quietEnd, tz: "Europe/Paris")
              } else {
                try? await model.updateSelectedDevicePolicy(quietStart: "12:00", quietEnd: "12:00", tz: "Europe/Paris")
              }
            }
          }
        ))
        .labelsHidden()
      }

      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Start")
            .font(.caption)
            .foregroundStyle(.secondary)
          TextField("22:00", text: $quietStart)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
        }
        VStack(alignment: .leading, spacing: 4) {
          Text("End")
            .font(.caption)
            .foregroundStyle(.secondary)
          TextField("07:00", text: $quietEnd)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
        }
      }

      Button {
        status = nil
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
      } label: {
        Label("Save rules", systemImage: "slider.horizontal.3")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)

      if let status {
        Text(status)
          .font(.footnote)
          .foregroundStyle(.red)
      }
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }
}

#Preview {
  ParentDashboardView()
    .environmentObject(AppModel())
}
#endif

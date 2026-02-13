import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentDashboardView: View {
  @EnvironmentObject private var model: AppModel

  @State private var detailsDeviceId: String?

  public init() {}

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          header

          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(model.parentDevices, id: \.id) { d in
              DeviceTileView(device: d) {
                // Open device details
                model.selectedDeviceId = d.id
                detailsDeviceId = d.id
              } onMore: {
                model.selectedDeviceId = d.id
                detailsDeviceId = d.id
              }
            }
          }

          if model.parentDevices.isEmpty {
            Text("No devices yet. Tap + to enroll one.")
              .font(.footnote)
              .foregroundStyle(.secondary)
              .padding(.top, 6)
          }

          // Optional ad placeholder (can be removed once IAP is wired)
          if !model.adsRemoved {
            adCard
          }
        }
        .padding(.top, 18)
        .padding(.horizontal, 18)
        .padding(.bottom, 32)
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            model.presentEnrollSheet = true
          } label: {
            Image(systemName: "plus")
              .font(.body.weight(.semibold))
          }
          .accessibilityLabel("Add device")
        }
      }
      .sheet(isPresented: $model.presentEnrollSheet) {
        AddDeviceSheetView()
          .environmentObject(model)
      }
      .sheet(item: Binding(
        get: { detailsDeviceId.map { DeviceDetailsSheet.ID(rawValue: $0) } },
        set: { detailsDeviceId = $0?.rawValue }
      )) { id in
        if let d = model.parentDevices.first(where: { $0.id == id.rawValue }) {
          DeviceDetailsSheet(device: d)
            .environmentObject(model)
        }
      }
      .task {
        await model.refreshParentDashboard()
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Devices")
        .font(.system(size: 34, weight: .bold))
        .padding(.top, 2)

      Text("Tap a device to view rules and recent activity.")
        .font(.footnote)
        .foregroundStyle(.secondary)
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
}

private struct DeviceTileView: View {
  let device: DashboardDevice
  var onTap: () -> Void
  var onMore: () -> Void

  private var gradient: LinearGradient {
    // Roughly Shortcuts-style colored tiles.
    switch device.status {
      case "OK":
        return LinearGradient(colors: [Color(red: 0.20, green: 0.45, blue: 1.0), Color(red: 0.31, green: 0.55, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
      case "STALE":
        return LinearGradient(colors: [Color(red: 0.35, green: 0.35, blue: 0.40), Color(red: 0.20, green: 0.20, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing)
      default:
        return LinearGradient(colors: [Color(red: 0.54, green: 0.36, blue: 1.0), Color(red: 0.35, green: 0.49, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
  }

  var body: some View {
    Button {
      onTap()
    } label: {
      ZStack {
        RoundedRectangle(cornerRadius: 22)
          .fill(gradient)

        VStack(alignment: .leading, spacing: 10) {
          HStack {
            ZStack {
              RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.22))
                .overlay(
                  RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
              Text(String(device.name.prefix(1)).uppercased())
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.95))
            }
            .frame(width: 28, height: 28)

            Spacer()

            Button {
              onMore()
            } label: {
              Image(systemName: "ellipsis")
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.16))
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
          }

          Spacer(minLength: 0)

          Text(device.name)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white.opacity(0.95))
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
      }
      .frame(height: 110)
    }
    .buttonStyle(.plain)
  }
}

private struct DeviceDetailsSheet: View {
  struct ID: Identifiable {
    let rawValue: String
    var id: String { rawValue }
  }

  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss

  let device: DashboardDevice

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          PolicyEditorCard(device: device)
            .environmentObject(model)

          recentActivityCard

          troubleshootingCard
        }
        .padding(.top, 18)
        .padding(.horizontal, 18)
        .padding(.bottom, 32)
      }
      .navigationTitle(device.name)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
    }
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
        // Keep minimal for now.
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

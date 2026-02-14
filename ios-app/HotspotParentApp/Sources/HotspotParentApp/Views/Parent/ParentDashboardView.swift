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
              }
            }
          }

          if model.parentDevices.isEmpty {
            Text("No devices yet. Tap + to enroll one.")
              .font(.footnote)
              .foregroundStyle(.secondary)
              .padding(.top, 6)
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
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("All Child Devices")
          .font(.system(size: 34, weight: .bold))
          .padding(.top, 2)

        Text("Tap a device to view rules and recent activity.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button {
        model.presentEnrollSheet = true
      } label: {
        Image(systemName: "plus")
          .font(.title3.weight(.semibold))
          .frame(width: 44, height: 44)
          .background(Color.white.opacity(0.08))
          .clipShape(Circle())
      }
      .accessibilityLabel("Add device")
      .padding(.top, 4)
    }
  }
}

private struct DeviceTileView: View {
  let device: DashboardDevice
  var onTap: () -> Void

  private var gradient: LinearGradient {
    // Shortcuts-like colored tiles, but avoid the app's blue/pink.
    // Use a stable per-device palette selection.
    let gradients: [LinearGradient] = [
      LinearGradient(colors: [Color(red: 0.00, green: 0.76, blue: 0.66), Color(red: 0.18, green: 0.83, blue: 0.44)], startPoint: .topLeading, endPoint: .bottomTrailing), // teal→green
      LinearGradient(colors: [Color(red: 0.54, green: 0.36, blue: 1.0), Color(red: 0.35, green: 0.49, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing), // purple
      LinearGradient(colors: [Color(red: 0.93, green: 0.58, blue: 0.12), Color(red: 0.93, green: 0.40, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing), // orange
      LinearGradient(colors: [Color(red: 0.20, green: 0.70, blue: 0.30), Color(red: 0.10, green: 0.50, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing), // green
    ]

    let idx = Self.stableColorIndex(device.id.isEmpty ? device.name : device.id, mod: gradients.count)
    return gradients[idx]
  }

  private static func stableColorIndex(_ s: String, mod: Int) -> Int {
    // deterministic hash (don’t use Swift's Hashable which can vary between runs)
    let v = s.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
    return abs(v) % max(mod, 1)
  }

  var body: some View {
    Button {
      onTap()
    } label: {
      ZStack {
        RoundedRectangle(cornerRadius: 22)
          .fill(gradient)

        VStack(alignment: .leading, spacing: 10) {
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

          Spacer(minLength: 0)

          Text(device.name)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white.opacity(0.95))
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
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
        }
        .padding(.top, 18)
        .padding(.horizontal, 18)
        .padding(.bottom, 32)
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          deviceTitleMenu
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
      .alert("Action failed", isPresented: Binding(
        get: { actionError != nil },
        set: { if !$0 { actionError = nil } }
      )) {
        Button("OK", role: .cancel) { actionError = nil }
      } message: {
        Text(actionError ?? "Unknown error")
      }
    }
  }

  @State private var showRename = false
  @State private var renameText: String = ""
  @State private var showDeleteConfirm = false
  @State private var actionError: String?

  private var deviceTitleMenu: some View {
    Menu {
      Button {
        renameText = device.name
        showRename = true
      } label: {
        Label("Rename", systemImage: "pencil")
      }

      Button {
        // Placeholder: icon selection UI can be added later.
      } label: {
        Label("Choose icon", systemImage: "square.dashed")
      }

      Divider()

      Button(role: .destructive) {
        showDeleteConfirm = true
      } label: {
        Label("Delete", systemImage: "trash")
      }
    } label: {
      HStack(spacing: 6) {
        Text(device.name)
          .font(.headline.weight(.semibold))
        Image(systemName: "chevron.down")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    .confirmationDialog(
      "Delete this device?",
      isPresented: $showDeleteConfirm,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        Task {
          do {
            try await model.deleteDevice(deviceId: device.id)
            dismiss()
          } catch {
            actionError = String(describing: error)
          }
        }
      }
      Button("Cancel", role: .cancel) {}
    }
    .alert("Rename device", isPresented: $showRename) {
      TextField("Name", text: $renameText)
      Button("Save") {
        Task {
          do {
            let t = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            try await model.renameDevice(deviceId: device.id, name: t)
          } catch {
            actionError = String(describing: error)
          }
        }
      }
      Button("Cancel", role: .cancel) {}
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
}

private struct PolicyEditorCard: View {
  @EnvironmentObject private var model: AppModel

  let device: DashboardDevice

  @State private var hotspotOff: Bool
  @State private var quiet: Bool

  @State private var startDate: Date
  @State private var endDate: Date

  init(device: DashboardDevice) {
    self.device = device

    _hotspotOff = State(initialValue: device.actions.setHotspotOff)
    _quiet = State(initialValue: device.quietHours != nil)

    // Use wheel time pickers like iOS Settings.
    let start = device.quietHours?.start ?? "22:00"
    let end = device.quietHours?.end ?? "07:00"
    _startDate = State(initialValue: Self.parseTime(start) ?? Date())
    _endDate = State(initialValue: Self.parseTime(end) ?? Date())
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Rules")
        .font(.headline)

      Toggle(isOn: $hotspotOff) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Hotspot OFF")
            .font(.subheadline.weight(.semibold))
          Text("Shortcut turns off hotspot + rotates password")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

      Toggle(isOn: $quiet) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Set schedule")
            .font(.subheadline.weight(.semibold))
          Text("Quiet hours for this device")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

      if quiet {
        VStack(alignment: .leading, spacing: 8) {
          Text("Quiet hours")
            .font(.subheadline.weight(.semibold))

          GeometryReader { geo in
            let colW = (geo.size.width - 12) / 2
            HStack(alignment: .top, spacing: 12) {
              VStack(alignment: .leading, spacing: 6) {
                Text("Start")
                  .font(.caption)
                  .foregroundStyle(.secondary)

                DatePicker("", selection: $startDate, displayedComponents: .hourAndMinute)
                  .labelsHidden()
                  .datePickerStyle(.wheel)
                  .environment(\.locale, Locale(identifier: "en_GB"))
                  .frame(width: colW, height: 140)
                  .clipped()
              }
              .frame(width: colW)

              VStack(alignment: .leading, spacing: 6) {
                Text("End")
                  .font(.caption)
                  .foregroundStyle(.secondary)

                DatePicker("", selection: $endDate, displayedComponents: .hourAndMinute)
                  .labelsHidden()
                  .datePickerStyle(.wheel)
                  .environment(\.locale, Locale(identifier: "en_GB"))
                  .frame(width: colW, height: 140)
                  .clipped()
              }
              .frame(width: colW)
            }
          }
          .frame(height: 170)
          .padding(10)
          .background(Color.white.opacity(0.04))
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(Color.white.opacity(0.08), lineWidth: 1)
          )
        }
        .padding(.top, 2)
      }

      Button {
        // TODO: wire to backend
        let start = Self.formatTime(startDate)
        let end = Self.formatTime(endDate)
        _ = start
        _ = end
      } label: {
        Label("Save rules", systemImage: "slider.horizontal.3")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(.blue)
      .padding(.top, 6)
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
  }

  private static func parseTime(_ s: String) -> Date? {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = .current
    df.dateFormat = "HH:mm"

    guard let t = df.date(from: s.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }

    let cal = Calendar.current
    let comps = cal.dateComponents([.hour, .minute], from: t)
    return cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: Date())
  }

  private static func formatTime(_ d: Date) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = .current
    df.dateFormat = "HH:mm"
    return df.string(from: d)
  }
}

#Preview {
  ParentDashboardView()
    .environmentObject(AppModel())
}
#endif

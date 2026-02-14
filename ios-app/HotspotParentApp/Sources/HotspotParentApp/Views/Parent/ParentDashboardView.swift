import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(PhotosUI)
import PhotosUI
#endif

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
  @EnvironmentObject private var model: AppModel
  let device: DashboardDevice
  var onTap: () -> Void

  private var gradient: LinearGradient {
    // Shortcuts-like colored tiles with a wide hue space so devices don't collide.
    // We also try to avoid the app's blue/pink range so tiles feel distinct.
    let hue = Self.stableHue(device.id.isEmpty ? device.name : device.id)

    let c1 = Color(hue: hue, saturation: 0.82, brightness: 0.92)
    let c2 = Color(hue: fmod(hue + 0.06, 1.0), saturation: 0.88, brightness: 0.74)

    return LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
  }

  private static func stableHue(_ s: String) -> Double {
    // deterministic hash (don’t use Swift's Hashable which can vary between runs)
    let v = s.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
    var hue = Double(abs(v) % 360) / 360.0

    // Avoid a blue band (~0.55–0.70) and a pink band (~0.85–0.98)
    if hue >= 0.55 && hue <= 0.70 { hue = fmod(hue + 0.18, 1.0) }
    if hue >= 0.85 && hue <= 0.98 { hue = fmod(hue - 0.22 + 1.0, 1.0) }

    return hue
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

            #if canImport(UIKit)
            if let img = DevicePhotoStore.getUIImage(deviceId: device.id) {
              Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(
                  RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .padding(1)
            } else {
              Text(String(device.name.prefix(1)).uppercased())
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.95))
            }
            #else
            Text(String(device.name.prefix(1)).uppercased())
              .font(.headline.weight(.bold))
              .foregroundStyle(.white.opacity(0.95))
            #endif
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

  #if canImport(PhotosUI)
  @State private var pickedPhoto: PhotosPickerItem?
  #endif

  private var deviceTitleMenu: some View {
    Menu {
      Button {
        renameText = device.name
        showRename = true
      } label: {
        Label("Rename", systemImage: "pencil")
      }

      #if canImport(PhotosUI)
      PhotosPicker(selection: $pickedPhoto, matching: .images, photoLibrary: .shared()) {
        Label("Choose photo", systemImage: "photo")
      }
      #else
      Button {
        // Placeholder: photo picker unavailable on this build target.
      } label: {
        Label("Choose photo", systemImage: "photo")
      }
      #endif

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
    .onChange(of: pickedPhoto) { item in
      guard let item else { return }
      Task {
        do {
          if let data = try await item.loadTransferable(type: Data.self) {
            model.setDevicePhoto(deviceId: device.id, jpegData: data)
          }
        } catch {
          actionError = String(describing: error)
        }
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

  @State private var events: [DeviceEventRow] = []
  @State private var eventsLoading: Bool = false

  private var recentActivityCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Recent activity")
          .font(.headline)
        Spacer()
        if eventsLoading {
          ProgressView().scaleEffect(0.9)
        }
      }

      if events.isEmpty {
        Text("No activity yet.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(events.prefix(8), id: \.id) { e in
            Text("\(Self.formatEventTime(e.ts)) — \(Self.formatTrigger(e.trigger))")
              .font(.subheadline.weight(.semibold))
          }
        }
      }

      Text("Tip: this list is inline (no tap-to-open).")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
    .task {
      await loadEvents()
    }
  }

  private func loadEvents() async {
    eventsLoading = true
    defer { eventsLoading = false }

    do {
      let out = try await model.fetchDeviceEvents(deviceId: device.id)
      events = out.sorted(by: { $0.ts > $1.ts })
    } catch {
      // best-effort; don't block details view
      events = []
    }
  }

  private static func formatEventTime(_ ts: Int) -> String {
    let d = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: d)
  }

  private static func formatTrigger(_ t: String) -> String {
    switch t {
      case "policy_fetch": return "Policy fetch"
      default: return t.replacingOccurrences(of: "_", with: " ")
    }
  }
}

private struct PolicyEditorCard: View {
  @EnvironmentObject private var model: AppModel

  let device: DashboardDevice

  @State private var hotspotOff: Bool
  @State private var wifiOff: Bool
  @State private var mobileDataOff: Bool

  @State private var quiet: Bool

  @State private var startDate: Date
  @State private var endDate: Date

  @State private var saveTask: Task<Void, Never>?
  @State private var saving: Bool = false

  init(device: DashboardDevice) {
    self.device = device

    _hotspotOff = State(initialValue: device.actions.setHotspotOff)
    _wifiOff = State(initialValue: device.actions.setWifiOff)
    _mobileDataOff = State(initialValue: device.actions.setMobileDataOff)
    _quiet = State(initialValue: device.quietHours != nil)

    // Use wheel time pickers like iOS Settings.
    let start = device.quietHours?.start ?? "22:00"
    let end = device.quietHours?.end ?? "07:00"
    _startDate = State(initialValue: Self.parseTime(start) ?? Date())
    _endDate = State(initialValue: Self.parseTime(end) ?? Date())
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Schedule box (first)
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text("Schedule")
            .font(.headline)
          Spacer()
          if saving {
            Text("Saving…")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }

        Toggle(isOn: $quiet) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Quiet hours")
              .font(.subheadline.weight(.semibold))
            Text("Pause enforcement during this time")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
        .onChange(of: quiet) { _ in scheduleSave() }

        if quiet {
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
                  .onChange(of: startDate) { _ in scheduleSave() }
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
                  .onChange(of: endDate) { _ in scheduleSave() }
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
      }
      .padding(18)
      .background(Color.primary.opacity(0.06))
      .clipShape(RoundedRectangle(cornerRadius: 22))

      // Rules box (second)
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
        .onChange(of: hotspotOff) { _ in scheduleSave() }

        Toggle(isOn: $wifiOff) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Wi‑Fi OFF")
              .font(.subheadline.weight(.semibold))
            Text("Turn off Wi‑Fi")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
        .onChange(of: wifiOff) { _ in scheduleSave() }

        Toggle(isOn: $mobileDataOff) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Mobile Data OFF")
              .font(.subheadline.weight(.semibold))
            Text("Turn off cellular data")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
        .onChange(of: mobileDataOff) { _ in scheduleSave() }
      }
      .padding(18)
      .background(Color.primary.opacity(0.06))
      .clipShape(RoundedRectangle(cornerRadius: 22))
    }
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

  private func scheduleSave() {
    saveTask?.cancel()
    saveTask = Task {
      try? await Task.sleep(nanoseconds: 600_000_000) // debounce
      await saveNow()
    }
  }

  @MainActor
  private func saveNow() async {
    saving = true
    defer { saving = false }

    let qs = quiet ? Self.formatTime(startDate) : nil
    let qe = quiet ? Self.formatTime(endDate) : nil

    do {
      try await model.updateSelectedDevicePolicy(
        setHotspotOff: hotspotOff,
        setWifiOff: wifiOff,
        setMobileDataOff: mobileDataOff,
        quietStart: qs,
        quietEnd: qe,
        tz: "Europe/Paris"
      )
    } catch {
      // Best-effort; errors are shown elsewhere in the sheet.
    }
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

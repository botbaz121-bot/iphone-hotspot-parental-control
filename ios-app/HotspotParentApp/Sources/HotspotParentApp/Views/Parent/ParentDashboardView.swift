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
            ForEach(Array(model.parentDevices.enumerated()), id: \.element.id) { idx, d in
              DeviceTileView(device: d, colorIndex: idx) {
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
  let colorIndex: Int
  var onTap: () -> Void

  private var gradient: LinearGradient {
    // Rotate between 8 very distinct gradients by *tile index*.
    // This prevents same-looking tiles for small numbers of devices.
    let palette: [LinearGradient] = [
      LinearGradient(colors: [Color(red: 0.98, green: 0.40, blue: 0.33), Color(red: 0.82, green: 0.18, blue: 0.27)], startPoint: .topLeading, endPoint: .bottomTrailing), // red
      LinearGradient(colors: [Color(red: 1.00, green: 0.62, blue: 0.22), Color(red: 0.93, green: 0.36, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), // orange
      LinearGradient(colors: [Color(red: 0.98, green: 0.86, blue: 0.18), Color(red: 0.78, green: 0.62, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing), // yellow
      LinearGradient(colors: [Color(red: 0.32, green: 0.86, blue: 0.36), Color(red: 0.12, green: 0.62, blue: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing), // green
      LinearGradient(colors: [Color(red: 0.22, green: 0.86, blue: 0.78), Color(red: 0.08, green: 0.62, blue: 0.64)], startPoint: .topLeading, endPoint: .bottomTrailing), // teal
      LinearGradient(colors: [Color(red: 0.74, green: 0.40, blue: 1.00), Color(red: 0.46, green: 0.34, blue: 1.00)], startPoint: .topLeading, endPoint: .bottomTrailing), // purple
      LinearGradient(colors: [Color(red: 1.00, green: 0.36, blue: 0.72), Color(red: 0.88, green: 0.18, blue: 0.56)], startPoint: .topLeading, endPoint: .bottomTrailing), // magenta
      LinearGradient(colors: [Color(red: 0.58, green: 0.72, blue: 1.00), Color(red: 0.24, green: 0.46, blue: 0.98)], startPoint: .topLeading, endPoint: .bottomTrailing), // blue
    ]

    let idx = ((colorIndex % palette.count) + palette.count) % palette.count
    return palette[idx]
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
  @State private var showPhotoPicker: Bool = false
  #endif

  #if canImport(UIKit)
  @State private var imageToCrop: UIImage?
  @State private var showCropper: Bool = false
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
      Button {
        showPhotoPicker = true
      } label: {
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
      HStack(spacing: 8) {
        #if canImport(UIKit)
        if let img = DevicePhotoStore.getUIImage(deviceId: device.id) {
          Image(uiImage: img)
            .resizable()
            .scaledToFill()
            .frame(width: 26, height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
              RoundedRectangle(cornerRadius: 7)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        } else {
          ZStack {
            RoundedRectangle(cornerRadius: 7)
              .fill(Color.white.opacity(0.10))
              .overlay(
                RoundedRectangle(cornerRadius: 7)
                  .stroke(Color.white.opacity(0.12), lineWidth: 1)
              )
            Text(String(device.name.prefix(1)).uppercased())
              .font(.caption.weight(.bold))
              .foregroundStyle(.white.opacity(0.9))
          }
          .frame(width: 26, height: 26)
        }
        #endif

        Text(device.name)
          .font(.headline.weight(.semibold))
          .lineLimit(1)
          .truncationMode(.tail)

        Image(systemName: "chevron.down")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    #if canImport(PhotosUI)
    .photosPicker(
      isPresented: $showPhotoPicker,
      selection: $pickedPhoto,
      matching: .images,
      photoLibrary: .shared()
    )
    .onChange(of: pickedPhoto) { item in
      guard let item else { return }
      Task {
        do {
          if let data = try await item.loadTransferable(type: Data.self) {
            #if canImport(UIKit)
            if let img = UIImage(data: data) {
              imageToCrop = img
              showCropper = true
            } else {
              model.setDevicePhoto(deviceId: device.id, jpegData: data)
            }
            #else
            model.setDevicePhoto(deviceId: device.id, jpegData: data)
            #endif
          }
        } catch {
          actionError = String(describing: error)
        }
      }
    }
    #endif
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
    #if canImport(UIKit) && canImport(TOCropViewController)
    .sheet(isPresented: $showCropper) {
      if let img = imageToCrop {
        ImageCropperView(
          image: img,
          onCropped: { cropped in
            let jpeg = cropped.jpegData(compressionQuality: 0.85)
            model.setDevicePhoto(deviceId: device.id, jpegData: jpeg)
            showCropper = false
            imageToCrop = nil
          },
          onCancel: {
            showCropper = false
            imageToCrop = nil
          }
        )
        .ignoresSafeArea()
      }
    }
    #endif

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
        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            ForEach(events.prefix(100), id: \.id) { e in
              HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Self.formatEventTime(e.ts))
                  .font(.subheadline.weight(.semibold))
                  .monospacedDigit()
                  .frame(width: 120, alignment: .leading)
                Text(Self.formatTrigger(e.trigger))
                  .font(.subheadline.weight(.semibold))
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 168) // ~5 rows
        .scrollIndicators(.hidden)
      }
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
    f.locale = .current
    f.timeZone = .current
    f.dateStyle = .short
    f.timeStyle = .short

    // Examples: 14/02/2026, 16:44
    return f.string(from: d)
  }

  private static func formatTrigger(_ t: String) -> String {
    switch t {
      case "policy_fetch": return "Checked status"
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
  @State private var selectedDay: String = "mon"
  @State private var quietDays: [String: UpdatePolicyRequest.QuietDayWindow] = [:]

  @State private var startDate: Date
  @State private var endDate: Date

  @State private var saveTask: Task<Void, Never>?
  @State private var saving: Bool = false

  init(device: DashboardDevice) {
    self.device = device

    _hotspotOff = State(initialValue: device.actions.setHotspotOff)
    _wifiOff = State(initialValue: device.actions.setWifiOff)
    _mobileDataOff = State(initialValue: device.actions.setMobileDataOff)
    _quiet = State(initialValue: device.quietDays != nil)

    let initialDay = device.quietDay ?? "mon"
    _selectedDay = State(initialValue: initialDay)

    // Initialize quietDays state from backend
    var qd: [String: UpdatePolicyRequest.QuietDayWindow] = [:]
    if let src = device.quietDays {
      for (k, v) in src {
        qd[k] = UpdatePolicyRequest.QuietDayWindow(start: v.start, end: v.end)
      }
    }
    _quietDays = State(initialValue: qd)

    // Pickers show the selected day values (or defaults)
    let start = qd[initialDay]?.start ?? "22:00"
    let end = qd[initialDay]?.end ?? "07:00"
    _startDate = State(initialValue: Self.parseTime(start) ?? Date())
    _endDate = State(initialValue: Self.parseTime(end) ?? Date())
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
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

      // Schedule box (first)
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text("Schedule")
            .font(.headline)
          Spacer()
        }

        Toggle(isOn: $quiet) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Enforcement schedule")
              .font(.subheadline.weight(.semibold))
            Text("Enforcement only active during this time. Always on if not set")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
        .onChange(of: quiet) { isOn in
          if !isOn {
            quietDays = [:]
          } else if quietDays.isEmpty {
            // seed all days with current picker values
            let s = Self.formatTime(startDate)
            let e = Self.formatTime(endDate)
            quietDays = [
              "mon": .init(start: s, end: e),
              "tue": .init(start: s, end: e),
              "wed": .init(start: s, end: e),
              "thu": .init(start: s, end: e),
              "fri": .init(start: s, end: e),
              "sat": .init(start: s, end: e),
              "sun": .init(start: s, end: e),
            ]
          }
          scheduleSave()
        }

        if quiet {
          // Day selector (horiz scroll so it never wraps)
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(["sun","mon","tue","wed","thu","fri","sat"], id: \.self) { d in
                Button {
                  selectedDay = d
                  let start = quietDays[d]?.start ?? "22:00"
                  let end = quietDays[d]?.end ?? "07:00"
                  startDate = Self.parseTime(start) ?? startDate
                  endDate = Self.parseTime(end) ?? endDate
                } label: {
                  Text(Self.dayLabel(d))
                    .font(.caption.weight(.semibold))
                    .frame(width: 30, height: 28)
                    .background(selectedDay == d ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                    .overlay(
                      RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(selectedDay == d ? 0.35 : 0.10), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
              }
            }
            .padding(.vertical, 2)
          }

          GeometryReader { geo in
            let spacing: CGFloat = 18
            let colW = (geo.size.width - spacing) / 2
            HStack(alignment: .top, spacing: spacing) {
              VStack(alignment: .leading, spacing: 6) {
                Text("Start")
                  .font(.caption)
                  .foregroundStyle(.secondary)

                DatePicker("", selection: $startDate, displayedComponents: .hourAndMinute)
                  .labelsHidden()
                  .datePickerStyle(.wheel)
                  .environment(\.locale, Locale(identifier: "en_GB"))
                  .frame(width: colW, height: 150)
                  .clipped()
                  .contentShape(Rectangle())
                  .onChange(of: startDate) { _ in
                    quietDays[selectedDay] = .init(start: Self.formatTime(startDate), end: Self.formatTime(endDate))
                    scheduleSave()
                  }
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
                  .frame(width: colW, height: 150)
                  .clipped()
                  .contentShape(Rectangle())
                  .onChange(of: endDate) { _ in
                    quietDays[selectedDay] = .init(start: Self.formatTime(startDate), end: Self.formatTime(endDate))
                    scheduleSave()
                  }
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
          HStack {
            Spacer()
            Button {
              let s = Self.formatTime(startDate)
              let e = Self.formatTime(endDate)
              quietDays = [
                "mon": .init(start: s, end: e),
                "tue": .init(start: s, end: e),
                "wed": .init(start: s, end: e),
                "thu": .init(start: s, end: e),
                "fri": .init(start: s, end: e),
                "sat": .init(start: s, end: e),
                "sun": .init(start: s, end: e),
              ]
              scheduleSave()
            } label: {
              Text("Copy to all days")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .overlay(
                  RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
          }

        }
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

  private static func dayLabel(_ k: String) -> String {
    switch k {
      case "mon": return "M"
      case "tue": return "T"
      case "wed": return "W"
      case "thu": return "T"
      case "fri": return "F"
      case "sat": return "S"
      case "sun": return "S"
      default: return "?"
    }
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

    do {
      try await model.updateSelectedDevicePolicy(
        setHotspotOff: hotspotOff,
        setWifiOff: wifiOff,
        setMobileDataOff: mobileDataOff,
        quietDays: quiet ? quietDays : nil,
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

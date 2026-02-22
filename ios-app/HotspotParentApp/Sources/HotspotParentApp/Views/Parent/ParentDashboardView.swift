import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(PhotosUI)
import PhotosUI
#endif

public struct ParentDashboardView: View {
  @EnvironmentObject private var model: AppModel

  @State private var detailsDeviceId: String?
  @State private var detailsParentEntryId: String?
  @State private var showCreateInviteSheet: Bool = false

  public init() {}

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          header

          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(Array(model.parentDevices.enumerated()), id: \.element.id) { idx, d in
              DeviceTileView(device: d, colorIndex: idx) {
                // Refresh before opening details so settings view starts with latest policy.
                Task {
                  await model.refreshParentDashboard()
                  model.selectedDeviceId = d.id
                  detailsDeviceId = d.id
                }
              }
            }
          }

          if model.parentDevices.isEmpty {
            Text("No devices yet. Tap + to enroll one.")
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
              .padding(.top, 6)
          }

          parentDevicesSection
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
      .sheet(item: Binding(
        get: { detailsParentEntryId.map { ParentPersonDetailsSheet.ID(rawValue: $0) } },
        set: { detailsParentEntryId = $0?.rawValue }
      )) { id in
        if let entry = parentEntries.first(where: { $0.id == id.rawValue }) {
          ParentPersonDetailsSheet(entry: entry)
            .environmentObject(model)
        }
      }
      .sheet(isPresented: $showCreateInviteSheet) {
        CreateParentInviteSheet()
          .environmentObject(model)
      }
      .task {
        await model.refreshParentDashboard()
        if let openId = model.pendingOpenDeviceDetailsId {
          detailsDeviceId = openId
          model.pendingOpenDeviceDetailsId = nil
        }
      }
      .onChange(of: model.pendingOpenDeviceDetailsId) { id in
        guard let id else { return }
        detailsDeviceId = id
        model.pendingOpenDeviceDetailsId = nil
      }
    }
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Child Devices")
          .font(.system(size: 34, weight: .bold))
          .padding(.top, 2)
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

  private var parentDevicesSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        Text("Parent Devices")
          .font(.system(size: 34, weight: .bold))
          .padding(.top, 2)
        Spacer()
        Button {
          showCreateInviteSheet = true
        } label: {
          Image(systemName: "plus")
            .font(.title3.weight(.semibold))
            .frame(width: 44, height: 44)
            .background(Color.white.opacity(0.08))
            .clipShape(Circle())
        }
        .accessibilityLabel("Add parent invite")
        .padding(.top, 4)
      }

      if parentEntries.isEmpty {
        Text("No parent devices or invites yet.")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
      } else {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
          ForEach(Array(parentEntries.enumerated()), id: \.element.id) { idx, entry in
            ParentPersonTileView(entry: entry, colorIndex: idx) {
              Task {
                await model.refreshParentDashboard()
                detailsParentEntryId = entry.id
              }
            }
              .environmentObject(model)
          }
        }
      }
    }
  }

  private var parentEntries: [ParentTileEntry] {
    var out: [ParentTileEntry] = model.householdMembers
      .filter { $0.status.lowercased() == "active" }
      .map { .member($0) }

    out.append(contentsOf: model.householdInvites
      .filter { $0.status.lowercased() == "pending" }
      .map { .invite($0) })

    return out
  }
}

private struct CreateParentInviteSheet: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss

  @State private var inviteName: String = ""
  @State private var creating: Bool = false
  @State private var createdCode: String?
  @State private var errorText: String?

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 14) {
        Text("Create Invite")
          .font(.system(size: 24, weight: .bold))

        TextField("Name", text: $inviteName)
          .textInputAutocapitalization(.words)
          .disableAutocorrection(true)
          .padding(.horizontal, 12)
          .padding(.vertical, 10)
          .background(Color.primary.opacity(0.06))
          .clipShape(RoundedRectangle(cornerRadius: 12))

        if let code = createdCode {
          VStack(alignment: .leading, spacing: 6) {
            Text("Invite code")
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
            Text(code)
              .font(.system(size: 20, weight: .bold))
              .monospacedDigit()
          }
          .padding(12)
          .background(Color.primary.opacity(0.06))
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        if let errorText {
          Text(errorText)
            .font(.system(size: 14))
            .foregroundStyle(.red)
        }

        Button {
          Task { await createInvite() }
        } label: {
          if creating {
            ProgressView()
              .frame(maxWidth: .infinity)
          } else {
            Text("Create Invite")
              .frame(maxWidth: .infinity)
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(creating)

        Spacer()
      }
      .padding(18)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
    }
  }

  @MainActor
  private func createInvite() async {
    creating = true
    errorText = nil
    defer { creating = false }
    do {
      let name = inviteName.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else {
        errorText = "Invite name is required."
        return
      }
      let invite = try await model.createHouseholdInvite(
        inviteName: name
      )
      createdCode = invite.code
    } catch {
      if let apiErr = error as? APIError {
        errorText = apiErr.userMessage
      } else {
        errorText = "Couldn’t create invite. Please try again."
      }
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

private enum ParentTileEntry: Identifiable {
  case member(HouseholdMember)
  case invite(HouseholdInvite)

  var id: String {
    switch self {
      case .member(let m): return "member:\(m.id)"
      case .invite(let i): return "invite:\(i.id)"
    }
  }

  var photoKey: String {
    switch self {
      case .member(let m): return "parent-member-\(m.id)"
      case .invite(let i): return "parent-invite-\(i.id)"
    }
  }

  var title: String {
    switch self {
      case .member(let m):
        if let d = m.displayName, !d.isEmpty { return d }
        if let e = m.email, !e.isEmpty { return e }
        return "Parent"
      case .invite(let i):
        if let n = i.inviteName, !n.isEmpty { return n }
        if let e = i.email, !e.isEmpty { return e }
        return "Invited parent"
    }
  }

  var subtitle: String {
    switch self {
      case .member(let m): return m.role.capitalized
      case .invite: return "Invite pending"
    }
  }

  func isCurrentParent(_ currentParentId: String?) -> Bool {
    switch self {
      case .member(let m):
        return currentParentId == m.parentId
      case .invite:
        return false
    }
  }

  var canDelete: Bool {
    switch self {
      case .invite:
        return true
      case .member(let m):
        return m.role.lowercased() != "owner"
    }
  }
}

private struct ParentPersonTileView: View {
  let entry: ParentTileEntry
  let colorIndex: Int
  var onTap: () -> Void

  private var gradient: LinearGradient {
    let palette: [LinearGradient] = [
      LinearGradient(colors: [Color(red: 0.15, green: 0.52, blue: 0.98), Color(red: 0.10, green: 0.32, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing),
      LinearGradient(colors: [Color(red: 0.12, green: 0.68, blue: 0.56), Color(red: 0.06, green: 0.46, blue: 0.38)], startPoint: .topLeading, endPoint: .bottomTrailing),
      LinearGradient(colors: [Color(red: 0.86, green: 0.44, blue: 0.24), Color(red: 0.62, green: 0.28, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing),
      LinearGradient(colors: [Color(red: 0.56, green: 0.42, blue: 0.95), Color(red: 0.36, green: 0.26, blue: 0.78)], startPoint: .topLeading, endPoint: .bottomTrailing),
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
            if let img = DevicePhotoStore.getUIImage(deviceId: entry.photoKey) {
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
              Text(String(entry.title.prefix(1)).uppercased())
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.95))
            }
            #else
            Text(String(entry.title.prefix(1)).uppercased())
              .font(.headline.weight(.bold))
              .foregroundStyle(.white.opacity(0.95))
            #endif
          }
          .frame(width: 28, height: 28)

          Spacer(minLength: 0)

          VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
              .font(.system(size: 18, weight: .bold))
              .foregroundStyle(.white.opacity(0.95))
              .lineLimit(2)
              .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.subtitle)
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(.white.opacity(0.82))
              .lineLimit(1)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .padding(14)
      }
      .frame(height: 110)
    }
    .buttonStyle(.plain)
  }
}

private struct ParentPersonDetailsSheet: View {
  struct ID: Identifiable {
    let rawValue: String
    var id: String { rawValue }
  }

  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss

  let entry: ParentTileEntry

  @State private var showRename: Bool = false
  @State private var renameText: String = ""
  @State private var showDeleteConfirm: Bool = false
  @State private var showInviteCode: Bool = false
  @State private var inviteCodeText: String = ""
  @State private var actionError: String?

  #if canImport(PhotosUI)
  @State private var pickedPhoto: PhotosPickerItem?
  @State private var showPhotoPicker: Bool = false
  #endif

  #if canImport(UIKit)
  @State private var imageToCrop: UIImage?
  @State private var showCropper: Bool = false
  #endif

  private var isCurrentParent: Bool { entry.isCurrentParent(model.currentParentId) }
  private var canRename: Bool {
    switch entry {
      case .invite: return true
      case .member: return isCurrentParent
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          notificationSettingsCard
        }
        .padding(.top, 18)
        .padding(.horizontal, 18)
        .padding(.bottom, 32)
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          titleMenu
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
              model.setDevicePhoto(deviceId: entry.photoKey, jpegData: data)
            }
            #else
            model.setDevicePhoto(deviceId: entry.photoKey, jpegData: data)
            #endif
          }
        } catch {
          actionError = userError(error)
        }
      }
    }
    #endif
    #if canImport(UIKit) && canImport(TOCropViewController)
    .sheet(isPresented: $showCropper) {
      if let img = imageToCrop {
        ImageCropperView(
          image: img,
          onCropped: { cropped in
            let jpeg = cropped.jpegData(compressionQuality: 0.85)
            model.setDevicePhoto(deviceId: entry.photoKey, jpegData: jpeg)
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
    .alert("Rename", isPresented: $showRename) {
      TextField("Name", text: $renameText)
      Button("Save") { Task { await saveRename() } }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Update the displayed parent name.")
    }
    .alert("Invite code", isPresented: $showInviteCode) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(inviteCodeText)
    }
    .confirmationDialog(
      "Delete this item?",
      isPresented: $showDeleteConfirm,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        Task { await deleteEntry() }
      }
      Button("Cancel", role: .cancel) {}
    }
  }

  private var titleMenu: some View {
    Menu {
      if canRename {
        Button {
          renameText = entry.title
          showRename = true
        } label: {
          Label("Rename", systemImage: "pencil")
        }
      }

      #if canImport(PhotosUI)
      Button {
        showPhotoPicker = true
      } label: {
        Label("Choose Photo", systemImage: "photo")
      }
      #endif

      Button {
        switch entry {
          case .invite(let invite):
            inviteCodeText = invite.code
          case .member:
            inviteCodeText = "No invite code for active parents."
        }
        showInviteCode = true
      } label: {
        Label("View Invite Code", systemImage: "qrcode")
      }

      if entry.canDelete {
        Divider()
        Button(role: .destructive) {
          showDeleteConfirm = true
        } label: {
          Label("Delete", systemImage: "trash")
        }
      }
    } label: {
      HStack(spacing: 8) {
        #if canImport(UIKit)
        if let img = DevicePhotoStore.getUIImage(deviceId: entry.photoKey) {
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
            Text(String(entry.title.prefix(1)).uppercased())
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(.white.opacity(0.9))
          }
          .frame(width: 26, height: 26)
        }
        #endif

        Text(entry.title)
          .font(.headline.weight(.semibold))
          .lineLimit(1)
          .truncationMode(.tail)

        Image(systemName: "chevron.down")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
      }
    }
  }

  private var notificationSettingsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Notification Settings")
        .font(.headline)

      Toggle(isOn: Binding(
        get: { model.parentNotifyExtraTimeRequests },
        set: { newValue in if isCurrentParent { model.parentNotifyExtraTimeRequests = newValue } }
      )) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Extra time request notifications")
            .font(.system(size: 16, weight: .semibold))
          Text("Show parent alerts when child requests more time.")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        }
      }
      .disabled(!isCurrentParent)

      Toggle(isOn: Binding(
        get: { model.parentNotifyTamperAlerts },
        set: { newValue in if isCurrentParent { model.parentNotifyTamperAlerts = newValue } }
      )) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Tamper notifications")
            .font(.system(size: 16, weight: .semibold))
          Text("Show tamper alerts when available.")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        }
      }
      .disabled(!isCurrentParent)
    }
    .padding(18)
    .background(Color.primary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 22))
    .opacity(isCurrentParent ? 1.0 : 0.6)
  }

  @MainActor
  private func saveRename() async {
    let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !newName.isEmpty else { return }
    do {
      switch entry {
        case .invite(let invite):
          try await model.renameHouseholdInvite(inviteId: invite.id, inviteName: newName)
        case .member:
          guard isCurrentParent else {
            actionError = "You can only rename your own profile."
            return
          }
          try await model.renameCurrentParentProfile(displayName: newName)
      }
    } catch {
      actionError = userError(error)
    }
  }

  @MainActor
  private func deleteEntry() async {
    do {
      switch entry {
        case .invite(let invite):
          try await model.deleteHouseholdInvite(inviteId: invite.id)
          dismiss()
        case .member(let member):
          try await model.deleteHouseholdMember(memberId: member.id)
          dismiss()
      }
    } catch {
      actionError = userError(error)
    }
  }

  private func userError(_ error: Error) -> String {
    if let apiErr = error as? APIError {
      return apiErr.userMessage
    }
    return "That action couldn't be completed. Please try again."
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
      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            PolicyEditorCard(device: device, extraTimeAnchorId: extraTimeAnchorId) {
              Task { await loadEvents() }
            }
              .environmentObject(model)

            recentActivityCard
          }
          .padding(.top, 18)
          .padding(.horizontal, 18)
          .padding(.bottom, 32)
        }
        .onAppear {
          guard !didAutoScrollToExtraTime else { return }
          guard model.extraTimePrefillMinutesByDeviceId[device.id] != nil || model.extraTimePendingRequestIdByDeviceId[device.id] != nil else { return }
          didAutoScrollToExtraTime = true
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.25)) {
              proxy.scrollTo(extraTimeAnchorId, anchor: .top)
            }
          }
        }
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
  @State private var showPairingCodePopup = false
  @State private var pairingCodeText: String = ""
  @State private var pairingCodeBusy = false
  @State private var didAutoScrollToExtraTime = false
  private let extraTimeAnchorId = "extraTimeSection"

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

      Button {
        Task { await loadPairingCodePopup() }
      } label: {
        Label(pairingCodeBusy ? "Loading pairing..." : "View Pairing Code", systemImage: "qrcode")
      }
      .disabled(pairingCodeBusy)

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
              .font(.system(size: 13, weight: .bold))
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
          .font(.system(size: 13, weight: .semibold))
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
          actionError = friendlyActionError(error)
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
            actionError = friendlyActionError(error)
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
            actionError = friendlyActionError(error)
          }
        }
      }
      Button("Cancel", role: .cancel) {}
    }
    .alert("Pairing code", isPresented: $showPairingCodePopup) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(pairingCodeText)
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
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            ForEach(events.prefix(100), id: \.id) { e in
              HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Self.formatEventTime(e.ts))
                  .font(.system(size: 16))
                  .monospacedDigit()
                  .frame(width: 120, alignment: .leading)
                Text(Self.formatTrigger(e.trigger))
                  .font(.system(size: 16))
                  .italic()
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

  @MainActor
  private func loadPairingCodePopup() async {
    pairingCodeBusy = true
    defer { pairingCodeBusy = false }
    do {
      let out = try await model.createPairingCode(deviceId: device.id)
      let expires = Date(timeIntervalSince1970: TimeInterval(out.expiresAt) / 1000.0)
      pairingCodeText = "\(out.code)\nExpires at \(Self.formatEventTime(Int(expires.timeIntervalSince1970 * 1000)))."
      showPairingCodePopup = true
    } catch {
      actionError = friendlyActionError(error)
    }
  }

  private func friendlyActionError(_ error: Error) -> String {
    if let apiErr = error as? APIError {
      return apiErr.userMessage
    }
    return "That action couldn't be completed. Please try again."
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
      case "policy_fetch": return "Phone online"
      case "extra_time_requested": return "Extra time requested"
      case "extra_time_applied": return "Extra time applied"
      case "extra_time_denied": return "Extra time denied"
      default: return t.replacingOccurrences(of: "_", with: " ")
    }
  }
}

private struct PolicyEditorCard: View {
  @EnvironmentObject private var model: AppModel

  let device: DashboardDevice
  let extraTimeAnchorId: String
  let onExtraTimeApplied: () -> Void

  @State private var hotspotOff: Bool
  @State private var wifiOff: Bool
  @State private var mobileDataOff: Bool
  @State private var activateProtection: Bool

  @State private var quiet: Bool
  @State private var selectedDay: String = "mon"
  @State private var quietDays: [String: UpdatePolicyRequest.QuietDayWindow] = [:]

  @State private var startDate: Date
  @State private var endDate: Date
  @State private var dailyLimitMinutes: Int

  @State private var saveTask: Task<Void, Never>?
  @State private var saving: Bool = false
  @State private var saveWarning: String?
  @State private var copyAllSuccess: Bool = false
  @State private var extraTimeMinutes: Int = 15
  @State private var applyingExtraTime: Bool = false
  @State private var extraTimeStatus: String?
  @State private var didConsumePrefill: Bool = false
  @State private var activeExtraTimeEndsAt: Date?
  @State private var hasPendingExtraTimeRequest: Bool = false
  @State private var pendingRequestId: String?
  @State private var pendingRequestedMinutes: Int?
  @State private var denyingExtraTime: Bool = false
  @State private var forceShowExtraTime: Bool = false

  init(device: DashboardDevice, extraTimeAnchorId: String = "extraTimeSection", onExtraTimeApplied: @escaping () -> Void = {}) {
    self.device = device
    self.extraTimeAnchorId = extraTimeAnchorId
    self.onExtraTimeApplied = onExtraTimeApplied

    _hotspotOff = State(initialValue: device.actions.setHotspotOff)
    _wifiOff = State(initialValue: device.actions.setWifiOff)
    _mobileDataOff = State(initialValue: device.actions.setMobileDataOff)
    _activateProtection = State(initialValue: device.actions.activateProtection ?? true)
    _quiet = State(initialValue: device.quietDays != nil)

    let initialDay = device.quietDay ?? "mon"
    _selectedDay = State(initialValue: initialDay)

    // Initialize quietDays state from backend
    var qd: [String: UpdatePolicyRequest.QuietDayWindow] = [:]
    if let src = device.quietDays {
      for (k, v) in src {
        qd[k] = UpdatePolicyRequest.QuietDayWindow(start: v.start, end: v.end, dailyLimitMinutes: v.dailyLimitMinutes)
      }
    }
    _quietDays = State(initialValue: qd)

    // Pickers show the selected day values (or defaults)
    let start = qd[initialDay]?.start ?? "22:00"
    let end = qd[initialDay]?.end ?? "07:00"
    let dailyLimit = Self.clampDailyLimitMinutes(qd[initialDay]?.dailyLimitMinutes ?? 0)
    _startDate = State(initialValue: Self.parseTime(start) ?? Date())
    _endDate = State(initialValue: Self.parseTime(end) ?? Date())
    _dailyLimitMinutes = State(initialValue: dailyLimit)
    _activeExtraTimeEndsAt = State(initialValue: Self.dateFromMillis(device.activeExtraTime?.endsAt))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Status summary (matches web child settings treatment)
      HStack(alignment: .top, spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Status")
            .font(.headline)
          Text((device.statusMessage?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
               ? (device.statusMessage ?? "")
               : (device.enforce ? "Protection is currently on." : "Protection is currently off."))
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 8) {
          Text(device.enforce ? "Protection On" : "Protection Off")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(device.enforce ? .green : .orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((device.enforce ? Color.green : Color.orange).opacity(0.16))
            .clipShape(Capsule())

          if let usage = dailyLimitUsage {
            ZStack {
              Circle()
                .stroke(Color.primary.opacity(0.14), lineWidth: 8)
                .frame(width: 104, height: 104)

              Circle()
                .trim(from: 0, to: usage.progress)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 104, height: 104)

              VStack(spacing: 2) {
                Text("Screen Time Used")
                  .font(.system(size: 9))
                  .foregroundStyle(.secondary)
                Text("\(usage.used)m")
                  .font(.system(size: 22, weight: .semibold))
                Text("of \(formatMinutesHM(usage.limit))")
                  .font(.system(size: 10))
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }
      .padding(18)
      .background(Color.primary.opacity(0.06))
      .clipShape(RoundedRectangle(cornerRadius: 22))

      if let saveWarning, !saveWarning.isEmpty {
        Text(saveWarning)
          .font(.system(size: 14))
          .foregroundStyle(.orange)
      }

      // Rules box (second)
      VStack(alignment: .leading, spacing: 10) {
        Text("Rules")
          .font(.headline)

        Toggle(isOn: $activateProtection) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Lock Apps")
              .font(.system(size: 16, weight: .semibold))
            Text("Block certain apps. Set list on child phone.")
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
          }
        }
        .onChange(of: activateProtection) { _ in scheduleSave() }

        Toggle(isOn: $hotspotOff) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Turn Hotspot off")
              .font(.system(size: 16, weight: .semibold))
          }
        }
        .onChange(of: hotspotOff) { _ in scheduleSave() }

        Toggle(isOn: $wifiOff) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Turn Wi-Fi Off")
              .font(.system(size: 16, weight: .semibold))
          }
        }
        .onChange(of: wifiOff) { _ in scheduleSave() }

        Toggle(isOn: $mobileDataOff) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Turn Mobile Data Off")
              .font(.system(size: 16, weight: .semibold))
          }
        }
        .onChange(of: mobileDataOff) { _ in scheduleSave() }
      }
      .padding(18)
      .background(Color.primary.opacity(0.06))
      .clipShape(RoundedRectangle(cornerRadius: 22))

      // Schedule box (first)
      VStack(alignment: .leading, spacing: 10) {
        Toggle(isOn: $quiet) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Phone Time")
              .font(.system(size: 16, weight: .semibold))
            Text("Set when phone use is allowed. Outside this window, protection turns on.")
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
          }
        }
        .onChange(of: quiet) { isOn in
          if !isOn {
            quietDays = [:]
            if extraTimeStatus?.hasPrefix("Pending request:") == true {
              extraTimeStatus = nil
            }
          } else if quietDays.isEmpty {
            // seed all days with current picker values
            let s = Self.formatTime(startDate)
            let e = Self.formatTime(endDate)
            let limit = Self.clampDailyLimitMinutes(dailyLimitMinutes)
            quietDays = [
              "mon": .init(start: s, end: e, dailyLimitMinutes: limit),
              "tue": .init(start: s, end: e, dailyLimitMinutes: limit),
              "wed": .init(start: s, end: e, dailyLimitMinutes: limit),
              "thu": .init(start: s, end: e, dailyLimitMinutes: limit),
              "fri": .init(start: s, end: e, dailyLimitMinutes: limit),
              "sat": .init(start: s, end: e, dailyLimitMinutes: limit),
              "sun": .init(start: s, end: e, dailyLimitMinutes: limit),
            ]
          }
          scheduleSave()
          if isOn {
            Task { await loadPendingExtraTimeRequest() }
          }
        }

        if !quiet && wifiOff && mobileDataOff {
          Text("Warning: Wi-Fi Off + Mobile Data Off with no Phone Time window may prevent child phone from fetching policy updates.")
            .font(.system(size: 14))
            .foregroundStyle(.orange)
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
                  dailyLimitMinutes = Self.clampDailyLimitMinutes(quietDays[d]?.dailyLimitMinutes ?? 0)
                } label: {
                  Text(Self.dayLabel(d))
                    .font(.system(size: 13, weight: .semibold))
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
                  .font(.system(size: 13))
                  .foregroundStyle(.secondary)

                DatePicker("", selection: $startDate, displayedComponents: .hourAndMinute)
                  .labelsHidden()
                  .datePickerStyle(.wheel)
                  .environment(\.locale, Locale(identifier: "en_GB"))
                  .frame(width: colW, height: 118)
                  .clipped()
                  .contentShape(Rectangle())
                  .onChange(of: startDate) { _ in
                    let currentLimit = Self.clampDailyLimitMinutes(quietDays[selectedDay]?.dailyLimitMinutes ?? dailyLimitMinutes)
                    quietDays[selectedDay] = .init(start: Self.formatTime(startDate), end: Self.formatTime(endDate), dailyLimitMinutes: currentLimit)
                    scheduleSave()
                  }
              }
              .frame(width: colW)

              VStack(alignment: .leading, spacing: 6) {
                Text("End")
                  .font(.system(size: 13))
                  .foregroundStyle(.secondary)

                DatePicker("", selection: $endDate, displayedComponents: .hourAndMinute)
                  .labelsHidden()
                  .datePickerStyle(.wheel)
                  .environment(\.locale, Locale(identifier: "en_GB"))
                  .frame(width: colW, height: 118)
                  .clipped()
                  .contentShape(Rectangle())
                  .onChange(of: endDate) { _ in
                    let currentLimit = Self.clampDailyLimitMinutes(quietDays[selectedDay]?.dailyLimitMinutes ?? dailyLimitMinutes)
                    quietDays[selectedDay] = .init(start: Self.formatTime(startDate), end: Self.formatTime(endDate), dailyLimitMinutes: currentLimit)
                    scheduleSave()
                  }
              }
              .frame(width: colW)
            }
          }
          .frame(height: 138)
          .padding(10)
          .background(Color.white.opacity(0.04))
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(Color.white.opacity(0.08), lineWidth: 1)
          )
          HStack(spacing: 10) {
            Text("Total daily limit")
              .font(.system(size: 16, weight: .semibold))
            Spacer()
            Picker("Total daily limit", selection: $dailyLimitMinutes) {
              Text("Off").tag(0)
              ForEach(Array(stride(from: 15, through: 8 * 60, by: 15)), id: \.self) { m in
                Text(Self.formatDurationHM(m)).tag(m)
              }
            }
            .pickerStyle(.menu)
            .onChange(of: dailyLimitMinutes) { v in
              let rounded = Self.clampDailyLimitMinutes(v)
              quietDays[selectedDay] = .init(
                start: Self.formatTime(startDate),
                end: Self.formatTime(endDate),
                dailyLimitMinutes: rounded
              )
              scheduleSave()
            }
          }
          HStack {
            Spacer()
            Button {
              let s = Self.formatTime(startDate)
              let e = Self.formatTime(endDate)
              let limit = Self.clampDailyLimitMinutes(dailyLimitMinutes)
              quietDays = [
                "mon": .init(start: s, end: e, dailyLimitMinutes: limit),
                "tue": .init(start: s, end: e, dailyLimitMinutes: limit),
                "wed": .init(start: s, end: e, dailyLimitMinutes: limit),
                "thu": .init(start: s, end: e, dailyLimitMinutes: limit),
                "fri": .init(start: s, end: e, dailyLimitMinutes: limit),
                "sat": .init(start: s, end: e, dailyLimitMinutes: limit),
                "sun": .init(start: s, end: e, dailyLimitMinutes: limit),
              ]
              scheduleSave()
              copyAllSuccess = true
              DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                copyAllSuccess = false
              }
            } label: {
              HStack(spacing: 8) {
                Image(systemName: copyAllSuccess ? "checkmark.circle.fill" : "doc.on.doc")
                Text(copyAllSuccess ? "Copied" : "Copy to all days")
              }
              .font(.system(size: 16, weight: .semibold))
              .padding(.horizontal, 2)
            }
            .buttonStyle(.borderedProminent)
            .tint(copyAllSuccess ? .green : .blue)
          }

        }
      }
      .padding(18)
      .background(Color.primary.opacity(0.06))
      .clipShape(RoundedRectangle(cornerRadius: 22))

      if quiet || hasPendingExtraTimeRequest || forceShowExtraTime {
        VStack(alignment: .leading, spacing: 10) {
          Text("Extra Time")
            .font(.headline)

          Text(hasPendingExtraTimeRequest
            ? "You have a pending request."
            : "Temporarily disable enforcement for this child.")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)

          HStack(spacing: 10) {
            Text("Amount")
              .font(.system(size: 16, weight: .semibold))
            Spacer()
            Picker("Minutes", selection: $extraTimeMinutes) {
              ForEach(Array(stride(from: 0, through: 120, by: 5)), id: \.self) { m in
                Text("\(m) min").tag(m)
              }
            }
            .pickerStyle(.menu)
          }

          if hasPendingExtraTimeRequest {
            HStack(spacing: 10) {
              Button {
                Task { await applyExtraTime() }
              } label: {
                HStack(spacing: 8) {
                  if applyingExtraTime { ProgressView() }
                  Text(applyingExtraTime ? "Approving..." : "Approve")
                }
                .frame(maxWidth: .infinity)
              }
              .buttonStyle(.borderedProminent)
              .disabled(applyingExtraTime || denyingExtraTime)

              Button(role: .destructive) {
                Task { await denyExtraTime() }
              } label: {
                HStack(spacing: 8) {
                  if denyingExtraTime { ProgressView() }
                  Text(denyingExtraTime ? "Denying..." : "Deny")
                }
                .frame(maxWidth: .infinity)
              }
              .buttonStyle(.bordered)
              .disabled(applyingExtraTime || denyingExtraTime)
            }
          } else {
            Button {
              Task { await applyExtraTime() }
            } label: {
              HStack(spacing: 8) {
                if applyingExtraTime { ProgressView() }
                Text(applyingExtraTime ? "Applying..." : "Apply extra time")
              }
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(applyingExtraTime)
          }

          if let text = extraTimeStatusText {
            Text(text)
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
              .italic()
          }
        }
        .padding(18)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .id(extraTimeAnchorId)
      }

    }
    .onAppear {
      consumePrefillIfNeeded()
      if let d = Self.dateFromMillis(device.activeExtraTime?.endsAt), d > Date() {
        activeExtraTimeEndsAt = d
      } else {
        activeExtraTimeEndsAt = nil
      }
      Task { await loadPendingExtraTimeRequest() }
    }
  }

  private var dailyLimitUsage: (used: Int, limit: Int, progress: CGFloat)? {
    guard let daily = device.dailyLimit else { return nil }
    let limit = daily.limitMinutes ?? 0
    let used = max(0, daily.usedMinutes ?? 0)
    guard limit > 0 else { return nil }
    let clampedUsed = min(limit, used)
    let progress = CGFloat(Double(clampedUsed) / Double(limit))
    return (used: clampedUsed, limit: limit, progress: progress)
  }

  private func formatMinutesHM(_ minutes: Int) -> String {
    let m = max(0, minutes)
    let h = m / 60
    let r = m % 60
    if h == 0 { return "\(r)m" }
    if r == 0 { return "\(h)h" }
    return "\(h)h \(r)m"
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

  private func consumePrefillIfNeeded() {
    guard !didConsumePrefill else { return }
    didConsumePrefill = true
    if let prefilled = model.consumeExtraTimePrefill(deviceId: device.id) {
      extraTimeMinutes = max(0, min(120, (prefilled / 5) * 5))
      forceShowExtraTime = true
    }
  }

  @MainActor
  private func loadPendingExtraTimeRequest() async {
    do {
      if let req = try await model.fetchLatestPendingExtraTimeRequest(deviceId: device.id) {
        model.stashExtraTimePendingRequest(deviceId: device.id, requestId: req.id, minutes: req.requestedMinutes)
        extraTimeMinutes = max(0, min(120, (req.requestedMinutes / 5) * 5))
        extraTimeStatus = "Pending request: \(req.requestedMinutes) min."
        hasPendingExtraTimeRequest = true
        pendingRequestId = req.id
        pendingRequestedMinutes = req.requestedMinutes
      } else if extraTimeStatus?.hasPrefix("Pending request:") == true {
        extraTimeStatus = nil
        hasPendingExtraTimeRequest = false
        pendingRequestId = nil
        pendingRequestedMinutes = nil
      } else {
        hasPendingExtraTimeRequest = false
        pendingRequestId = nil
        pendingRequestedMinutes = nil
      }
    } catch {
    }
  }

  @MainActor
  private func applyExtraTime() async {
    applyingExtraTime = true
    defer { applyingExtraTime = false }
    do {
      let endsAt = try await model.parentApplyExtraTime(deviceId: device.id, minutes: extraTimeMinutes)
      activeExtraTimeEndsAt = endsAt
      hasPendingExtraTimeRequest = false
      pendingRequestId = nil
      pendingRequestedMinutes = nil
      extraTimeStatus = extraTimeMinutes == 0 ? "Extra time cleared." : "Extra time applied."
      onExtraTimeApplied()
    } catch {
      extraTimeStatus = "Failed to apply extra time."
    }
  }

  @MainActor
  private func denyExtraTime() async {
    denyingExtraTime = true
    defer { denyingExtraTime = false }
    do {
      try await model.parentDenyExtraTime(deviceId: device.id)
      hasPendingExtraTimeRequest = false
      pendingRequestId = nil
      pendingRequestedMinutes = nil
      extraTimeStatus = "Request denied."
      onExtraTimeApplied()
    } catch {
      extraTimeStatus = "Failed to deny request."
    }
  }

  @MainActor
  private func saveNow() async {
    saving = true
    defer { saving = false }

    do {
      let tz = TimeZone.current.identifier
      try await model.updateSelectedDevicePolicy(
        activateProtection: activateProtection,
        setHotspotOff: hotspotOff,
        setWifiOff: wifiOff,
        setMobileDataOff: mobileDataOff,
        quietDays: quiet ? quietDays : nil,
        tz: tz
      )
      saveWarning = nil
    } catch {
      saveWarning = Self.isLikelyOffline(error)
        ? "No internet connection. Couldn't save settings."
        : "Could not save settings. Please try again."
    }
  }

  private static func isLikelyOffline(_ error: Error) -> Bool {
    if let urlError = error as? URLError {
      switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .timedOut:
          return true
        default:
          break
      }
    }
    if let apiError = error as? APIError {
      if case .invalidResponse = apiError { return true }
    }
    return false
  }

  private static func formatTime(_ d: Date) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = .current
    df.dateFormat = "HH:mm"
    return df.string(from: d)
  }

  private var extraTimeStatusText: String? {
    if let extraTimeStatus, !extraTimeStatus.isEmpty {
      if extraTimeStatus == "Failed to apply extra time." {
        return extraTimeStatus
      }
    }
    if let end = activeExtraTimeEndsAt, end > Date() {
      return "Extra time active until \(Self.formatClock(end))."
    }
    return extraTimeStatus
  }

  private static func formatClock(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = .current
    f.timeZone = .current
    f.dateStyle = .none
    f.timeStyle = .short
    return f.string(from: d)
  }

  private static func formatDurationHM(_ minutes: Int) -> String {
    let clamped = max(0, minutes)
    let h = clamped / 60
    let m = clamped % 60
    if h == 0 { return "\(m)m" }
    if m == 0 { return "\(h)h" }
    return "\(h)h \(m)m"
  }

  private static func clampDailyLimitMinutes(_ minutes: Int) -> Int {
    let clamped = max(0, min(8 * 60, minutes))
    return clamped - (clamped % 15)
  }

  private static func dateFromMillis(_ ms: Int?) -> Date? {
    guard let ms, ms > 0 else { return nil }
    return Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
  }
}

#Preview {
  ParentDashboardView()
    .environmentObject(AppModel())
}
#endif

import Foundation

#if canImport(SwiftUI)
import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(UIKit)
import UIKit
#endif

public struct ChildDashboardView: View {
  @EnvironmentObject private var model: AppModel
  @State private var showAutomationsInfo = false
  @State private var showFinishConfirm = false
  #if canImport(FamilyControls)
  @State private var requiredSelection = FamilyActivitySelection()
  @State private var showingRequiredPicker = false
  @State private var quietSelection = FamilyActivitySelection()
  @State private var showingQuietPicker = false
  #endif

  private static let shortcutsIconBase64 = "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAECklEQVR4nO2ZR2gWQRiGHxMTe8EGYsMgCEZFBRU8aCRgbmINYkOwYcEYL3pSTyqCggdBPYgYE0+2g3jwrmJBjCXRmIsl2EESu2Y9zLfMRv9/Zmd213jIC3P55/3a7uz3zj8DXehCp6EYqATqgEagDQgyHm0Sq1ZiFyctYhHQ/A8St42nwEKfAgqAgxFH94BtwASgj49DR/QBSoEqoD6SxwHJLTbCIr4CG12NU0YBsElyCYuJhUXoIuZkkpofytDFLLCRi9HfxMYss/LEZlRuTUCRiViJ/iaSLKeewA7gFvBZxi2gWuZ8UQjclxyXmIh1QtqWINgkoIH8HahBOL7YLn7OmEiPhTTBM8gKtM40oJ7aEBlLgUcy9wlY6RmjVHw0mkitQurr6Lw7qpuET/000DsHrydwIsI7DvRwjNVPbFtNpDCAC0YC19CdriqGzWrUWwmAO8BYx5jWPF0LKQNeic0zYKaD7VR0h3wHVDjYplZIN2An8FP4l4FBDomEGACcFx/txFfuVArp7xk8H3weSuJCStDL4S1uy8GGCvEZSIwSAzdxIZdk/iYw2inNeBgtvgPgooGXuJB3Mm979b3wV/bB6Dfum6eVcFfmdxk4k0mm7LvQbdk3TyuhEvWBB8Ax/t64RfUhl7KHBbahdgFRFInPsIkszrIQJKHPwrsKDJTfhwMv5fdTqOX1J3oBJyNxjqJ23APFVyC+l1pySE1HpgMt6Cc/Tn4fCayKYb8O+CL2N9BvqkV825Cqso+iozLPjmkXYhrwIhKzWXzGQWbKHgDfgDUxEwFYhn4rnaLsg1DqGwC/gN3AoYjtfksyBcIJ+YeBPeKr05R9XmRuPfBd5s6R+7Slt8wFwt0QmatA61Qz5h1x5speDnwQzhNU9xkmo1J+C4RTnsN+DFrZLyTIMxVlHw88jPj6czwUTj6Eyv4mQZ6pKDsovdiOaq1tMq6j/nTZtiihst9OkKezsne3JOWCf67si9HbkKiyJ0E/dCf8Aiy38FPTkSnAc+E2YV7zNpSgT1dagBkxbFJV9hGodRwA71H/310xC3gtPupRXSsOUi0E1LHRRZIr+xXUX+i4SL0QUNuVvRHbI5iVPRe/0DGmNU/fAzqAtXRU9nwHdGeF8wPY4hGnv9h/NJGSHpnmUvahaGVvwqzscTBRfBiPTGuFVOUZBJIruw3V4qfGRAqvFepJdlaVRNlNKAQeSI7Ga4Vi1MVjgLru+t+wFb1sjRc9oG5PA9SBdFmmablhLqrFtwPz4xqFVwRfUdddru0xTRSi3sQ3yWmfi3EBHe877qPWfCl+rdkVfVHdqRr9TbSjivD6dhegW2Znjic4LKd8KEJ1iDOoY5tQNLMcraiNZI3Etn7YXehCRvgNZNsvTgtbGykAAAAASUVORK5CYII="

  private struct AutomationRow: View {
    let triggerIcon: String
    let triggerIconColor: Color
    let triggerIconBackground: Color
    let title: String

    var body: some View {
      HStack(spacing: 10) {
        HStack(spacing: 7) {
          ZStack {
            RoundedRectangle(cornerRadius: 7)
              .fill(triggerIconBackground)
            Image(systemName: triggerIcon)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(triggerIconColor)
          }
          .frame(width: 24, height: 24)

          Image(systemName: "arrow.right")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary.opacity(0.7))

          ZStack {
            RoundedRectangle(cornerRadius: 7)
              .fill(Color(red: 0.29, green: 0.41, blue: 1.00))
            Image(systemName: "network")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.white)
          }
          .frame(width: 24, height: 24)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.system(size: 16, weight: .semibold))
            .lineLimit(1)
            .truncationMode(.tail)

          Text("Enforce Hotspot Policy")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 0)
      }
      .padding(.vertical, 10)
      .padding(.horizontal, 12)
    }
  }

  public init() {}

  private var pairingComplete: Bool {
    model.loadHotspotConfig() != nil
  }

  private var shortcutComplete: Bool {
    model.appIntentRunCount > 0
  }

  private var automationsComplete: Bool {
    model.appIntentRunCount >= 2
  }

  private var screenTimeComplete: Bool {
    model.screenTimeAuthorized
      && model.screenTimeHasRequiredSelection
      && model.screenTimePasswordStepCompleted
  }

  private var canFinishSetup: Bool {
    pairingComplete && shortcutComplete && automationsComplete && screenTimeComplete
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Setup checklist")
          .font(.system(size: 34, weight: .bold))
          .padding(.top, 2)

        Text("Complete these steps so rules can be enforced.")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
          pairingTile
          shortcutTile
          automationsTile
          screenTimeTile
          lockShortcutsTile
          lockAppsTile
        }
        .padding(.top, 6)

        Button {
          showFinishConfirm = true
        } label: {
          Text("Finish setup")
            .frame(maxWidth: .infinity)
        }
        .primaryActionButton()
        .disabled(!canFinishSetup)
      }
      .padding(.top, 18)
      .padding(.horizontal, 18)
      .padding(.bottom, 32)
    }
    // Re-read intent telemetry (AppIntents update SharedDefaults out-of-process)
    // so the dashboard highlights update without restarting the app.
    // This runs whenever the view appears.
    .onAppear { model.syncFromSharedDefaults() }
    #if canImport(FamilyControls)
    .onAppear {
      if let savedRequired = ScreenTimeManager.shared.loadRequiredSelection() {
        requiredSelection = savedRequired
      }
      if let saved = ScreenTimeManager.shared.loadQuietSelection() {
        quietSelection = saved
      }
    }
    .sheet(isPresented: $showingRequiredPicker) {
      NavigationStack {
        FamilyActivityPicker(selection: $requiredSelection)
          .navigationTitle("Always Locked Apps")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") {
                showingRequiredPicker = false
                ScreenTimeManager.shared.saveRequiredSelection(requiredSelection)
                Task {
                  await model.reconcileScreenTimeProtection()
                }
              }
            }
          }
      }
    }
    .sheet(isPresented: $showingQuietPicker) {
      NavigationStack {
        FamilyActivityPicker(selection: $quietSelection)
          .navigationTitle("Enforcement Schedule Apps")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") {
                showingQuietPicker = false
                ScreenTimeManager.shared.saveQuietSelection(quietSelection)
                Task {
                  await model.reconcileScreenTimeProtection()
                }
              }
            }
          }
      }
    }
    #endif
    .sheet(isPresented: $showAutomationsInfo) {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            Text("Personal")
              .font(.system(size: 34, weight: .bold))
              .padding(.top, 2)

            Text("Set these automations up in Shortcuts exactly like this. Add multiple times per day, and add multiple battery levels. More triggers means policy checks run more often.")
              .font(.system(size: 15))
              .foregroundStyle(.secondary)

            VStack(spacing: 0) {
              AutomationRow(
                triggerIcon: "clock.fill",
                triggerIconColor: .orange,
                triggerIconBackground: Color.orange.opacity(0.18),
                title: "At 16:00, daily"
              )
              SettingsDivider()
              AutomationRow(
                triggerIcon: "clock.fill",
                triggerIconColor: .orange,
                triggerIconBackground: Color.orange.opacity(0.18),
                title: "At 21:00, daily"
              )
              SettingsDivider()
              AutomationRow(
                triggerIcon: "wifi",
                triggerIconColor: .blue,
                triggerIconBackground: Color.blue.opacity(0.18),
                title: "When joining your Wi‑Fi"
              )
              SettingsDivider()
              AutomationRow(
                triggerIcon: "arrow.up.right.square.fill",
                triggerIconColor: .white.opacity(0.9),
                triggerIconBackground: Color.white.opacity(0.12),
                title: "When \"Settings\" is opened"
              )
              SettingsDivider()
              AutomationRow(
                triggerIcon: "battery.50",
                triggerIconColor: .white.opacity(0.9),
                triggerIconBackground: Color.white.opacity(0.12),
                title: "When battery level is 50%"
              )
              SettingsDivider()
              AutomationRow(
                triggerIcon: "battery.25",
                triggerIconColor: .white.opacity(0.9),
                triggerIconBackground: Color.white.opacity(0.12),
                title: "When battery level is 20%"
              )
            }
            .background(Color.white.opacity(0.06))
            .overlay(
              RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
          }
          .padding(18)
        }
        .navigationTitle("Automations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button("Done") {
              showAutomationsInfo = false
            }
          }
        }
      }
    }
    .confirmationDialog(
      "Logout and lock this phone?",
      isPresented: $showFinishConfirm,
      titleVisibility: .visible
    ) {
      Button("Logout and lock", role: .destructive) {
        // Lock the child setup screen and remove parent session from this device.
        model.signOut()
        model.lockChildSetup()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will sign the parent out on this phone and show the locked screen.")
    }
  }

  private var pairingTile: some View {
    let paired = pairingComplete
    return NavigationLink {
      PairingEntryView()
        .environmentObject(model)
    } label: {
      ShortcutTileCard(
        color: paired ? .pink : .gray,
        systemIcon: "qrcode",
        title: paired ? "Edit pairing" : "Start pairing",
        subtitle: paired ? "Paired" : "Not paired yet"
      )
    }
    .buttonStyle(.plain)
  }

  private var shortcutTile: some View {
    let shortcutURL = "https://www.icloud.com/shortcuts/397015e4b5f24d488f12d0658454c6a0"
    let hasRun = shortcutComplete
    return ShortcutTile(
      color: hasRun ? .pink : .gray,
      systemIcon: "link",
      customIcon: shortcutsIcon,
      title: "Install our Shortcut",
      subtitle: hasRun ? "Done" : "Open link, add Shortcut, run once"
    ) {
      openURL(shortcutURL)
    }
  }

  private var automationsTile: some View {
    let ok = automationsComplete
    return ShortcutTile(
      color: ok ? .pink : .gray,
      systemIcon: "wrench.and.screwdriver",
      title: "Automations",
      subtitle: ok ? "Done" : "Tap to view instructions"
    ) {
      showAutomationsInfo = true
    }
  }

  private var screenTimeTile: some View {
    let ok = screenTimeComplete
    let subtitle: String = {
      if !ok { return "Needs setup" }
      if model.shieldingApplied { return "Managed by parent" }
      return "Configured (parent can enable)"
    }()
    return NavigationLink {
      ScreenTimeSetupView()
        .environmentObject(model)
    } label: {
      ShortcutTileCard(
        color: ok ? .pink : .gray,
        systemIcon: "shield",
        title: "Screen Time lock",
        subtitle: subtitle
      )
    }
    .buttonStyle(.plain)
  }

  private var lockAppsTile: some View {
    let quietCount = ScreenTimeManager.shared.selectionSummary().quietSelectionsSelected
    let ok = quietCount > 0
    let enabled = model.screenTimeAuthorized
    return Button {
      #if canImport(FamilyControls)
      if let saved = ScreenTimeManager.shared.loadQuietSelection() {
        quietSelection = saved
      } else {
        quietSelection = FamilyActivitySelection()
      }
      showingQuietPicker = true
      #endif
    } label: {
      ShortcutTileCard(
        color: ok ? .pink : .gray,
        systemIcon: "moon.stars",
        title: "Lock apps",
        subtitle: ok ? "Done" : "Choose apps for Enforcement Schedule"
      )
      .opacity(enabled ? 1.0 : 0.7)
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
  }

  private var lockShortcutsTile: some View {
    let hasRequired = ScreenTimeManager.shared.selectionSummary().hasRequiredSelection
    let enabled = model.screenTimeAuthorized
    return Button {
      #if canImport(FamilyControls)
      if let saved = ScreenTimeManager.shared.loadRequiredSelection() {
        requiredSelection = saved
      } else {
        requiredSelection = FamilyActivitySelection()
      }
      showingRequiredPicker = true
      #endif
    } label: {
      ShortcutTileCard(
        color: hasRequired ? .pink : .gray,
        systemIcon: hasRequired ? "checkmark.shield" : "link",
        customIcon: hasRequired ? shortcutsIcon : nil,
        title: "Lock Shortcuts",
        subtitle: hasRequired ? "Done" : "Pick Shortcuts in Always Locked Apps"
      )
      .opacity(enabled ? 1.0 : 0.7)
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
  }

  private func openURL(_ s: String) {
    guard let url = URL(string: s) else { return }
    #if canImport(UIKit)
    UIApplication.shared.open(url)
    #endif
  }

  private var shortcutsIcon: Image? {
    #if canImport(UIKit)
    guard let data = Data(base64Encoded: Self.shortcutsIconBase64),
          let uiImage = UIImage(data: data) else { return nil }
    return Image(uiImage: uiImage)
    #else
    return nil
    #endif
  }
}

#Preview {
  ChildDashboardView()
    .environmentObject(AppModel())
}
#endif

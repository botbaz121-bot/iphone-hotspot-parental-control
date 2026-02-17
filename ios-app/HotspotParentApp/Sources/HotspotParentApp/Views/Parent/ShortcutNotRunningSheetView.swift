import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ShortcutNotRunningSheetView: View {
  public init() {}

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          Text("If the Shortcut isn’t running")
            .font(.title2.bold())

          Group {
            Text("1) Open the Shortcuts app")
              .font(.headline)
            Text("Find the SpotCheck automation and make sure it exists.")
              .font(.footnote)
              .foregroundStyle(.secondary)

            Text("2) Disable \"Ask Before Running\"")
              .font(.headline)
            Text("Automations won’t run silently if Ask Before Running is enabled.")
              .font(.footnote)
              .foregroundStyle(.secondary)

            Text("3) Check notifications / Focus")
              .font(.headline)
            Text("Some Focus/notification settings can prevent prompts or make it look like nothing happened.")
              .font(.footnote)
              .foregroundStyle(.secondary)

            Text("4) Reboot and re‑create the automation")
              .font(.headline)
            Text("If it still doesn’t trigger, restart the phone and re-create the automation from scratch.")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }

          Divider().opacity(0.4)

          Text("What SpotCheck can verify")
            .font(.headline)
          Text("The app can tell whether the SpotCheck Shortcut (App Intent) has been executed recently, but it can’t directly inspect your Shortcuts automations.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding()
      }
      .navigationTitle("Troubleshooting")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

#Preview {
  ShortcutNotRunningSheetView()
}
#endif

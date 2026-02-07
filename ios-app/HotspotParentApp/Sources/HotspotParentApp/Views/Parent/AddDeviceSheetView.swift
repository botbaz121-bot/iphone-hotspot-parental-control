import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct AddDeviceSheetView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss

  public init() {}

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("Add a child device")
            .font(.title.bold())

          VStack(alignment: .leading, spacing: 8) {
            Text("Steps")
              .font(.headline)
            Text("1) On a computer, open the backend admin UI (/admin) and generate a pairing code for a device.")
            Text("2) On the child phone, open this app → Child mode → Settings → enter pairing code.")
            Text("3) Install the Shortcut and confirm it has run at least once.")
          }
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
          .background(.thinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 16))

          Button {
            model.setAppMode(.childSetup)
            dismiss()
          } label: {
            Label("Set up child phone now", systemImage: "iphone")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
        }
        .padding()
      }
      .navigationTitle("Add device")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}

#Preview {
  AddDeviceSheetView()
    .environmentObject(AppModel())
}
#endif

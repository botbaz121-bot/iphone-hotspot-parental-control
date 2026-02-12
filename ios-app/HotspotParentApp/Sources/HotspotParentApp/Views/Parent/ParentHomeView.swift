import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct ParentHomeView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Home")
              .font(.title.bold())
            Text("Your devices at a glance")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }

          if model.parentDevices.isEmpty {
            VStack(spacing: 12) {
              Image(systemName: "qrcode")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
              Text("No devices enrolled")
                .font(.title2.weight(.semibold))
              Text("Tap Enroll on Dashboard to add your first child phone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
          } else {
            VStack(spacing: 12) {
              ForEach(model.parentDevices) { d in
                HStack {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(d.name)
                      .font(.headline.weight(.semibold))
                      .lineLimit(1)
                    Text(d.gap ? "Stale check-in" : "Recent activity")
                      .font(.caption)
                      .foregroundStyle(d.gap ? .orange : .green)
                    if let last = d.last_event_at {
                      Text(last.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    } else {
                      Text("No activity yet")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                  }
                  Spacer()
                  Text(d.gap ? "STALE" : "OK")
                    .font(.caption.weight(.semibold))
                    .font(.system(.caption, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(d.gap ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                    .foregroundStyle(d.gap ? .orange : .green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
              }
            }
          }
        }
        .padding()
      }
      .navigationTitle("Home")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          AppModeSwitcherView()
        }
      }
    }
  }
}

#Preview {
  ParentHomeView()
    .environmentObject(AppModel())
}
#endif

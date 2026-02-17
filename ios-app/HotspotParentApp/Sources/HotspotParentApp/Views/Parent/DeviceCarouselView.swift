import Foundation

#if canImport(SwiftUI)
import SwiftUI

/// Prototype-style horizontal device carousel with an "Enroll" tile as the last card.
public struct DeviceCarouselView: View {
  @EnvironmentObject private var model: AppModel

  public init() {}

  public var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(model.parentDevices, id: \.id) { d in
          Button {
            model.selectedDeviceId = d.id
          } label: {
            VStack(alignment: .leading, spacing: 10) {
              HStack(alignment: .top) {
                Circle()
                  .fill(Color.primary.opacity(0.12))
                  .frame(width: 36, height: 36)
                  .overlay {
                    Text(String(d.name.prefix(1)).uppercased())
                      .font(.headline.weight(.semibold))
                  }

                VStack(alignment: .leading, spacing: 4) {
                  Text(d.name)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                  Text(lastSeenText(d))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                statusBadge(d)
              }

              HStack(spacing: 6) {
                badgeMuted(d.actions.setHotspotOff ? "Hotspot OFF" : "Hotspot ON")
                badgeMuted(quietBadgeText(d))
              }
            }
            .padding(12)
            .frame(width: 260, alignment: .leading)
            .background(model.selectedDeviceId == d.id ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18))
          }
          .buttonStyle(.plain)
        }

        // Enroll tile
        Button {
          model.presentEnrollSheet = true
        } label: {
          VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 14)
              .fill(Color.blue.opacity(0.14))
              .frame(width: 44, height: 44)
              .overlay {
                Image(systemName: "qrcode")
                  .foregroundStyle(.blue)
              }

            Text("Enroll device")
              .font(.headline.weight(.semibold))

            Text("Add another child phone")
              .font(.caption)
              .foregroundStyle(.secondary)

            Spacer(minLength: 0)
          }
          .padding(12)
          .frame(width: 220, height: 150, alignment: .leading)
          .background(Color.primary.opacity(0.06))
          .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
      }
      .padding(.vertical, 2)
    }
  }

  private func badgeMuted(_ s: String) -> some View {
    Text(s)
      .font(.caption2.weight(.medium))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Color.primary.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 999))
  }

  private func statusBadge(_ d: DashboardDevice) -> some View {
    let text: String
    let bg: Color
    let fg: Color

    if d.gap {
      text = "WARN"
      bg = .orange.opacity(0.18)
      fg = .orange
    } else {
      text = "OK"
      bg = .green.opacity(0.18)
      fg = .green
    }

    return Text(text)
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(bg)
      .foregroundStyle(fg)
      .clipShape(RoundedRectangle(cornerRadius: 999))
  }

  private func quietBadgeText(_ d: DashboardDevice) -> String {
    guard let q = d.quietHours else { return "Quiet OFF" }
    let s = (q.start ?? "12:00")
    let e = (q.end ?? "12:00")
    if s == e { return "Quiet OFF" }
    return "Quiet \(s)–\(e)"
  }

  private func lastSeenText(_ d: DashboardDevice) -> String {
    if d.gap { return "Check-in stale" }
    return d.last_event_at ?? "Recent activity"
  }
}

#Preview {
  DeviceCarouselView()
    .environmentObject(AppModel())
}
#endif

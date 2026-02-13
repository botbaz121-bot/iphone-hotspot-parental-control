import Foundation

#if canImport(SwiftUI)
import SwiftUI

// MARK: - Shortcuts-style gradient tiles

public enum ShortcutTileColor {
  case blue
  case gray
  case purple
  case pink
  case green

  public var gradient: LinearGradient {
    switch self {
      case .blue:
        return LinearGradient(
          colors: [Color(red: 0.20, green: 0.45, blue: 1.0), Color(red: 0.31, green: 0.55, blue: 1.0)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      case .gray:
        return LinearGradient(
          colors: [Color(red: 0.23, green: 0.23, blue: 0.27), Color(red: 0.12, green: 0.12, blue: 0.15)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      case .purple:
        return LinearGradient(
          colors: [Color(red: 0.54, green: 0.36, blue: 1.0), Color(red: 0.35, green: 0.49, blue: 1.0)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      case .pink:
        return LinearGradient(
          colors: [Color(red: 1.0, green: 0.29, blue: 0.72), Color(red: 0.61, green: 0.36, blue: 1.0)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      case .green:
        return LinearGradient(
          colors: [Color(red: 0.00, green: 0.76, blue: 0.66), Color(red: 0.18, green: 0.83, blue: 0.44)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
    }
  }
}

public struct ShortcutTileCard: View {
  public let color: ShortcutTileColor
  public let systemIcon: String
  public let title: String
  public let subtitle: String?

  public init(
    color: ShortcutTileColor,
    systemIcon: String,
    title: String,
    subtitle: String? = nil
  ) {
    self.color = color
    self.systemIcon = systemIcon
    self.title = title
    self.subtitle = subtitle
  }

  public var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 22)
        .fill(color.gradient)

      VStack(alignment: .leading, spacing: 10) {
        ZStack {
          RoundedRectangle(cornerRadius: 10)
            .fill(Color.black.opacity(0.22))
            .overlay(
              RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
          Image(systemName: systemIcon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.95))
        }
        .frame(width: 28, height: 28)

        Spacer(minLength: 0)

        Text(title)
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(.white.opacity(0.95))
          .multilineTextAlignment(.leading)
          .lineLimit(2)
          .truncationMode(.tail)
          .frame(maxWidth: .infinity, alignment: .leading)

        if let subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.70))
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(14)
    }
    // Allow the card to grow with text to avoid overlap in grids.
    .frame(minHeight: 118)
  }
}

public struct ShortcutTile: View {
  public let color: ShortcutTileColor
  public let systemIcon: String
  public let title: String
  public let subtitle: String?
  public let action: () -> Void

  public init(
    color: ShortcutTileColor,
    systemIcon: String,
    title: String,
    subtitle: String? = nil,
    action: @escaping () -> Void
  ) {
    self.color = color
    self.systemIcon = systemIcon
    self.title = title
    self.subtitle = subtitle
    self.action = action
  }

  public var body: some View {
    Button {
      action()
    } label: {
      ShortcutTileCard(color: color, systemIcon: systemIcon, title: title, subtitle: subtitle)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - iOS Settings-like grouped list

public struct SettingsGroup<Content: View>: View {
  public let title: String
  @ViewBuilder public let content: Content

  public init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
        .padding(.horizontal, 4)

      VStack(spacing: 0) {
        content
      }
      .background(Color.white.opacity(0.06))
      .overlay(
        RoundedRectangle(cornerRadius: 18)
          .stroke(Color.white.opacity(0.10), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 18))
    }
  }
}

public struct SettingsRow: View {
  public let systemIcon: String
  public let title: String
  public let subtitle: String?
  public let rightText: String?
  public let showsChevron: Bool
  public let action: (() -> Void)?

  public init(
    systemIcon: String,
    title: String,
    subtitle: String? = nil,
    rightText: String? = nil,
    showsChevron: Bool = true,
    action: (() -> Void)? = nil
  ) {
    self.systemIcon = systemIcon
    self.title = title
    self.subtitle = subtitle
    self.rightText = rightText
    self.showsChevron = showsChevron
    self.action = action
  }

  public var body: some View {
    Button {
      action?()
    } label: {
      HStack(spacing: 12) {
        ZStack {
          RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.08))
          Image(systemName: systemIcon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.90))
        }
        .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.body.weight(.semibold))
            .foregroundStyle(.primary)

          if let subtitle, !subtitle.isEmpty {
            Text(subtitle)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }

        Spacer(minLength: 8)

        if let rightText {
          Text(rightText)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        if showsChevron {
          Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary.opacity(0.8))
        }
      }
      .padding(.vertical, 10)
      .padding(.horizontal, 12)
    }
    .buttonStyle(.plain)
  }
}

public struct SettingsToggleRow: View {
  public let systemIcon: String
  public let title: String
  public let subtitle: String?
  @Binding public var isOn: Bool

  public init(systemIcon: String, title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
    self.systemIcon = systemIcon
    self.title = title
    self.subtitle = subtitle
    self._isOn = isOn
  }

  public var body: some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.white.opacity(0.08))
        Image(systemName: systemIcon)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.white.opacity(0.90))
      }
      .frame(width: 28, height: 28)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.body.weight(.semibold))
          .foregroundStyle(.primary)

        if let subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

      Spacer(minLength: 8)

      Toggle("", isOn: $isOn)
        .labelsHidden()
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 12)
  }
}

public struct SettingsDivider: View {
  public init() {}
  public var body: some View {
    Divider()
      .background(Color.white.opacity(0.08))
      .padding(.leading, 52)
  }
}

#endif

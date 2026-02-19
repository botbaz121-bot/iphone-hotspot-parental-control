# Changelog

## 0.1.1 (2) - 2026-02-19
- Added child extra-time request flow from locked screen with 5-minute interval picker.
- Added parent-side Extra Time approval/apply controls in child settings.
- Added backend extra-time request lifecycle, approval/deny endpoints, and policy enforcement integration.
- Added APNs registration/send plumbing for extra-time request notifications.
- Added fallback pending-request loading in parent app (works even when push is not delivered).
- Added immediate recent-activity refresh after extra-time apply in parent child settings.
- Added extra-time request/applied/denied event logging and labels in recent activity.
- Added support for `0 min` parent adjustment to clear/reduce active extra time.
- Fixed active extra-time precedence so latest parent decision overrides previous active grants.
- Made child lock status text use backend-provided `statusMessage` as source of truth (with fallback).
- Fixed schedule/on-off messaging and clarified next-boundary day text.
- Added one-time auto-update on child lock screen entry.
- Show `Need more time?` card only when protection is currently off.
- Added Open Shortcuts button in Automations instructions.
- Updated Automations action icon to Apple portal VPN icon asset.
- Made Screen Time setup password/deletion steps manual checklist actions with explicit instructions.
- Added app version/build footer in Parent Settings.
- Ignored Xcode local user state files in `.gitignore`.

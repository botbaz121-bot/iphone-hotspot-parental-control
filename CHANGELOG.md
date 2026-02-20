# Changelog

## 0.1.8 (9) - 2026-02-20
- Updated backend protection status messaging for extra time:
- Clarified active state text to "approved extra time".
- Added pending-request status messaging so pending requests do not read as active approved extra time.

## 0.1.7 (8) - 2026-02-19
- Removed parent child-settings pending-request debug text from the UI.
- Updated backend policy status wording to consistently use "Protection is currently on/off..." phrasing.
- Removed child fallback copy branch that showed "The parent has disabled protection." so backend status messaging is preferred.

## 0.1.6 (7) - 2026-02-19
- Removed the separate `Approval` card from parent child settings.
- Kept dual-button moderation flow inside `Extra Time` when a request is pending (`Approve` / `Deny`).

## 0.1.5 (6) - 2026-02-19
- Fixed API URL building for query endpoints so `?` is no longer escaped to `%3F` (this fixes `Cannot GET /api/extra-time/requests%3F...` and restores pending-request fetch/approval visibility).

## 0.1.4 (5) - 2026-02-19
- Expanded parent pending-request debug output to include exact pending-fetch failure details (HTTP status/body, URL error, or localized error text).

## 0.1.3 (4) - 2026-02-19
- Made parent child-settings pending-request debug line always visible (not gated by pending state).
- Expanded debug line with device id, pending flag, request id, and minutes to diagnose missing Approval box cases.

## 0.1.2 (3) - 2026-02-19
- Fixed parent pending extra-time request lookup to reliably match by device in-app.
- Added explicit `Approval` card in parent child settings with `Accept` / `Deny` actions.
- Added pending-request debug details in parent child settings to diagnose request visibility issues.
- Fixed extra-time reduction/clear precedence so latest parent decision overrides active windows.
- Added immediate recent-activity refresh after parent apply/deny from child settings.
- Corrected child enforcement state handling to follow backend effective `enforce` flag.
- Fixed backend/admin protection status logic to avoid schedule-state mismatches.
- Switched child lock screen to backend `statusMessage` as authoritative source (with fallback).
- Expanded protection status messaging to include configured protections (Apps/Hotspot/Wi-Fi/Mobile Data).
- Updated rules schedule save to use current device timezone identifier.

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

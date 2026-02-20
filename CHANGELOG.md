# Changelog

## 0.1.36 (37) - 2026-02-20
- Increased Screen Time protection checklist subtitle line limit from 5 to 6 lines.

## 0.1.35 (36) - 2026-02-20
- Child Settings mode toggle now routes logged-out users to the welcome screen (app mode `nil`) instead of parent sign-in when turning off `This is a child phone`.

## 0.1.34 (35) - 2026-02-20
- Updated extra-time push notification copy to use plural `mins`.

## 0.1.33 (34) - 2026-02-20
- Removed remaining debug/status text from the child Screen Time protection screen (degraded reason and transient permission status line).

## 0.1.32 (33) - 2026-02-20
- Child Automations sheet updated:
- Removed the `Personal` heading.
- Added a second settings-style box showing `Automation / Run Immediately` and `Notify When Run / Off`.

## 0.1.31 (32) - 2026-02-20
- Replaced remaining raw user-facing error strings with friendly messages across:
- Landing sign-in alert, Add Device pairing generation, Child unlock alert, and Parent child-details action alerts.

## 0.1.30 (31) - 2026-02-20
- Increased Screen Time protection checklist subtitle line limit from 4 to 5 lines.
- Removed debug detail text from Screen Time permission result messages.

## 0.1.29 (30) - 2026-02-20
- Moved `Open Shortcuts` button to below the automations instruction list in the child Automations sheet.

## 0.1.28 (29) - 2026-02-20
- Child lock screen title changed from `SpotChecker Complete` to `SpotChecker`.
- Child lock screen button label changed from `Update` to `Refresh Status` (busy: `Refreshing Status…`).

## 0.1.27 (28) - 2026-02-20
- Renamed parent child-details menu item from `View Pairing` to `View Pairing Code`.

## 0.1.26 (27) - 2026-02-20
- Child lock screen now shows `Need more time?` only when protection is currently on and protections are configured.
- Hides extra-time request card when protection is off or no protections are enabled.

## 0.1.25 (26) - 2026-02-20
- Fixed status messaging to follow effective backend enforcement state (`enforce`) so schedule-off + active protections reports “Protection is currently on.”

## 0.1.24 (25) - 2026-02-20
- Fixed backend protection status messaging so it never reports “Protection is currently on” when no protections are configured.

## 0.1.23 (24) - 2026-02-20
- `Prevent App Deletions` now remains visible in Screen Time setup for `This Device` mode even before `Grant Permissions` is completed.

## 0.1.22 (23) - 2026-02-20
- Replaced the old embedded Shortcuts icon with a new vector asset (`ShortcutsIcon`) using the provided SVG.
- Updated child setup/automation Shortcuts icon rendering to use the shared asset.

## 0.1.21 (22) - 2026-02-20
- Clarified `Prevent App Deletions` checklist subtitle with explicit Settings navigation path and final action (`Deleting Apps: Don't Allow`).

## 0.1.20 (21) - 2026-02-20
- Updated iOS app display name to `SpotChecker`.
- Rebuilt full iOS `AppIcon` asset set from `/home/ubuntu/codex_images/icon.png` (1024x1024 source).

## 0.1.19 (20) - 2026-02-20
- Parent child-details sheet now auto-scrolls to `Extra Time` when opened from a push/request prefill.
- `Extra Time` section is force-shown when prefill exists so the target anchor is always available.

## 0.1.18 (19) - 2026-02-20
- Switched backend APNs send transport from `fetch` to native `http2` client (APNs requires HTTP/2).
- Added explicit APNs HTTP/2 client/request timeout and error reasons (`client_error`, `request_error`, `timeout`) in diagnostics.

## 0.1.17 (18) - 2026-02-20
- Expanded push diagnostics to include exception detail text in `attempts` (helps identify APNs signing key format errors vs network failures).

## 0.1.16 (17) - 2026-02-20
- Added backend push diagnostics:
- New `POST /api/push/test` endpoint (parent/admin) returns APNs env/topic/config flags and per-token delivery attempts.
- `/admin` now has a per-device `Test push` button and prints diagnostic JSON.
- APNs error parsing now extracts `reason` (e.g. `BadDeviceToken`) and includes status/body in diagnostics.
- Added backend push delivery/failure summary logging.

## 0.1.15 (16) - 2026-02-20
- Updated Rules Schedule warning copy from "may prevent this phone" to "may prevent child phone".

## 0.1.14 (15) - 2026-02-20
- Reduced Rules Schedule time wheel picker touch area height to lower accidental time changes while scrolling.

## 0.1.13 (14) - 2026-02-20
- Added save warning in parent child settings when policy updates fail.
- Shows explicit offline warning (`No internet connection. Couldn't save settings.`) for likely network failures.

## 0.1.12 (13) - 2026-02-20
- Added `View Pairing` action in parent child details menu (under photo actions) to open the current pairing code in a popup.
- Added `AppModel.createPairingCode(deviceId:)` so pairing popup fetch does not depend on selected-device state.

## 0.1.11 (12) - 2026-02-20
- Fixed parent approve/deny flow so pending extra-time requests are always resolved from backend by `requestId` before action.
- Prevented accidental manual grant fallback from leaving pending requests uncleared.

## 0.1.10 (11) - 2026-02-20
- Fixed `/admin` JavaScript `ReferenceError: activateProtection is not defined` by restoring the missing `activateProtection` row variable.

## 0.1.9 (10) - 2026-02-20
- Added `/admin` backend build stamp under the page title (version, commit hash, boot timestamp, APNS env) to confirm which deployment is live.

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

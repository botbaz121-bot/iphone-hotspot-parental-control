# Changelog

## 0.1.97 (98) - 2026-02-21
- Updated web helper/subtext spacing: `.panel-sub` now uses `margin-top: 20px`.
- Updated web cache-bust versions to `styles.css?v=0.1.97` and `app.js?v=0.1.97`.

## 0.1.96 (97) - 2026-02-21
- Child settings: moved Protection On/Off indicator to the top-right corner of the main panel box.
- Parent settings header: removed `Parent Settings` subtitle pill and moved parent name/title to the left.
- Parent settings cleanup: removed `Profile` block and `Use the menu to rename.` helper text.
- Updated web cache-bust versions to `styles.css?v=0.1.96` and `app.js?v=0.1.96`.

## 0.1.95 (96) - 2026-02-21
- Made web success toast higher-contrast with full green background for clearer visibility.
- Removed duplicate `View Pairing Code` button from child settings actions; pairing code remains available via the three-dots menu only.
- Updated web cache-bust versions to `styles.css?v=0.1.95` and `app.js?v=0.1.95`.

## 0.1.94 (95) - 2026-02-21
- `View Pairing Code` on web now opens a persistent modal instead of a short-lived toast.
- Modal includes code, expiry time, and `Copy code` action so users have enough time to read/use it.
- Updated web cache-bust versions to `styles.css?v=0.1.94` and `app.js?v=0.1.94`.

## 0.1.93 (94) - 2026-02-21
- Welcome screen invite code input is now left-aligned (`inviteCode` field), instead of centered.
- Updated web cache-bust versions to `styles.css?v=0.1.93` and `app.js?v=0.1.93`.

## 0.1.92 (93) - 2026-02-21
- Removed welcome subtitle text (`Choose user type`) so only brand/title and mode tiles are shown.
- Updated web cache-bust versions to `styles.css?v=0.1.92` and `app.js?v=0.1.92`.

## 0.1.91 (92) - 2026-02-21
- Web header/branding polish:
- updated brand logo size to `46x46` with `margin-top: 8px`.
- Child settings header cleanup:
- removed `Child Settings` subtitle pill,
- moved child name/title to the left side of the subpage header row.
- Reworked add-child/add-parent dialogs to a proper modal layout (Flowbite-style structure):
- explicit modal header/body/footer sections,
- close button in modal header,
- improved spacing and input/button alignment.
- Updated web cache-bust versions to `styles.css?v=0.1.91` and `app.js?v=0.1.91`.

## 0.1.90 (91) - 2026-02-21
- Increased web logo header text size to `47px` (`.title`).
- Added top margin to section title rows: `.section-title-row { margin-top: 20px; }`.
- Updated web cache-bust versions to `styles.css?v=0.1.90` and `app.js?v=0.1.90`.

## 0.1.89 (90) - 2026-02-21
- Updated web welcome copy:
- subtitle changed from `Choose device type` to `Choose user type`,
- mode tiles renamed from `Parent phone` / `Child phone` to `Parent` / `Child`.
- Updated web cache-bust versions to `styles.css?v=0.1.89` and `app.js?v=0.1.89`.

## 0.1.88 (89) - 2026-02-21
- Reduced web section header size by 10px:
- `.section-title` desktop `52px -> 42px`,
- medium breakpoint `44px -> 34px`,
- mobile breakpoint `40px -> 30px`.
- Added base Flowbite-style modal component styling for web dialogs (`modal-backdrop`, `modal-card`, header/body/footer).
- Updated web cache-bust versions to `styles.css?v=0.1.88` and `app.js?v=0.1.88`.

## 0.1.87 (88) - 2026-02-21
- Web header/navigation updates:
- added top-left SpotChecker logo in web app shell (`web-app/logo-192.png`),
- made `logo + SpotChecker` in header navigate back to dashboard,
- removed explicit `Dashboard` subnav button from child/parent subpages.
- Removed the profile/role line under the logo header on authenticated pages (e.g. “Mr One Hundredzzddd Coparent”).
- Updated web cache-bust versions to `styles.css?v=0.1.87` and `app.js?v=0.1.87`.

## 0.1.86 (87) - 2026-02-21
- Tightened web desktop content width:
- reduced main container max-width from `1160px` to `920px`.
- Updated web cache-bust versions to `styles.css?v=0.1.86` and `app.js?v=0.1.86`.

## 0.1.85 (86) - 2026-02-21
- Kept a consistent SpotChecker header/top nav on web child and parent subpages.
- Removed back buttons from subpages.
- Added `Dashboard` top-nav action on subpages to return to main dashboard.
- Updated web cache-bust versions to `styles.css?v=0.1.85` and `app.js?v=0.1.85`.

## 0.1.83 (84) - 2026-02-21
- Adjusted web toast placement to top-center within the main content column (instead of viewport right edge).
- Kept mobile toast anchored near top with full-width inset behavior.
- Updated web cache-bust versions to `styles.css?v=0.1.83` and `app.js?v=0.1.83`.

## 0.1.82 (83) - 2026-02-21
- Fixed stale CSS issue by adding cache-busting query params to both web assets:
- `styles.css?v=0.1.82`
- `app.js?v=0.1.82`
- Bumped web build marker to `0.1.82-web` to make asset version visible in UI.

## 0.1.81 (82) - 2026-02-21
- Fixed web toast placement to Flowbite-style top position on all screen sizes.
- Removed mobile bottom-toast behavior so save feedback appears at the top while editing child settings.
- Updated web cache-bust script version to `app.js?v=0.1.81`.

## 0.1.80 (81) - 2026-02-21
- Web rename flow now edits the actual page title inline (no browser prompt dialogs):
- child and parent/invite rename opens inline text edit in header with Save/Cancel.
- Updated toast behavior to a clearer floating style:
- desktop: top-right toast,
- mobile: bottom safe-area toast.
- Success feedback now stays visible as a toast while top-page banners are error-only.
- Updated web cache-bust script version to `app.js?v=0.1.80`.

## 0.1.79 (80) - 2026-02-21
- Web child settings now auto-save on change (like iOS):
- toggles, day selection, schedule times, and daily limit changes save automatically.
- Removed `Update` button from web child settings.
- Added bottom toast confirmation (`Saved`) after successful auto-save.
- Updated web cache-bust script version to `app.js?v=0.1.78`.

## 0.1.78 (79) - 2026-02-21
- Removed end-user API base controls from web app welcome screen.
- Web app now always uses the production API base internally (`https://api.spotchecker.app`) for normal users.

## 0.1.77 (78) - 2026-02-21
- Refactored web app navigation to app-like separate screens:
- dashboard at `#/dashboard`,
- child settings at `#/child/:deviceId`,
- parent settings at `#/parent/:entryKey`.
- Replaced inline “quick add” with `+` modal dialogs for child creation and parent invites.
- Added child/parent top-right dropdown option menus (excluding photo):
- child: Rename, View Pairing Code, Delete,
- parent/invite: Rename, View Invite Code (invite), Delete (where allowed).
- Updated web cache-bust script version to `app.js?v=0.1.77`.

## 0.1.76 (77) - 2026-02-21
- Rebuilt `web-app` UI to match iOS visual feel and flows:
- iOS-style welcome with device-type tiles and `Join by invite` code entry,
- `Child Devices` / `Parent Devices` tile sections with matching spacing rhythm,
- redesigned child details panel for rules, schedule, extra time, and recent activity,
- redesigned parent details panel for rename, invite info, notifications, and delete actions,
- improved responsive behavior and user-friendly status/error banners.
- Updated web cache-bust script version to `app.js?v=0.1.76`.

## 0.1.75 (76) - 2026-02-21
- Removed temporary auth/debug text from the welcome screen.
- Matched `Parent Devices` section layout to `Child Devices`:
- same header/top-button spacing,
- same tile height,
- removed extra parent tile vertical padding that caused inconsistent gaps.

## 0.1.74 (75) - 2026-02-21
- Removed leftover household-switch plumbing now that Active Household UI was removed:
- deleted backend `/api/households` and `/api/households/active` routes,
- removed related iOS client/model/types and state.
- Adjusted `Parent Devices` header-to-tiles spacing to match `Child Devices` visual gap.

## 0.1.73 (74) - 2026-02-21
- Parent details screen cleanup:
- removed `Active Household` dropdown from UI,
- renamed section to `Notification Settings`,
- removed the follow-up account-type info card.
- Notification toggles now show for every parent profile but are disabled for non-own profiles.
- Invite creation is now name-only and required (email removed) across iOS + web UI.
- Backend invite create now requires `inviteName` and stores email as null.

## 0.1.72 (73) - 2026-02-21
- Added explicit vertical outer margin to parent tiles to ensure visible gap between parent rows.

## 0.1.71 (72) - 2026-02-21
- Adjusted parent tile vertical spacing:
- added explicit spacing between title/subtitle,
- increased parent tile height to avoid cramped rows.

## 0.1.70 (71) - 2026-02-21
- Added parent sign-in diagnostics:
- in-app debug line on welcome screen showing mode/signed-in/parentId and last auth event.
- Added extra parent-mode fallback after successful sign-in in `ParentSignInView`.
- Added auth/mode trace logging in `AppModel` for sign-in/sign-out/mode changes/dashboard refresh.

## 0.1.69 (70) - 2026-02-21
- Web app bootstrap hardening:
- added startup fail-safe panel so runtime errors show visibly instead of blank page,
- added fallback `#app` container creation,
- bumped web cache bust to `app.js?v=0.1.60`.

## 0.1.68 (69) - 2026-02-21
- Fixed parent sign-in return path:
- if session exists and `appMode` is nil after auth handoff, app now auto-enters Parent mode.
- Added this fallback on app active, sign-in state change, and initial load.

## 0.1.67 (68) - 2026-02-21
- Parent devices UX consistency:
- parent tiles now open a details sheet (like child flow),
- parent actions moved into a name dropdown in the sheet title.
- Added parent-level settings in that details screen:
- active household selector (multi-household switch),
- notification toggles (extra time, tamper placeholder).
- Added `+` button on Parent Devices to create invites from iOS (shows generated code).
- Landing title updated from `SpotCheck` to `SpotChecker`.

## 0.1.66 (67) - 2026-02-21
- Allowed rename for the signed-in parent profile from `Parent Devices`.
- Added current parent identity tracking (`parentId`) in app state/defaults.
- Parent tiles now show `Rename` for pending invites and your own profile only.

## 0.1.65 (66) - 2026-02-21
- Parent-device photo selection now uses the same crop flow as child photos.
- Added `ImageCropperView` flow for parent/invite tile photos before saving.

## 0.1.64 (65) - 2026-02-21
- Parent Devices menu now hides `Delete` for household owners.
- Prevents owner-removal action from being shown in-app.

## 0.1.63 (64) - 2026-02-21
- UI polish for parent/invite surfaces:
- `Parent Devices` title now matches `Child Devices` font sizing.
- Parent device tiles now use less cramped content layout.
- Added extra top spacing above `Join By Invite` on welcome screen.

## 0.1.62 (63) - 2026-02-21
- Parent dashboard updates:
- renamed "All Child Devices" to "Child Devices" and removed subtitle,
- added new "Parent Devices" section with parent/invite tiles and per-tile menu actions.
- Added iOS invite-join flow on welcome screen:
- new "Join By Invite" box with 4-character code entry and Apple sign-in + code accept flow.
- Added household management APIs and iOS wiring:
- list household members + invites in app state,
- rename/revoke pending invite,
- delete household member (owner only).

## 0.1.61 (62) - 2026-02-21
- Removed token-based invite surfaces from web UI.
- Invite list now shows code only (no `invite?token=...` link).
- Removed token accept panel from dashboard page.
- Updated invite copy to code-first entry at `web.spotchecker.app`.

## 0.1.60 (61) - 2026-02-21
- Allowed parents to join multiple households via invite acceptance.
- Added `parents.active_household_id` for active household context selection.
- Accepting an invite now sets the newly joined household as active context.
- Removed `already_in_other_household` restriction during invite accept.

## 0.1.59 (60) - 2026-02-21
- Fixed household invite code length mismatch:
- backend now generates 4-character invite codes (was 6),
- aligns with web code-entry UI and join flow.

## 0.1.58 (59) - 2026-02-21
- Added code-first entry flow on `web.spotchecker.app`:
- sign-in screen now supports entering a 4-character invite code before Apple login,
- new "Join with code" starts Apple auth and carries `inviteCode` through callback,
- post-login bootstrap auto-accepts the code and then loads dashboard.
- Updated web cache bust to `app.js?v=0.1.58`.

## 0.1.57 (58) - 2026-02-21
- Added explicit web login/debug diagnostics for dashboard load issues:
- auth screen now shows web build stamp and recent runtime debug trace,
- captures `window.error` and `unhandledrejection` with stack details,
- logs per-card binding state to isolate remaining null `onchange` sources.
- Added cache busting for web script load (`web-app/index.html` uses `app.js?v=0.1.57`).

## 0.1.56 (57) - 2026-02-21
- Added extra hardening for web dashboard rendering/binding:
- isolated per-device card listener binding in try/catch,
- prevents one malformed card from breaking full dashboard load,
- avoids auth-screen fallback loops caused by render-time exceptions.

## 0.1.55 (56) - 2026-02-21
- Hardened web dashboard event binding for child cards:
- added null-safe guards for day selector and row buttons,
- prevents render-time crashes from missing controls,
- fixes repeated `Cannot set properties of null (setting 'onchange')` load failures after sign-in/invite actions.

## 0.1.54 (55) - 2026-02-21
- Fixed web invite flow crash after creating an invite:
- invite cards no longer bind device schedule listeners,
- prevents `Cannot set properties of null (setting 'onchange')`,
- avoids forced redirect back to login from the post-create render failure.

## 0.1.53 (54) - 2026-02-20
- Added parent display name support:
- new `parents.display_name` field (with migration),
- Apple auth upsert now stores display name when available (web + native),
- `GET /api/me` now returns `parent.displayName`,
- added `PATCH /api/me/profile` to set/update display name.
- Added invite name support:
- new `household_invites.invite_name` field (with migration),
- invite create/list/detail APIs now accept/return `inviteName`.
- Updated web dashboard UI:
- profile card to edit display name,
- signed-in header uses display name fallback chain,
- household members list prefers display name,
- invite creation form supports optional invite name and renders it in invite list.

## 0.1.52 (53) - 2026-02-20
- Added Docker deployment support for web app (`web-app/`) for Coolify Docker mode:
- `web-app/Dockerfile` (nginx alpine static serve),
- `web-app/nginx.conf` with routes for `/invite` and SPA fallback to `/index.html`.

## 0.1.51 (52) - 2026-02-20
- Fixed backend startup crash in household bootstrap migration (`ReferenceError: Cannot access 'id' before initialization`):
- replaced early bootstrap `id()` calls with `crypto.randomUUID()` before `id` helper initialization.

## 0.1.50 (51) - 2026-02-20
- Fixed backend startup migration ordering for household rollout:
- delayed creation of `idx_devices_household` index until after legacy `devices.household_id` column backfill/migration.
- resolves restart loop on existing SQLite databases (`SqliteError: no such column: household_id`).

## 0.1.49 (50) - 2026-02-20
- Added initial web parent app scaffold at `web-app/` for `web.spotchecker.app`:
- dashboard shell with child list and policy editing controls,
- household members and invite management,
- dedicated `/invite` page for token/code acceptance.
- Added backend web auth improvements:
- Apple web callback now verifies identity token, mints session JWT, and redirects to web app with session hash.
- `/auth/apple/start` now supports `next` path round-trip for invite flows.
- Added backend CORS allowlist support for web app (`CORS_ALLOW_ORIGINS`).
- Added deployment notes in `web-app/README.md`.

## 0.1.48 (49) - 2026-02-20
- Added household architecture foundations on backend:
- new `households` and `household_members` models, auth context now resolves active household + member role.
- migrated parent-scoped device access to household scope across dashboard/devices/policy/events/extra-time/push test endpoints.
- added owner-only delete protection (`DELETE /api/devices/:id` requires household role `owner`).
- added household bootstrap/backfill migration logic for existing data (`devices.household_id` populated from legacy `parent_id` ownership).
- Added co-parent invite backend (token + code):
- `GET /api/household/me`, `GET /api/household/members`,
- `GET /api/household/invites`, `POST /api/household/invites`,
- `GET /api/household/invites/:token`,
- `POST /api/household/invites/:token/accept`,
- `POST /api/household/invite-code/accept`.
- Parent push fan-out now targets all active household members for extra-time requests.

## 0.1.47 (48) - 2026-02-20
- Fixed protection status grammar so single `Apps` action now reads `Apps are protected.` (while singular actions keep `is protected`).

## 0.1.46 (47) - 2026-02-20
- Updated `/admin` device table to show daily-limit warning pipeline diagnostics per child:
- daily-limit state (`limit/used/remaining/reached`),
- child push token count + last token update timestamp,
- last sent 5-minute warning day/timestamp.
- Extended `/api/dashboard` payload with `childPush` and `dailyLimitWarn5m` fields used by `/admin`.

## 0.1.45 (46) - 2026-02-20
- Moved child 5-minute daily-limit warning delivery to backend APNS (server-side minute sweep) for higher reliability.
- Added backend child push token registration endpoint (`POST /api/push/register-child`) authenticated by child `device_secret`.
- Added backend `child_push_tokens` storage and APNS send path for daily-limit warnings.
- Added per-day backend warning dedupe fields in `device_daily_usage` (`daily_limit_warn_5m_day_key`, `daily_limit_warn_5m_sent_at`).
- Updated iOS push sync to register token in child mode after pairing.
- Removed local App Intent notification fallback to avoid duplicate warnings.

## 0.1.44 (45) - 2026-02-20
- Child lock screen protection status now appends daily-limit usage text when configured (e.g. used X of Y today).
- Parent `Total daily limit` picker now shows values in `h/m` format and is capped at 8 hours.
- Added 5-minute remaining child warning notification via `FetchHotspotPolicyIntent` (deduped to once per child/day when daily limit is active).

## 0.1.43 (44) - 2026-02-20
- Added per-day `Total daily limit` control (15-minute intervals) under schedule start/end in parent child settings.
- Extended per-day schedule payload (`quietDays`) to persist `dailyLimitMinutes`.
- Added backend daily usage tracking (`device_daily_usage`) and limit-aware enforcement:
- once the daily limit is reached, `enforce` becomes true (same effective behavior as schedule enforcement).
- Added `dailyLimit` status payload in `/policy` and `/api/dashboard` (`limitMinutes`, `usedMinutes`, `remainingMinutes`, `reached`).
- Updated protection status messaging to reflect daily-limit reached and remaining-time states.
- Updated `/admin` row-save behavior to preserve extra day fields in `quietDays` when editing times.

## 0.1.42 (43) - 2026-02-20
- Full rewrite of website copy across homepage, support, and privacy pages with clearer value proposition and tighter parent-focused language.
- Strengthened SEO-facing metadata copy (title/description/OG/Twitter) for homepage and support/privacy pages.
- Refined homepage sections (`hero`, controls list, FAQs) to be more direct and conversion-focused.

## 0.1.41 (42) - 2026-02-20
- Rewrote website copy across homepage, support, and privacy pages with clearer parent-facing messaging and tighter language.
- Refined homepage hero, feature value bullets, and FAQ wording.
- Improved support troubleshooting wording and privacy-policy plain-language clarity.

## 0.1.40 (41) - 2026-02-20
- Updated `spotchecker.app` pages with current product capabilities and onboarding flow:
- Rules Enforcement Schedule, app lock setup guidance, extra-time request/approval flow, and push notification support.
- Replaced gradient placeholder brand block with the new SpotChecker logo image site-wide.
- Added favicon and app-icon assets (`favicon.ico`, PNG sizes, Apple touch icon).
- Improved on-page SEO across homepage/support/privacy:
- richer page titles and descriptions, canonical URLs, robots directives, Open Graph/Twitter metadata, and SoftwareApplication structured data on homepage.

## 0.1.39 (40) - 2026-02-20
- Removed duplicate `Rules Schedule` heading in parent child settings.
- Renamed toggle title from `Enforcement schedule` to `Rules Enforcement Schedule`.

## 0.1.38 (39) - 2026-02-20
- Added missing full stop in parent Lock Apps subtitle (`Set list on child phone.`).

## 0.1.37 (38) - 2026-02-20
- `Lock Shortcuts` tile now shows the Shortcuts icon in both incomplete and complete states.
- Updated incomplete subtitle to: `Pick Productivity & Finance > Shortcuts to lock`.

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

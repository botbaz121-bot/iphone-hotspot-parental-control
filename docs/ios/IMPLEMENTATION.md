# SpotCheck iOS (SwiftUI) — Implementation Plan

> Source of truth for this doc:
> - Web prototype routes: `prototype-web/app.js`
> - Product docs: `docs/*.md`
> - Backend API: `backend/src/index.js`
> - iOS scaffold (WIP): `ios-app/HotspotParentApp/**`, `ios-app/xcodegen/**`, `codemagic.yaml`

## 0) Scope decision (v1)

**Recommended v1 = Option A (“Setup + Status only”)** from `docs/BUILD_PLAN_V1.md`:
- The App Store build **does not** ship backend `ADMIN_TOKEN` capabilities.
- Parent policy editing is either:
  - deferred to `backend/src/index.js` admin UI (`/admin`) during alpha, **or**
  - implemented with real parent auth (Sign in with Apple) + server sessions (bigger scope).

This plan still documents both tracks:
- **v1A (recommended):** child setup + status; policy editing read-only in iOS.
- **v1B (optional upgrade):** parent can edit policy in-app.

---

## 1) Screen-by-screen spec (SwiftUI) mapped to prototype routes

### Navigation architecture

**Prototype navigation rules (from `prototype-web/app.js`):**
- Landing and onboarding/auth hide tab bar.
- Parent flow uses bottom tabs: Home (landing), Dashboard, Settings.
- Child flow uses bottom tabs: Home (landing), Dashboard, Settings (but the “Locked” screen hides tabs).

**SwiftUI approach:**
- Root coordinator decides **AppMode** (`.parent` vs `.childSetup`) and auth state.
- Use `TabView` for each mode, each tab containing its own `NavigationStack`.
- Present sheets with `.sheet` for “Add device” and “Shortcut not running”.

**Files to create/update:**
- Update: `ios-app/HotspotParentApp/Sources/HotspotParentApp/Views/RootView.swift`
- Add:
  - `ios-app/HotspotParentApp/Sources/HotspotParentApp/Views/Parent/ParentTabView.swift`
  - `ios-app/HotspotParentApp/Sources/HotspotParentApp/Views/Child/ChildTabView.swift`
  - `ios-app/HotspotParentApp/Sources/HotspotParentApp/Views/Shared/AppModeSwitcherView.swift`

#### Shared state you’ll need
- `AppMode`: `.parent` | `.childSetup`
- `SessionState`: signed-in vs locked (child unlock)
- `SelectedDeviceId` for parent dashboard carousel

Store in:
- `@MainActor class AppModel: ObservableObject` (existing at `.../App/AppModel.swift`) but expanded.

---

### Route: `/` — Landing (prototype `screenLanding()`)

**UI (SwiftUI mapping):**
- Large hero title “SpotCheck”
- Two primary buttons:
  - “Parent phone” → sets mode `.parent` and navigates to parent onboarding
  - “Set up child phone” → sets mode `.childSetup` and navigates to child onboarding
- Optional ad card (if IAP not purchased)
- “Reset mockup” → in iOS becomes “Reset local data” (debug only)

**Components:**
- `VStack` with hero header
- `Button` x2
- `AdBannerCardView` (conditional)
- Debug section inside `#if DEBUG`

**State:**
- `model.appMode` persisted
- `model.adsRemoved` (StoreKit) determines ad card visibility

**Files:**
- Add: `Views/LandingView.swift`

---

### Parent flow

#### Route: `/parent/onboarding` — Parent Welcome (prototype `screenParentOnboarding()`)

**UI:**
- Title “Welcome” + subtitle copy
- Feature grid (3 tiles): Per-device rules, Guided setup, Tamper warning
- Constraints card
- CTA “Continue” → parent sign-in

**SwiftUI mapping:**
- `ScrollView` + `LazyVGrid`
- `FeatureTileView(icon:title:subtitle:)`

**State:** none beyond navigation.

**Files:**
- Add: `Views/Parent/ParentOnboardingView.swift`

#### Route: `/parent/signin` — Parent Sign In (prototype `screenParentSignIn()`)

**UI:**
- Sign in with Apple button

**Implementation options:**
1) **Native Sign in with Apple (recommended)** using `AuthenticationServices`.
   - You already have a stub UI: `Views/SignInView.swift`.
   - Wire the real token exchange to backend (see API section).

2) **Dev-only stub** remains available in DEBUG.

**State:**
- `model.session` contains parent session token (server) OR local stub.

**Files:**
- Update:
  - `ios-app/HotspotParentApp/Sources/HotspotParentApp/Views/SignInView.swift`
  - `ios-app/HotspotParentApp/Sources/HotspotParentApp/AppleSignIn.swift` (already present; integrate)

#### Route: `/parent/dashboard` — Parent Dashboard (prototype `screenParentDashboard()`)

**UI sections:**
1) Ad card (unless removed)
2) **Device switcher carousel**
   - horizontally scrollable cards, with last “Enroll device” CTA card
3) “Device rules” card
   - toggle Hotspot OFF
   - toggle Quiet Time schedule
   - if enabled: Start/End time inputs
   - Save rules
4) Recent activity list (scrollable)
5) Troubleshooting card
   - “Shortcut not running” bottom sheet
   - “Remove device”
6) Tamper warning card

**SwiftUI mapping:**
- Carousel: `ScrollView(.horizontal)` + `LazyHStack`
  - Each `DeviceCardView(device:isSelected:)`
  - CTA card triggers `EnrollmentSheetView` (see below)
- Toggles: `Toggle` with custom row styling
- Quiet start/end: `DatePicker` in `.hourAndMinute` OR masked `TextField("HH:mm")`
- Activity: `List` inside card OR `ScrollView` with rows
- Troubleshooting: `Button`s; present `.sheet` for instructions

**State:**
- `model.devices: [ManagedDevice]`
- `model.selectedDeviceId`
- For v1A, devices/policy likely **read-only** unless admin or signed-in parent.

**Backend interactions (v1B):**
- `GET /api/dashboard` (admin-only currently) OR new authenticated parent endpoints.
- `PATCH /api/devices/:id/policy`
- `GET /api/devices/:id/events`

**Files:**
- Replace current minimal dashboard:
  - Update: `Views/DashboardView.swift` (currently a dev status screen)
- Add:
  - `Views/Parent/ParentDashboardView.swift`
  - `Views/Parent/DeviceCarouselView.swift`
  - `Views/Parent/DeviceRulesCardView.swift`
  - `Views/Parent/RecentActivityCardView.swift`
  - `Views/Parent/TamperWarningCardView.swift`
  - `Views/Parent/ShortcutNotRunningSheetView.swift`

#### Route: `/parent/device/:id` — Device Details (prototype `screenParentDeviceDetails()`)

**Note:** prototype kept this route but mostly inlined everything into Dashboard.

**Recommendation:**
- Keep iOS v1 as **inline dashboard** (no separate details), unless needed later.
- If you add it, it’s a `NavigationLink` from the device card.

**Files (optional):**
- `Views/Parent/DeviceDetailView.swift`

#### Route: `/parent/settings` — Parent Settings (prototype `screenParentSettings()`)

**UI sections:**
- Mode toggle “This is a child phone” (switch between parent and child experience)
- Account: signed in yes/no, sign out
- In-app purchase: Remove ads / Restore
- Debug info

**SwiftUI mapping:**
- `Form` with sections
- Mode switch flips `model.appMode` and navigates to correct tab root.

**IAP wiring:** see section 6.

**Files:**
- Update existing: `Views/SettingsView.swift` (currently backend+policy debug)
- Add:
  - `Views/Parent/ParentSettingsView.swift`

---

### Child setup flow

In prototype, child mode is still within the same app, but after setup it can be “Locked” and require parent unlock.

#### Route: `/child/onboarding` — Child Welcome (prototype `screenChildOnboarding()`)

**UI:**
- Hero with “Welcome” and summary
- “Continue” sets `isChildPhone = true` and goes to child dashboard checklist

**SwiftUI mapping:**
- `ChildOnboardingView` sets `model.appMode = .childSetup`

**Files:**
- Add: `Views/Child/ChildOnboardingView.swift`

#### Route: `/child/dashboard` — Child Setup Checklist Dashboard (prototype `screenChildDashboard()`)

**UI (4 cards):**
1) Pair device
   - button: Start pairing / View pairing
   - unpair button if paired
2) Install our Shortcut
   - button: open iCloud Shortcut link
   - status: “Shortcut runs” (awaiting first run, done after 1)
3) Automations
   - status: “Multiple runs observed” (>=2)
4) Screen Time lock
   - status: authorization + shielding applied
   - button: “Select apps to shield”
5) Finish setup button → locked screen

**SwiftUI mapping:**
- Each step is a `SetupStepCardView`
- State comes from:
  - local persisted pairing status + device credentials
  - observed App Intent run counts / last run date (see App Intents section)
  - FamilyControls authorization state

**State fields (model):**
- `childSetup.paired: Bool`
- `childSetup.deviceId/deviceToken/deviceSecret/apiBaseURL`
- `childSetup.appIntentRunCount`, `lastAppIntentRunAt`
- `childSetup.familyControlsAuthorized`, `shieldingApplied`

**Files:**
- Add:
  - `Views/Child/ChildDashboardView.swift`
  - `Views/Child/SetupStepCardView.swift`

#### Route: `/child/settings` — Child Settings & Pairing (prototype `screenChildSettings()`)

**UI:**
- Mode toggle
- Pairing section:
  - Scan QR (mock) OR Enter pairing code
  - Unpair
- Debug helpers (prototype only): simulate shortcut run, toggle Screen Time auth, reset

**SwiftUI mapping (real app):**
- Pairing:
  - QR scanner using `AVFoundation` (camera) to scan a code OR manual entry.
  - Redeem pairing code by calling backend `POST /pair`.
- Remove prototype-only debug helpers from release builds.

**Files:**
- Add:
  - `Views/Child/ChildSettingsView.swift`
  - `Views/Child/Pairing/PairingEntryView.swift`
  - `Views/Child/Pairing/QRScannerView.swift`

#### Route: `/child/screentime` — Screen Time Lock (prototype `screenChildScreenTime()`)

**UI:**
- explanation
- list of recommended apps to shield: Settings + Shortcuts
- apply shielding
- reminder: parent must set Screen Time passcode manually

**SwiftUI mapping:**
- Use `FamilyControls` + `ManagedSettings`:
  - Request authorization
  - Present `FamilyActivityPicker` to select apps/categories
  - Apply `ManagedSettingsStore().shield.applications = selection.applicationTokens`

**Important limitations:** see feasibility section.

**Files:**
- Add:
  - `Views/Child/ScreenTime/ScreenTimeSetupView.swift`
  - `Services/ScreenTime/ScreenTimeManager.swift`

#### Route: `/child/locked` — Locked Screen (prototype `screenChildLocked()`)

**UI:**
- “Setup complete”
- Button: Unlock (parent)

**SwiftUI mapping:**
- A full-screen view without TabView.
- Use app state `childSetup.isLocked = true`.

**Files:**
- Add: `Views/Child/ChildLockedView.swift`

#### Route: `/child/unlock` — Parent Unlock (prototype `screenChildUnlock()`)

**UI:**
- Sign in to unlock setup screens

**SwiftUI mapping:**
- Require parent sign-in (Sign in with Apple) to unlock.
- For v1A, can be a local “parent pin” fallback in DEBUG.

**Files:**
- Add: `Views/Child/ChildUnlockView.swift`

---

### Bottom sheet modals (prototype `openSheet()`)

1) “Add device” sheet (`enrollmentSheet()`)
- Device name field
- Enrollment token display + copy + regenerate
- Next steps checklist
- Buttons: Add device, Set up child phone

2) “Shortcut not running” sheet (`shortcutNotRunningSheet()`)
- Quick checks list
- Common issues list
- Button: Open Shortcuts

**SwiftUI mapping:**
- `.sheet(isPresented:)` with `NavigationStack` inside (for large sheets)
- Use `UIApplication.shared.open(URL(string:"shortcuts://")!)` where allowed

**Files:**
- Add:
  - `Views/Parent/AddDeviceSheetView.swift`
  - `Views/Parent/ShortcutNotRunningSheetView.swift`

---

## 2) Required data models / entities

### Shared domain models (Swift)
Create/expand in:
- `ios-app/HotspotParentApp/Sources/HotspotParentApp/Models.swift`

Suggested models:
```swift
enum AppMode: String, Codable { case parent, childSetup }

struct ManagedDevice: Identifiable, Codable {
  var id: String
  var name: String
  var lastSeenAt: Date?
  var lastEventAt: Date?
  var status: DeviceStatus // ok, stale, setup
  var policy: DevicePolicyView
  var recentEvents: [DeviceEvent]
}

enum DeviceStatus: String, Codable { case ok, stale, setup }

struct DevicePolicyView: Codable {
  var enforce: Bool
  var hotspotOff: Bool
  var rotatePassword: Bool
  var quiet: QuietHours?
  var gapMs: Int
}

struct QuietHours: Codable {
  var start: String? // "HH:mm"
  var end: String?
  var tz: String?
}

struct DeviceEvent: Identifiable, Codable {
  var id: String
  var ts: Date
  var trigger: String
  var actionsAttempted: [String]
  var ok: Bool
  var errors: [String]
}

struct HotspotConfig: Codable {
  var apiBaseURL: String
  var deviceToken: String
  var deviceSecret: String
}
```

### Persistence representation
- `HotspotConfig` must be shared with App Intents (Shortcuts) → store in **Keychain + App Group** (details below).

---

## 3) Backend / API endpoints needed

### Backend already implemented (SQLite + Express)
Source: `backend/src/index.js`.

#### Shortcut endpoints (public)
- `GET /policy` (requires Shortcut auth)
  - Returns: `{ enforce, actions: { setHotspotOff, rotatePassword }, quietHours }`
- `POST /events` (requires Shortcut auth)
  - Body: `{ ts, trigger, shortcutVersion?, actionsAttempted?, result? }`
- `POST /pair` (public)
  - Body: `{ code, name? }`
  - Returns: `{ deviceId, name, deviceToken, deviceSecret }`
- `GET /healthz`

#### Admin endpoints (temporary)
- `GET /api/dashboard` (Bearer ADMIN_TOKEN)
- `GET /api/devices`
- `POST /api/devices`
- `POST /api/devices/:deviceId/pairing-code`
- `PATCH /api/devices/:deviceId/policy`
- `GET /api/devices/:deviceId/events`

### What’s missing for a real App Store parent app (policy editing + multi-device)
If you want v1B (parent edits policy in iOS) **without shipping ADMIN_TOKEN**, add:

1) **Native Sign in with Apple session**
- `POST /auth/apple/native` (new)
  - Accepts `identityToken` + `authorizationCode`
  - Validates `id_token` signature and creates a server session
  - Returns `sessionToken` (JWT or opaque) + user record

2) Parent-scoped device management endpoints
- `GET /v1/devices`
- `POST /v1/devices` (create placeholder + pairing code)
- `POST /v1/devices/:id/pairing-code`
- `GET /v1/devices/:id/policy`
- `PATCH /v1/devices/:id/policy`
- `GET /v1/devices/:id/events`

3) Device ownership model in DB
- Add `users` table keyed by Apple `sub`
- Add `user_id` to devices

**If you keep v1A:** iOS child setup app only needs `/pair` + Shortcut endpoints.

---

## 4) App Intents needed for Shortcuts

Goal from mockups/docs: Shortcut should **not** embed secrets; it calls the app first to retrieve config.

### App Intents target setup
- Add an **App Intents extension** (or include intents in main target if possible).
- Ensure the intents can access the Keychain item (use Keychain access group / App Group).

### Required intents

#### A) `GetHotspotConfigIntent` (required)
**Purpose:** First step in the Shortcut. Returns a JSON dictionary/string containing:
- `apiBaseURL`
- `deviceToken`
- `deviceSecret`

**Shortcuts usage pattern:**
1) Run “Get Hotspot Config” → returns Dictionary
2) Use “Get Contents of URL”:
   - URL: `{{apiBaseURL}}/policy`
   - Header: `Authorization: Bearer {{deviceSecret}}`
   - (Optional) Header: `X-Device-Token: {{deviceToken}}`

**Implementation:**
- File: `ios-app/HotspotParentApp/Sources/HotspotParentApp/Intents/GetHotspotConfigIntent.swift`
- Reads config from `KeychainStore` (see persistence section)

#### B) (Optional) `PostSpotCheckEventIntent`
**Purpose:** Remove networking from Shortcut.
- Shortcut runs intent with parameters like trigger/actions/result.
- Intent posts to `/events` using stored config.

Pros:
- Easier Shortcut (no custom headers)
- Secrets never leave app process

Cons:
- More code, more failure modes; less transparent.

#### C) (Optional) `FetchPolicyIntent`
Similar to B, but returns actions to the Shortcut.

#### D) (Optional) `EnforceNowIntent` (NOT recommended for MVP)
Would attempt enforcement inside the app. iOS apps generally can’t toggle hotspot; enforcement remains in Shortcuts.

### Intent run telemetry
To power the child checklist (“Seen N runs”), each intent execution should:
- increment `appIntentRunCount`
- set `lastAppIntentRunAt`

Store in shared defaults (App Group `UserDefaults(suiteName:)`) so app and intents share it.

---

## 5) Screen Time / FamilyControls feasibility (what can/can’t be detected)

Source: `docs/FEASIBILITY.md` + Apple framework constraints.

### What you can do (iOS 16+)
- Request **FamilyControls** authorization.
- Present an app picker UI (`FamilyActivityPicker`) so the parent selects apps to restrict.
- Apply shielding via `ManagedSettingsStore`:
  - Shield **Shortcuts** app to prevent edits.
  - Potentially shield **Settings** as well (token availability varies; test on-device).

This supports the doc’s noted result:
- Even when Shortcuts app is limited/blocked, **existing automations may still run**.

### What you cannot reliably do
- You generally **cannot detect**:
  - whether Screen Time passcode is set (`docs/MOCKUPS.md` explicitly notes this)
  - whether specific personal automations exist or are enabled
  - whether “Ask Before Running” is off
  - whether hotspot is currently ON/OFF from public APIs

### How to model status in UI (important)
- Treat these items as **confidence signals**:
  - “Screen Time authorized” (true/false)
  - “Shielding applied” (true/false)
  - “Shortcut ran at least once” (via intent run count or backend events)
  - “Multiple runs observed” (>=2)

**Do not claim** you can detect exact hotspot state.

---

## 6) IAP “Remove ads” wiring (StoreKit 2)

Prototype behavior:
- Parent screens show an ad card unless `adsRemoved` is true.

### Product
- Non-consumable: `remove_ads`

### Swift implementation
- Create `IAPStore` (ObservableObject) using StoreKit 2.
- On app start:
  - load products
  - call `Transaction.currentEntitlements` to determine purchase state

### UI integration
- `AdBannerCardView` only shown when `!iap.hasRemoveAds`.
- Settings:
  - “Remove ads” purchase button
  - “Restore purchase” button (`Transaction.latest(for:)` or `AppStore.sync()`)

**Files:**
- Add:
  - `Services/IAP/IAPStore.swift`
  - `Views/Shared/AdBannerCardView.swift`
- Update settings view(s) to use IAP state.

---

## 7) Persistence / Keychain storage plan

### What goes where

**Keychain (secure, required):**
- Child device credentials (returned by `POST /pair`):
  - `deviceToken`
  - `deviceSecret`
  - `apiBaseURL`
- (If/when you have server sessions) parent `sessionToken`

**App Group UserDefaults (shared with App Intents):**
- `appMode` (.parent/.childSetup)
- child setup checklist state:
  - `appIntentRunCount`
  - `lastAppIntentRunAt`
  - `screenTimeAuthorized`
  - `shieldingApplied`
- last selected device id (parent)

**Regular UserDefaults:**
- purely cosmetic / non-sensitive UI state

### Implementation
- Add `KeychainStore` wrapper (SecItemAdd/SecItemCopyMatching) with Codable blobs.
- Use a single Keychain item for `HotspotConfig`.

**Files:**
- Add:
  - `Storage/KeychainStore.swift`
  - `Storage/SharedDefaults.swift` (App Group suite)

### App Group + Keychain access groups
- If intents are in an extension, both targets must share:
  - App Group identifier (for shared defaults)
  - Keychain access group (so extension can read the config)

Update entitlements:
- `ios-app/xcodegen/HotspotParentiOS/HotspotParent.entitlements`

---

## 8) Build/signing/Codemagic steps

Source: `codemagic.yaml` + XcodeGen spec `ios-app/xcodegen/project.yml`.

### Current pipeline
- Installs XcodeGen
- Patches `CURRENT_PROJECT_VERSION` to epoch seconds
- Generates project from `ios-app/xcodegen/project.yml`
- Applies provisioning profiles (`xcode-project use-profiles`)
- Archives & exports IPA
- Uploads to TestFlight

### What you must set up in Codemagic UI
- Certificates:
  - `hotspotparent-distribution`
- Provisioning profile:
  - `hotspotparent_appstore_profile`
- App Store Connect integration

### What you must set up in Apple Developer
- Bundle ID: `com.bazapps.hotspotparent`
- Sign in with Apple capability (already in entitlements)
- If adding App Group + Keychain group, configure those identifiers

### XcodeGen updates likely needed
When adding extensions (App Intents), update:
- `ios-app/xcodegen/project.yml` to include:
  - new target `HotspotParentIntentsExtension`
  - proper entitlements + Info.plist entries

---

## 9) Prioritized TODO list (estimates + risk notes)

Estimates assume one experienced iOS dev, working full-time.

### Phase 0 — Align on v1 scope (0.5 day)
- [ ] Confirm v1A vs v1B.
  - **Risk:** v1B requires secure parent auth; don’t ship ADMIN_TOKEN.

### Phase 1 — App mode + navigation + screens skeleton (3–5 days)
- [ ] Implement `LandingView` + mode switcher
- [ ] Implement Parent tabs scaffold (Dashboard/Settings)
- [ ] Implement Child tabs scaffold (Dashboard/Settings) + Locked/Unlock flow
- [ ] Create reusable card/tile components to match prototype look

**Risks:** moderate (mostly UI work).

### Phase 2 — Child pairing + secure storage (3–6 days)
- [ ] Pairing entry + QR scanner
- [ ] `POST /pair` integration and error handling
- [ ] Keychain storage for `HotspotConfig`
- [ ] Display pairing state and unpair

**Risks:** camera permissions UX; Keychain group complexities when adding intents.

### Phase 3 — App Intents + Shortcut contract (4–7 days)
- [ ] Add `GetHotspotConfigIntent`
- [ ] App Group shared defaults; track run count + last run
- [ ] Provide in-app “Install Shortcut” link + instructions
- [ ] (Optional) `PostSpotCheckEventIntent` / `FetchPolicyIntent`

**Risks:** App Intents + extension entitlements/signing is fiddly; needs device testing.

### Phase 4 — Screen Time shielding (4–8 days)
- [ ] `FamilyControls` authorization flow
- [ ] App picker + shielding apply/remove
- [ ] UX copy that clearly states limitations

**Risks:**
- Shielding Settings may or may not work as expected; must test on real devices.
- Users must set Screen Time passcode manually; cannot be verified.

### Phase 5 — Parent dashboard w/ real devices + status (v1A: 2–4 days, v1B: 2–3 weeks)

**v1A (recommended):**
- [ ] Parent dashboard shows locally known devices + “last seen” from backend events (if you add read-only endpoints)

**v1B:**
- [ ] Implement real parent auth (native Sign in with Apple) on backend
- [ ] Replace admin endpoints in app with session-based endpoints
- [ ] Full dashboard: list devices, edit quiet hours/hotspot off, view activity

**Risks:** backend auth, App Store review risk if claims are too strong.

### Phase 6 — IAP remove ads (2–4 days)
- [ ] StoreKit2 implementation
- [ ] Settings purchase/restore UI
- [ ] Hide ad card on parent screens

**Risks:** minor; needs App Store Connect product setup.

### Phase 7 — CI + TestFlight hardening (1–3 days)
- [ ] Add extension targets to XcodeGen + Codemagic
- [ ] Ensure signing works for all targets
- [ ] Add basic UI tests (optional)

**Risks:** signing + provisioning profiles for multiple targets.

---

## Appendix A — Mockup element → iOS component mapping (quick reference)

- Device carousel → `ScrollView(.horizontal) + LazyHStack + .scrollTargetBehavior(.paging)` (iOS 17+) or manual paging
- Bottom sheet → `.sheet` / `.presentationDetents([.medium, .large])`
- Badge (OK/STALE/SETUP) → `Text` with `.font(.caption.weight(.semibold))` + colored background capsule
- Toggle switch row → `Toggle` with `.labelsHidden()` plus a custom `HStack` label
- Time inputs → `DatePicker` (hour/minute) OR `TextField` with validation to "HH:mm"
- Activity list (scrollable) → `ScrollView` inside a card, or `List` section
- QR code → existing helper `Utilities/QRCode.swift`

---

## Appendix B — Current iOS scaffold status (what exists today)

Already in repo:
- XcodeGen app wrapper target: `ios-app/xcodegen/HotspotParentiOS/*`
- Swift package with MVP views:
  - `Views/RootView.swift`, `OnboardingView.swift`, `SignInView.swift`, `DashboardView.swift`, `EnrollmentView.swift`, `SettingsView.swift`
- Backend client (admin/dev): `HotspotAPIClient.swift`
- Apple web auth notes: `docs/APPLE_AUTH.md`

Gaps vs prototype:
- No parent/child mode switching experience
- No child setup checklist screens
- No real pairing flow using `/pair`
- No App Intents
- No FamilyControls integration
- No StoreKit IAP


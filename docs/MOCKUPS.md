# Hotspot Parent — Mockups (v0.2)

This document is **planning-first**: screens, flows, copy, and required backend/Shortcut hooks.

> Constraint reminder: iOS apps cannot reliably toggle Personal Hotspot via public APIs. Enforcement is via **Shortcuts automations** (deterrence + audit). This app is the **parent/admin UI**.

---

## Information Architecture

This is a **two-mode** app installed on **both phones** (the parent sets up both):
- **Parent mode** (admin UI)
- **Setup Child Device mode** (pairing + config file generator for the Shortcut)

On first launch, choose a mode:
- [Parent phone]
- [Set up child phone]

### Parent mode (signed-in)
Bottom tabs:
- **Dashboard**
- **Devices**
- **Settings**

### Child mode
Single flow (no tabs needed for MVP):
- Pair device → Generate hotspot-config.json → Export to Files for the Shortcut


---

## Key Entities (mental model)

- **Account** (parent)
- **Family** (optional; can be single-parent account)
- **Device** (child phone; enrolled via QR/token)
- **Policy** (what we want enforced)
- **Check-ins** (child-side Shortcut/app events proving coverage)

---

## Core Flows

### Flow A — Parent first run
1) Onboarding (what it does / what it cannot do)
2) Choose mode: **Parent**
3) Sign in with Apple
4) Add first device (Enrollment QR)
5) Policy defaults per device: **Hotspot OFF = ON**, Quiet Time optional
6) Setup guide for child device (install Child app + Shortcut)

### Flow B — Set up child phone (parent using the child phone)
1) Onboarding
2) Choose mode: **Set up child phone**
3) Pair device (scan QR / enter code)
4) Generate `hotspot-config.json`
5) Export file to **Files → On My iPhone → Shortcuts** as **`hotspot-config.json`** so the Shortcut can read it
6) Install/enable automations

### Flow C — Add a device (Shortcuts-only)
1) Parent generates **Enrollment QR** (contains enrollment token)
2) On child iPhone: install **Child app** + install Shortcut
3) In **Child app**: scan QR → pair with backend → receive device credentials
4) Child app generates **`hotspot-config.json`** and exports it to **Files → On My iPhone → Shortcuts**
5) Shortcut reads **`hotspot-config.json`** to:
   - authenticate to backend
   - fetch policy
   - post check-ins
   - perform actions (turn hotspot off + rotate password)
6) Parent sees device status + last check-in

### Flow C — Ongoing
- Shortcut automation runs (battery/time-of-day) → fetch policy → attempts actions (rotate password, etc.) → posts event
- Parent app shows compliance + gaps

---

## Screen Mockups (text wireframes)

Notation:
- `[button]` tappable action
- `(field)` input
- `⚠️` warning

### 0) Onboarding

**Welcome to Hotspot Parent**
- Subtitle: “Shortcuts-only hotspot control + visibility.”

Mode selection:
- [Parent phone]
- [Set up child phone]

Cards:
- **What this can do**
  - “Set ‘Hotspot OFF’ policy”
  - “Guide setup on child phone”
  - “Show last check-in + gaps”
- **What iOS doesn’t allow**
  - “Apps can’t directly toggle Personal Hotspot.”
  - “We use Shortcuts automations instead.”

Actions:
- [Continue]

---

### 1) Sign In

Title: **Sign In**
- Apple button: [Sign in with Apple]
- Small text: “We don’t access your Apple password.”

Fallback (dev only):
- [Continue without Apple]

Error area:
- show raw error + “Try again”

---

### 2) Dashboard (tab)

Nav title: **Dashboard**

Top: **Device switcher**
- Horizontal paging/swipe between devices (like cards)
- Or a compact picker: “Device: Child iPhone ▾”

Per-device card shows:

Section: **Status**
- “Hotspot OFF: ON/OFF” (per device)
- “Quiet Time: ON/OFF” (per device)
  - If ON: show “22:00–07:00”

Section: **Coverage**
- “Last check-in: 12 min ago”
- If stale: `⚠️ No check-in for 2h 10m`

Section: **Latest run**
- “Hotspot turned off: success/failed”
- “Password rotated: success/failed”

Section: **Quick actions**
- [Open Device Details]
- [Setup Guide]

Global summary (small, optional):
- “Devices with gaps: 1”

Pull to refresh.

---

### 3) Devices (tab)

Nav title: **Devices**

List rows:
- Device name (e.g., “Child iPhone”)
  - Subtitle: “Last check-in 12m ago”
  - Badge: `OK` / `GAP` / `SETUP` / `OFFLINE`

Actions:
- [+ Add Device]

---

### 4) Add Device — Enrollment QR

Nav title: **Enroll Device**

Card: **Enrollment token**
- Monospace token
- [Copy]  [Regenerate]

Card: **QR**
- QR image

Card: **Next on the child phone**
1. “Install the Child app”
2. “Open Child app → Pair device → Scan this QR”
3. “Install the Shortcut” [Open Shortcut link]
4. “In Child app: Export hotspot-config.json to Files”
5. “Enable automations” [Setup Automations]

Footer:
- “This QR links the child device to your account and produces the config file the Shortcut uses.”

---

### 5) Setup Automations (guide)

Nav title: **Setup**

Step list:
- Step 1: Install Shortcut
- Step 2: Turn on Automations
  - “Battery level” (e.g., 10%, 20%, …)
  - “Time of day” (e.g., every 15 min blocks)
  - Note: “iOS may prompt; set ‘Ask Before Running’ off if available.”
- Step 3: Lock down changes (important)
  - Goal: make it hard for the child to disable/modify the Shortcut/automations.

  **In-app Screen Time integration (preferred):**
  - We can use Apple’s **Screen Time APIs** (FamilyControls/DeviceActivity) to help the parent apply app/category restrictions.
  - This requires the parent to **grant Screen Time control permission** when prompted.

  **Important:** the parent must also set a **Screen Time passcode** on the child phone, otherwise restrictions are easy to change.
  - We can’t set this passcode for them; we must remind + verify.

  - What we *can* do:
    - ask permission via a native authorization prompt
    - let the parent select apps/categories to restrict (e.g. Settings, Shortcuts)
    - apply schedules/limits using Screen Time frameworks
    - show a checklist gate: “Screen Time passcode set ✅ / Not yet”
  - What we *cannot reliably do*:
    - set a Screen Time passcode
    - guarantee Shortcuts automations cannot be edited/deleted (we can only raise the cost)

  **Fallback (manual instructions):**
  1. Settings → Screen Time → Turn on Screen Time (parent sets a Screen Time passcode)
  2. Screen Time → Content & Privacy Restrictions → ON
  3. Content & Privacy Restrictions → Account Changes → Don’t Allow
  4. Content & Privacy Restrictions → Passcode Changes → Don’t Allow
  5. Use App Limits/Downtime to reduce access to Settings/Shortcuts

  **Shortcut tamper signals (in-app):**
  - Show “Last check-in …”
  - Show “Stale check-in” warnings
  - Explain likely causes: automations disabled, Shortcut deleted, no network, phone off

Actions:
- [I’ve done this]

---

### 6) Device Details

Nav title: **Child iPhone**

Header:
- Status badge
- “Last check-in …”

Section: **Policy summary**
- “Hotspot OFF: ON”
- “Quiet hours: 22:00–07:00” (optional)

Section: **Latest run**
- “Action: rotated hotspot password” (if feasible)
- “Result: success/failed”

Section: **Troubleshooting**
- [Child Shortcut not running]
- [Reset enrollment]
- [Remove device]

---

### 7) Device Policy (inside Device Details)

Nav title: **Policy**

Applies to: **this device only**.

Section: **Hotspot**
- Toggle: (ON) **Hotspot OFF**
- Helper: “Shortcut will attempt to turn hotspot off and rotate password.”

Section: **Quiet Time**
- Toggle: (OFF/ON) **In Quiet Time schedule**
- Pickers:
  - Start (time)
  - End (time)
- Timezone: device local (display it)

(Removed: expected frequency)

Action:
- [Save]

---

### 8) Device Activity (inside Device Details)

Nav title: **Activity**

Filter chips:
- All / Errors / Gaps

Timeline rows:
- “15:05 Check-in OK”
- “15:20 Policy fetch OK”
- “15:35 ⚠️ Gap detected”

Row tap → detail:
- request/response summary (redacted)

---

### 9) Settings (tab)

Nav title: **Settings**

Section: Account
- Apple ID (masked)
- [Sign out]

Section: Support
- [Contact]
- [Privacy]

Section: Debug (hidden behind long-press or build flag)
- API base URL
- Admin token
- [Reset local data]

---

## Backend + Child app + Shortcut Hooks (minimum needed)

Even if we keep the backend tiny, the mockups assume:

- `GET /healthz`

Parent:
- `GET /api/devices` (list)
- `GET /api/devices/:id/activity`
- `GET /api/devices/:id/policy`
- `PUT /api/devices/:id/policy` (Hotspot OFF, Quiet Time start/end)

Child app (pairing):
- `POST /api/enroll` (enrollment token → returns deviceId + deviceSecret)

Shortcut (runs on child phone):
- `GET /api/policy?device_id=…` (auth using deviceSecret)
- `POST /api/checkins` (device_id, timestamp, actions attempted, results)

Security:
- Enrollment token is **time-limited** and exchanged for a long-lived `deviceSecret`.
- Shortcut requests authenticated using `deviceSecret` (Bearer or HMAC).

Config file:
- Child app generates **`hotspot-config.json`** containing (at minimum):
  - `deviceId`
  - `deviceSecret`
  - `apiBaseURL`
- Child app exports it to **Files → On My iPhone → Shortcuts** so the Shortcut can read it.

---

## Build Plan (planning-first)

1) Lock these mockups + copy.
2) Lock API contract + minimal DB schema.
3) Implement iOS UI to match mockups (no more incremental UI churn).
4) Implement backend endpoints.
5) Implement Shortcut template + setup guide.
6) End-to-end TestFlight build.

---

## Open questions (need Leon decisions)

Resolved:
1) Enforcement mode: **Shortcut-only**.
2) Shortcut actions: **turn hotspot off + rotate password**.
3) Devices: **multiple devices supported**.

Remaining:
- None (cadence/expected frequency removed; we’ll just show last check-in and a simple “stale” warning).

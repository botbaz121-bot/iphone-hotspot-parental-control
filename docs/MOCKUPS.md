# SpotCheck — Mockups (v0.3)

This document is **planning-first**: screens, flows, copy, and required backend/Shortcut hooks.

> Constraint reminder: iOS apps cannot reliably toggle Personal Hotspot via public APIs. Enforcement is via **Shortcuts automations** (deterrence + audit). This app is the **parent/admin UI**.

---

## Information Architecture

This is a **two-mode** app installed on **both phones** (the parent sets up both):
- **Parent mode** (admin UI)
- **Setup Child Device mode** (pairing + config file generator for the Shortcut)

On first launch (or in Settings), choose a mode:
- [Parent phone]
- [Child phone]

### Parent mode (signed-in)
Bottom tabs:
- **Home** (returns to root welcome)
- **Dashboard**
- **Settings**

### Child phone mode
Flow:
- **Welcome (instructions)** → **Dashboard** (checklist-style progress) → **Settings** (pairing + mode)

Bottom tabs:
- **Home** (returns to root welcome)
- **Dashboard**
- **Settings**


---

## Key Entities (mental model)

- **Account** (parent)
- **Family** (optional; can be single-parent account)
- **Device** (child phone; enrolled via QR/token)
- **Policy** (what we want enforced)
- **Signals** (high-level tamper signals: “last seen”, stale, missing activity)

---

## Core Flows

### Flow A — Parent first run
1) Onboarding (what it does / what it cannot do)
2) Choose mode: **Parent**
3) Sign in with Apple
4) Add first device (Enrollment QR)
5) Policy defaults per device: **Hotspot OFF = ON**, Quiet Time optional
6) Setup guide for child device (install Child app + Shortcut)

### Flow B — Child phone first run (parent holding the child phone)
1) Welcome (instructions)
2) Ensure mode is **Child phone**
3) Pair device (scan QR / enter code)
4) Store config securely in the app (deviceId/deviceSecret/apiBaseURL)
5) Install the Shortcut + add **App Intent** step (“Get Hotspot Config”)
6) Create/enable automations
7) **Lock down Shortcuts/Settings with Screen Time** (in-app Screen Time permission + parent sets Screen Time passcode)
8) (Fallback) Export `hotspot-config.json` to Files if App Intent is blocked

### Flow C — Add a device (Shortcuts-only)
1) Parent generates **Enrollment QR** (contains enrollment token)
2) On child iPhone: install **Child app** + install Shortcut
3) In **Child app**: scan QR → pair with backend → receive device credentials
4) Setup flow stores device credentials securely in the app (deviceId/deviceSecret/apiBaseURL)
5) Shortcut calls an **App Intent** to retrieve config at runtime (no Files step needed)
6) Shortcut uses that config to:
   - authenticate to backend
   - fetch policy
   - post activity
   - perform actions (turn hotspot off + rotate password)
6) Parent sees device status + last seen

### Flow C — Ongoing
- Shortcut automation runs (battery/time-of-day) → fetches policy → attempts actions (turn off hotspot + rotate password)
- Parent app shows **last seen** and warns if the device is likely tampered (stale / missing activity)

---

## Screen Mockups (text wireframes)

Notation:
- `[button]` tappable action
- `(field)` input
- `⚠️` warning

### 0) Onboarding

**Welcome to SpotCheck**
- Subtitle: “Shortcuts-only hotspot control + visibility.”

Mode selection:
- [Parent phone]
- [Set up child phone]

Cards:
- **What this can do**
  - “Set ‘Hotspot OFF’ policy”
  - “Guide setup on child phone”
  - “Warn if the child may have disabled the Shortcut/automations (tamper warning)”
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
- Last tile in the carousel is a big CTA: **[Enroll device]** (scroll right to reveal)

Per-device content shows:

Section: **Device rules**
- “Hotspot OFF: ON/OFF” (per device)
- “Quiet Time: ON/OFF” (per device)
  - If ON: show “22:00–07:00”

Section: **Device status**
- “Last seen: 12 min ago”
- If stale: `⚠️ Device may be tampered (no recent activity for 2h 10m)`

Section: **Recent activity**
- Timeline list

Section: **Troubleshooting**
- [Shortcut not running]
- [Remove device]

---

### 3) Enroll Device — Enrollment QR

Nav title: **Enroll Device**

Card: **Enrollment token**
- Monospace token
- [Copy]  [Regenerate]

Card: **QR**
- QR image

Card: **Next on the child phone**
1. “Install the app on the child phone”
2. “Open app → Set up child phone → Pair device → Scan this QR”
3. “Install the Shortcut” [Open Shortcut link]
4. “In Shortcut: add action ‘Get Hotspot Config’ (App Intent) as the first step”
5. “Enable automations” [Setup Automations]

Footer:
- “This QR links the child device to your account. The Shortcut reads config from the app via App Intent.”

---

### 5) Child Phone Setup Checklist (guide)

Nav title: **Child phone setup**

This screen is shown in **Set up child phone** mode and is the single place that ties everything together.

Step list:
- Step 1: Pair device
  - Scan QR / enter code
  - Confirm: “Paired ✅”

- Step 2: Shortcut
  - Install the Shortcut [Open Shortcut link]
  - Ensure the Shortcut starts with: **Get Hotspot Config** (App Intent)

- Step 3: Automations
  - Create/enable automations (battery + time-of-day)
  - Note: “iOS may prompt; set ‘Ask Before Running’ off if available.”

- Step 4: Screen Time lock (important)
  - Goal: make it hard for the child to disable/modify the Shortcut/automations.

  **In-app Screen Time integration (preferred):**
  - Request Screen Time authorization (FamilyControls)
  - Parent selects apps to restrict (recommended: **Settings + Shortcuts**)
  - Apply shielding via ManagedSettings

  **Also required:** parent sets a **Screen Time passcode** on the child phone
  - We can’t set this passcode; we must remind + verify.
  - Show a checklist gate: “Screen Time passcode set ✅ / Not yet”

  **Fallback (manual):** show the exact Settings path to enable Screen Time + passcode + Content & Privacy restrictions.

Actions:
- [Done]

---

### 6) Device Details

Nav title: **Child iPhone**

Header:
- Status badge
- “Last seen …”

Section: **Policy summary**
- “Hotspot OFF: ON”
- “Quiet hours: 22:00–07:00” (optional)

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
- “15:05 Activity OK”
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

Config (preferred):
- Setup flow stores config securely in the app (Keychain recommended), containing (at minimum):
  - `deviceId`
  - `deviceSecret`
  - `apiBaseURL`
- Shortcut retrieves it via an **App Intent** (e.g. “Get Hotspot Config”) each run.

Config file (fallback):
- Offer an export button to save **`hotspot-config.json`** to Files if App Intent is blocked by iOS automation prompts.

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
- None (we’ll just show last seen and a simple “device may be tampered” warning).

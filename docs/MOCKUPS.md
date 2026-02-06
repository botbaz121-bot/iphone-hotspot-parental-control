# Hotspot Parent — Mockups (v0.2)

This document is **planning-first**: screens, flows, copy, and required backend/Shortcut hooks.

> Constraint reminder: iOS apps cannot reliably toggle Personal Hotspot via public APIs. Enforcement is via **Shortcuts automations** (deterrence + audit). This app is the **parent/admin UI**.

---

## Information Architecture

Bottom tabs (signed-in):
- **Dashboard**
- **Devices**
- **Policy**
- **Activity**
- **Settings**

Pre-auth flow:
- Onboarding → Sign in → Create family (optional) → Add first device

---

## Key Entities (mental model)

- **Account** (parent)
- **Family** (optional; can be single-parent account)
- **Device** (child phone; enrolled via QR/token)
- **Policy** (what we want enforced)
- **Check-ins** (child-side Shortcut/app events proving coverage)

---

## Core Flows

### Flow A — First run
1) Onboarding (what it does / what it cannot do)
2) Sign in with Apple
3) Add first device (Enrollment QR)
4) Policy defaults: **Hotspot OFF = ON**
5) Setup guide for child device

### Flow B — Add a device (Shortcut mode)
1) Parent generates **Enrollment QR**
2) On child iPhone: install Shortcut from link
3) Child runs Shortcut once → enters/scans token → posts to backend → device shows as **Enrolled**
4) Parent sees device status + last check-in

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
- Subtitle: “Prevent hotspot use (via Shortcuts) + get visibility.”

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

Section: **Status**
- “Hotspot OFF policy: ON/OFF”
- “Devices: 1 enrolled / 1 needs setup”

Section: **Coverage**
- “Last check-in: 12 min ago”
- “Expected cadence: every 15 min”
- If gap: `⚠️ No check-in for 2h 10m`

Section: **Quick actions**
- [Add Device]
- [View Setup Guide]

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
1. “Install the Shortcut” [Open Shortcut link]
2. “Run it once and scan/enter this token”
3. “Enable automations” [Setup Automations]

Footer:
- “This token links the child’s check-ins to your account.”

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
  - In iOS this is done via **Screen Time** (not by our app directly).

  **Recommended Screen Time lock-down checklist:**
  1. Settings → Screen Time → Turn on Screen Time (parent sets a Screen Time passcode)
  2. Screen Time → **Content & Privacy Restrictions** → ON
  3. Screen Time → Content & Privacy Restrictions → **Account Changes** → “Don’t Allow”
  4. Screen Time → Content & Privacy Restrictions → **Passcode Changes** → “Don’t Allow”
  5. Screen Time → **App Limits / Downtime** (optional) to limit access to Settings/Shortcuts at night
  6. Screen Time → **Always Allowed**: keep Phone/Messages allowed (your choice)

  **Shortcut-specific guidance (best-effort):**
  - Ask the parent to keep the **Shortcuts app** accessible (it needs to exist), but restrict the child’s ability to edit.
  - Provide a quick “Audit” page in our app:
    - “Last check-in …”
    - “Gap detected …”
    - “Likely causes: automations disabled, Shortcut deleted, no network, phone off.”

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

### 7) Policy (tab)

Nav title: **Policy**

Section: **Hotspot**
- Toggle: (ON) **Enforce Hotspot OFF**
- Description: “In Shortcut mode, enforcement means rotating/changing credentials and logging attempts.”

Section: **Schedule (v1)**
- Toggle: Enable schedule
- Quiet hours picker: Start/End
- Timezone: device local

Section: **Cadence**
- Picker: Expected check-in interval (15m/30m/60m)

Action:
- [Save]

---

### 8) Activity (tab)

Nav title: **Activity**

Filter chips:
- All / This device / Errors / Gaps

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

## Backend + Shortcut Hooks (minimum needed)

Even if we keep the backend tiny, the mockups assume:

- `GET /healthz`
- `POST /api/enroll` (token → device record)
- `GET /api/policy?device_id=…` (or token-based)
- `POST /api/checkins` (device_id, timestamp, actions attempted, results)
- `GET /api/devices` (parent)
- `GET /api/devices/:id/activity`

Security:
- Enrollment token is **time-limited** and exchanged for a long-lived device secret.
- Shortcut requests signed with device secret (HMAC) or sent as Bearer.

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
4) **Expected check-in cadence** is *parent-defined* (based on the automations they create). In-app we will:
   - store an optional **Expected frequency** per device (15m / 30m / 60m / custom / Not sure)
   - if unset: show last check-in but **no gap alerts**
   - if set: show **gap warnings** when last check-in exceeds a threshold (e.g., 2× expected frequency)

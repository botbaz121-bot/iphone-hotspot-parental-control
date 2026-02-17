# PRD: iPhone Parental Control — Disable Personal Hotspot

## Summary
Build an iPhone product that enables a parent/guardian to prevent a child’s iPhone from using **Personal Hotspot** (and ideally tethering via Wi‑Fi/Bluetooth/USB), with clear status visibility, auditability, and predictable enforcement.

**Reality check (important):** iOS does **not** generally allow third‑party apps to toggle or restrict system features like Personal Hotspot through public APIs. The viable path is likely:
- **MDM / configuration profiles** (often requiring the device to be **supervised**) to enforce restrictions, or
- using **Screen Time / Family Sharing** if Apple exposes an equivalent control (uncertain).

This PRD therefore includes a **feasibility spike** as a first milestone.

---

## Problem
Children can enable Personal Hotspot and share cellular data (or bypass Wi‑Fi limits), which can:
- bypass parental controls/network filters,
- create unexpected data costs,
- allow access when a parent intends the phone to be “online only on approved Wi‑Fi”.

Parents want a reliable “off switch” (or schedule) for Hotspot on the child device.

---

## Goals
1. Parent can **disable** hotspot on child’s device (enforced, not just advisory).
2. Parent can see **current enforcement status** (hotspot allowed/blocked).
3. Parent can define simple rules: **Always off** (MVP) and optionally **schedule** (v1).
4. Product has clear setup steps and communicates constraints (supervision/MDM if required).

## Non-goals (initial)
- Building a full parental controls suite (content filtering, app limits, location tracking) beyond what’s needed.
- Jailbreak-based solutions.
- Android support.

---

## Personas
- **Parent/Guardian (Admin):** wants control + peace of mind, not technical setup.
- **Child (Managed Device User):** uses the iPhone; may attempt to bypass restrictions.

---

## Key User Stories
1. **Setup:** As a parent, I can enroll my child’s iPhone so the app can enforce restrictions.
2. **Disable hotspot:** As a parent, I can set “Hotspot OFF” and it actually stays off.
3. **Verify status:** As a parent, I can confirm the device is compliant.
4. **Audit:** As a parent, I can see when hotspot was attempted/blocked (if feasible).
5. **Recovery:** As a parent, I can remove management safely (unenroll) if needed.

---

## Requirements

### Functional Requirements (MVP)
- Parent-facing UI (iPhone app) with:
  - Family/device enrollment (generate a **token** used by the installed Shortcut)
  - Policy controls (for the Shortcut to fetch):
    - enable/disable enforcement
    - allowed hours / quiet hours
    - rotation frequency strategy (via triggers)
  - Dashboard:
    - timeline of Shortcut runs ("enforcement executed")
    - gaps (expected run did not report)
  - Setup guide:
    - install prebuilt Shortcut via iCloud link
    - create battery + time-of-day automations
    - optional Screen Time lock-down instructions

- Child-side execution is primarily via **Shortcuts**, not background app code.

- Admin controls:
  - Authentication (Sign in with Apple recommended)
  - Basic role model: parent = admin

### Non-functional Requirements
- Privacy-first: collect minimal data; no content inspection.
- Security:
  - Encrypted at rest and in transit
  - Device enrollment tokens/time-limited QR codes
- Reliability:
  - Clear “last seen” timestamp
  - Graceful degradation when device offline

---

## UX / Flows

### 1) Parent Onboarding
1. Install parent app.
2. Create account / sign in.
3. Add a child device.
4. Choose enforcement mode:
   - **Mitigation mode (consumer iOS)**: relies on Shortcuts *automations* as the reliable scheduler.
   - **Strict mode (MDM / supervised)**: optional later.

### 2) Mitigation mode — Scheduling checks with multiple automations
iOS does not provide a guaranteed “run my app every N minutes” background scheduler.

So the reliable approach is to have the parent set up **multiple Time of Day personal automations** to achieve coverage.

Example: to guarantee checks every **15 minutes** over a **2-hour window**, the parent sets up **9 separate automations** (T0, T+15, …, T+120).

The product should:
- provide a **wizard** that generates the list of times based on a desired window + interval,
- provide step-by-step instructions to create each automation,
- provide a “checklist” UX so users don’t lose their place,
- verify setup by requiring each automation to call a test endpoint once.

### 3) Strict mode (future)
If we later support MDM, this becomes optional and can replace the automation setup.

### 2) Device Enrollment (likely MDM)
- Parent app generates enrollment QR/code.
- Child iPhone installs a management profile.
- Server registers device, begins compliance checks.

### 3) Control Hotspot
- Parent toggles “Block Hotspot”.
- Server pushes updated configuration/restriction.
- Parent sees status update:
  - “Applied” with timestamp
  - If not applied, surface reason (offline, not supervised, enrollment incomplete).

---

## Technical Approach (Options)

We should treat this as a **constraints-first iOS problem**: if Apple doesn’t expose a supported way to disable/tweak Hotspot, we need “effective enough” mitigations that don’t require deep device management.

### Option A — MDM (Most Likely for true enforcement)
**How it works:** run an MDM server, enroll the child device, apply a Restrictions payload that disallows Personal Hotspot.

- Pros: enforcement is system-level.
- Cons:
  - May require **Supervised** mode for certain restrictions.
  - Needs Apple push certificates, MDM infra, and careful compliance/security.
  - App Store positioning/approval risks depending on functionality and claims.

### Option B — “Mitigation mode” (consumer iOS; Shortcuts as the enforcement engine)
Instead of trying to get system-level control from our app (unlikely), we treat **Shortcuts automations** as the reliable scheduler + privileged action runner.

**Core pattern:**
1) Parent installs a **prebuilt Shortcut** (distributed via iCloud link, launched from within our app).
2) The Shortcut calls our backend (`Get Contents of URL`) to fetch the current policy ("enforce now?", "rotate password?", quiet hours, etc.).
3) The Shortcut enforces:
   - **Turn Personal Hotspot OFF**
   - **Change Hotspot password** (to break ongoing usage and make sharing impractical)
4) The Shortcut posts an event back to our backend for dashboards/audit.

**Triggers:**
- **Battery level changes** (high-frequency, good for catching “they just started using it”) — parent needs to create these automations.
- **Time of day** coverage automations (multiple individual times) to catch “fully charged + plugged in” cases.

**What the app adds:**
- Onboarding wizard that generates the set of automations + provides a checklist.
- A parent dashboard: history of enforcement runs, gaps, and patterns.
- Optional guidance to lock down the Shortcuts app via Screen Time.

#### Shortcut protocol (v1)
We need a tiny, reliable API that Shortcuts can call (via **Get Contents of URL**) with minimal dependencies.

**Auth / device identity**
- Each child device has a `deviceToken` (opaque random string) provisioned by the parent app.
- Requests are authenticated using an HMAC signature derived from a per-device shared secret.
  - Header: `X-Device-Token: <deviceToken>`
  - Header: `X-TS: <unix_ms>`
  - Header: `X-Signature: <hex(hmac_sha256(deviceSecret, ts + "\n" + method + "\n" + path + "\n" + body))>`
- Server enforces clock skew window (e.g. ±5 minutes) to limit replay.

**Endpoints**
1) `GET /policy`
- Purpose: tell the Shortcut what to do *right now*.
- Response (example):
```json
{
  "enforce": true,
  "actions": {
    "setHotspotOff": true,
    "rotatePassword": true
  },
  "quietHours": { "start": "21:00", "end": "07:00", "tz": "Europe/Paris" },
  "note": "optional debug string"
}
```

2) `POST /events`
- Purpose: append telemetry for dashboards/audit.
- Body (example):
```json
{
  "ts": 1738570000000,
  "trigger": "time_of_day",
  "shortcutVersion": "1.0",
  "actionsAttempted": ["setHotspotOff", "rotatePassword"],
  "result": {
    "ok": true,
    "errors": []
  }
}
```

**Idempotency**
- Shortcut may retry. We can accept duplicates by treating events as append-only, or add `eventId`.

Feasibility checklist: see `/docs/iphone-hotspot-parental-control/FEASIBILITY.md`.

2) **Detect + notify** (instead of block)
- Concept: if we can detect hotspot activation/usage, we can alert the parent immediately and/or ask for confirmation.
- Reality check: detecting hotspot usage from a sandboxed iOS app may not be possible without MDM-level telemetry.

3) **Carrier-level tethering disable** (often simplest)
- Many carriers can disable tethering on the plan/account.
- Pros: strong enforcement without device management.
- Cons: carrier-specific; may require parent to change plan; not always available.

4) **Configuration profile for APN / cellular settings** (possible middle-ground)
- Some carriers use a separate tethering APN; changing APN settings can break tethering.
- Reality check: would likely require a profile/MDM-like installation, and may be fragile/carrier-specific.

### Option C — Screen Time / FamilyControls APIs (Uncertain)
**How it works:** use Apple’s FamilyControls / ManagedSettings frameworks.

- Pros: more “consumer-friendly” if possible.
- Cons: these frameworks generally manage **apps and web domains**, not core system toggles like hotspot.

**Decision:** Start with a **feasibility spike** that explicitly tests:
- Can we truly **block** hotspot without full MDM/supervision?
- If not, can we implement an **effective mitigation** (password rotation, APN trick, carrier block) that’s good enough for parents?
- App Store review implications for each approach.

---

## Data Model (MVP)
- User
- Family / Household
- Device (child iPhone)
  - identifiers (MDM-managed IDs; avoid storing unnecessary PII)
  - last_seen
  - compliance_state
- Policy
  - hotspot_blocked: boolean
  - updated_at

---

## Compliance, Privacy, and Legal
- Clearly disclose that the product manages device settings.
- Minimal data collection; no message/content access.
- For child-focused products, review COPPA/GDPR-K implications; likely require:
  - parental consent flows
  - data deletion requests

---

## Metrics
- Activation rate: enrolled devices / parent installs
- Time-to-enroll (median)
- Compliance rate (% devices in compliant state)
- “Hotspot blocked” success rate and failures by reason

---

## Milestones
1. **Feasibility Spike (1–2 weeks)**
   - Confirm technical feasibility to restrict Personal Hotspot via Apple-supported mechanism.
   - Identify requirements: supervised device? iOS versions? restrictions payload key(s)?
   - Draft App Store review risk assessment.
2. **MVP Build (4–8 weeks)**
   - Parent app basic UI + auth
   - MDM server skeleton + enrollment
   - Apply/verify hotspot policy
3. **Beta (2–4 weeks)**
   - Setup UX improvements
   - Observability + support docs

---

## Risks / Open Questions
- Is there a supported restriction to disable Personal Hotspot, and does it require supervision?
- Can this be distributed via App Store without being rejected as “MDM/enterprise-only” tooling?
- Bypass vectors (USB tethering, device resets, profile removal).
- Setup friction: supervising a device is non-trivial for typical families.

---

## Out of Scope (Explicit)
- Location tracking
- Message monitoring
- Keylogging
- VPN/content filtering

---

## Next Step
Complete the feasibility checklist in `/docs/iphone-hotspot-parental-control/FEASIBILITY.md` (especially Shortcuts-based password rotation). Then we can lock the MVP approach and convert requirements into an implementation plan.

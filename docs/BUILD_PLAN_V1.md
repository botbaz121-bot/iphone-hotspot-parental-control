# Build plan (v1)

**Target:** iOS 16+

**Pairing:** manual pairing code entry (fastest for v1)

## What “v1 scope” means

It’s the boundary for what the first usable release includes, vs what we explicitly defer.

### Option A — v1 scope = Setup + Status only (recommended)
The iOS app:
- pairs/enrolls the device
- installs/links the Shortcut
- guides creating automations (battery + time-of-day)
- locks Shortcuts via FamilyControls/ManagedSettings (fallback: manual Screen Time instructions)
- shows current status (last seen, gap, quiet hours, enforce flag)

**But does NOT** edit policy (quiet hours/enforce/gap) directly.
Policy edits happen in the local webadmin for now.

Pros: simplest + safest; no need to ship admin credentials or invent parent-auth yet.

### Option B — v1 scope = Setup + Status + Edit policy
Everything in Option A, plus the iOS app can:
- toggle `enforce`
- set quiet hours
- set gap threshold

This requires a secure model for “parent writes policy” that is NOT the backend `ADMIN_TOKEN`.
Common approach: parent login / OAuth, or per-device parent-write token created during pairing.

Pros: less dependence on webadmin.
Cons: more security surface and work.

## Architecture (locked)
- Backend is **source of truth** for policy + telemetry.
- Enforcement runs on-device via Shortcuts:
  - `GET /policy` (HMAC)
  - `POST /events` (HMAC)
- Quiet-hours comparison uses **device timezone**.

## Proposed app screens (v1)
1) Welcome
2) Pair device (enter pairing code)
3) Install Shortcut (iCloud link + confirm constants)
4) Automations checklist
5) Lock Shortcuts (FamilyControls/ManagedSettings)
6) Status / Test connection

## Next concrete steps
1) Decide v1 scope: Option A or B.
2) Implement pairing code endpoint on backend (if not already).
3) Create iOS project skeleton (SwiftUI) (will need macOS/Xcode to actually run/build).

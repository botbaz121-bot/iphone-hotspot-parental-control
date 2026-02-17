# Feasibility Notes — iPhone Hotspot Parental Control

## Claim to validate
> “Apple Shortcuts can change the Personal Hotspot password.”

If true, we may be able to achieve an **effective lock-out** strategy by rotating the password periodically.

---

## What we need to learn (in order)

### 1) Can Shortcuts reliably change the Hotspot password?
- iOS version(s) where it works
- Does it require Personal Hotspot to be enabled first?
- Does it change the Wi‑Fi password only, or also affect Bluetooth/USB tethering?
- Does it apply immediately to active connections (kicks devices off)?

**Pass criteria:** a Shortcut action exists that changes the hotspot password and takes effect without manual navigation in Settings.

### 2) Can we achieve a reliable cadence (without a real scheduler)?
Shortcuts automations are the only reliable user-accessible scheduler, but **Time of Day** doesn’t give “every N minutes” as a single automation.

Workaround: create **many individual Time of Day automations** (one per time slot).

Test:
- Confirm the minimum practical interval (e.g., 15 minutes) given UX friction.
- Confirm each automation can run with **Ask Before Running = Off** (when available).
- Confirm iOS doesn’t throttle/disable repeated automations across a window.

**Pass criteria:** we can achieve (and users will tolerate) something like “every 15 minutes for 2 hours” by creating multiple automations, and they run reliably without interaction.

### 3) Can we distribute and bind a prebuilt Shortcut to a specific family?
Apps can’t programmatically create automations, but we can:
- distribute a **prebuilt Shortcut** via an iCloud link opened from our app,
- ask the parent to create the needed automations (battery/time-of-day),
- and bind the Shortcut’s executions to a specific family/device.

Binding options to validate:
- **App Intents / App Shortcuts**: have the Shortcut call into our app to retrieve a user/device token.
- A one-time **enrollment code** the parent copies into the Shortcut as a variable.

**Pass criteria:** onboarding UX exists where the Shortcut can reliably identify the correct user/device when posting to our server.

### 4) Security / bypass model
- Child can disable the automation, delete the Shortcut, or re-share the new password.
- The Shortcut also calls our server for policy; the child may try to:
  - block network access, or
  - forge requests.

Mitigations to validate:
- Use Screen Time to restrict Shortcuts edits (see section C).
- Sign requests from the Shortcut (shared secret token) to prevent easy forgery.
- Treat missing events as a first-class signal ("coverage gap").

**Pass criteria:** the bypass cost is high enough for target parents, or we reframe as “deterrence + audit trail”.

---

## Likely product implication
If the above checks pass:
- MVP becomes **Shortcut-based mitigation mode** (low infra, no MDM)
- MDM becomes “Pro / strict enforcement” only if needed

---

## Next experiments (quick)

### A) Shortcuts enforcement engine (policy check + actions)
1) Confirm Shortcuts actions exist and work:
   - turn hotspot off (or toggle → verify we can reach a known OFF state)
   - change hotspot password
2) Confirm a Shortcut can call our server:
   - `Get Contents of URL` → GET policy with a stable device/user identifier
   - `Get Contents of URL` → POST an execution event (timestamp, action results)
3) Confirm trigger strategy works in practice:
   - **Battery level** automation triggers are available and can run without user interaction (as much as iOS allows)
   - Time-of-day automations (many individual times) for coverage
4) Confirm password change drops active tethering sessions.
5) Confirm locked-phone behavior (we’re avoiding UI/screenshot probes; still verify automations run as expected when locked).

### B) App-side heuristic feasibility: can we see `bridge100`?
Goal: validate whether a normal sandboxed iOS app can observe the `bridge100` interface (or any hotspot-related interface) using `getifaddrs()`.

Build a tiny spike app that logs interface names + flags + IPs and records whether `bridge100` exists.

Test matrix:
- Hotspot OFF
- Hotspot ON (no clients)
- Hotspot ON (Wi‑Fi client connected)
- Hotspot ON (USB client connected, if possible)
- Hotspot ON (Bluetooth client connected, if possible)

Pass criteria:
- `bridge100` (or another consistent hotspot-only interface) is observable in app logs for at least one ON state, and ideally differentiates ON vs OFF.

Fail criteria:
- No hotspot-specific interface is observable from the app, or it’s too inconsistent to be useful.

### C) Screen Time lock-down: can we block Shortcuts edits while still running automations?
Goal: reduce child bypass by using **Screen Time** to restrict the Shortcuts app, while keeping the scheduled automations working.

✅ Leon test result: setting a **Screen Time app limit** on the Shortcuts app prevented opening Shortcuts, but **automations still ran**.

Test matrix:
1) Configure the monitoring automations (battery/time-of-day) and confirm they post events successfully.
2) Enable Screen Time restrictions that block or limit Shortcuts (as an app) on the child device (app limit / downtime / app restrictions).
3) Verify:
   - Can the child still open Shortcuts? (should be blocked)
   - Can the child edit/delete automations? (should be blocked/harder)
   - Do existing automations still run on schedule and successfully post events?

Pass criteria:
- Shortcuts is effectively blocked for the child, and existing automations still run and post.

Fail criteria:
- Blocking Shortcuts also stops automations from running, or doesn’t meaningfully prevent edits.

### D) Anti-bypass: Settings-open redirect automation
Idea: since changing the hotspot password pushes the child to open Settings to read the new password, create a Personal Automation:
- Trigger: **App** → When **Settings** is opened
- Action: **Open App** → redirect to another app (e.g., our app)

This can make it hard to view the hotspot password.

What to validate:
- Can this automation run with **Ask Before Running = Off**?
- Does it work consistently (immediate redirect) and with the phone locked/unlocked?
- Does it block *all* ways of seeing the password (e.g., hotspot settings page, shared sheet, system prompts), or only Settings app UI?
- UX: does breaking Settings create unacceptable side effects (Settings is needed for legitimate use)?

Pass criteria:
- Parent can reliably prevent the child from opening Settings long enough to read/copy the hotspot password, without constant prompts.

Fail criteria:
- Requires confirmation, is inconsistent, or is too disruptive / easy to bypass.

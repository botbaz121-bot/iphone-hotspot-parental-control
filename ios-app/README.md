# iOS App (WIP)

Target: iOS 16+

This folder will contain the native iOS app (SwiftUI) for the iPhone Hotspot Parental Control project.

## v1 assumptions
- Setup is performed on the **child phone** (parent holding the device).
- Pairing is via **manual pairing code**.
- Enforcement is run by **Shortcuts automations** (poll `/policy`, post `/events`).
- App can lock **Shortcuts** using FamilyControls/ManagedSettings.

## Status
This repo is being prepared on Linux.
To create the Xcode project and run/build, we’ll need a macOS machine with recent Xcode (Catalina won’t work).

See: `../docs/BUILD_PLAN_V1.md`

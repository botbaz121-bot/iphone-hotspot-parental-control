# SpotCheck UI mock ↔ iOS mapping

Source of truth mock screenshots (captured from `prototype-web`):
- `prototype_screens/crawl-2026-02-12/`

## Screen map

### 00-root (/#/)
- Mock: `prototype_screens/crawl-2026-02-12/00-root.png`
- iOS: `Views/LandingView.swift`
- Entry: `Views/RootView.swift` (when `appMode == nil`)

### 01-parent-onboarding (/#/parent/onboarding)
- Mock: `prototype_screens/crawl-2026-02-12/01-parent-onboarding.png`
- iOS: `Views/Parent/ParentOnboardingView.swift`
- Entry: `RootView` when `appMode == .parent && onboardingCompleted == false`

### 02-parent-dashboard (/#/parent/dashboard)
- Mock: `prototype_screens/crawl-2026-02-12/02-parent-dashboard.png`
- iOS: `Views/Parent/ParentDashboardView.swift`

### 03-parent-settings (/#/parent/settings)
- Mock: `prototype_screens/crawl-2026-02-12/03-parent-settings.png`
- iOS: `Views/Parent/ParentSettingsView.swift`

### 04-child-onboarding (/#/child/onboarding)
- Mock: `prototype_screens/crawl-2026-02-12/04-child-onboarding.png`
- iOS: `Views/Child/ChildWelcomeView.swift`

### 05-child-dashboard (/#/child/dashboard)
- Mock: `prototype_screens/crawl-2026-02-12/05-child-dashboard.png`
- iOS: `Views/Child/ChildDashboardView.swift`

### 06-child-settings (/#/child/settings)
- Mock: `prototype_screens/crawl-2026-02-12/06-child-settings.png`
- iOS: `Views/Child/ChildSettingsView.swift`

### 07-child-locked (/#/child/locked)
- Mock: `prototype_screens/crawl-2026-02-12/07-child-locked.png`
- iOS: `Views/Child/ChildLockedView.swift`

### 08-child-unlock (/#/child/unlock)
- Mock: `prototype_screens/crawl-2026-02-12/08-child-unlock.png`
- iOS: `Views/Child/ChildUnlockView.swift`

## Notes
- iOS design is intentionally native SwiftUI (materials, spacing, SF Symbols), so it will not be pixel-perfect.
- The goal is consistent **screen flow** + **information hierarchy**.

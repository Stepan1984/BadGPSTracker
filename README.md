# BadGPSTracker

iOS (SwiftUI) MVP for stable run tracking when GPS is weak, jammed, or spoofed. Location, step odometry, and a light fusion engine feed a MapKit live map and in-app post-run review. **GPX/FIT export is out of v1.**

## Open in Xcode (Mac)

1. Clone this repo and open **`BadGPSTracker.xcodeproj`** in Xcode 15+ (iOS 17 SDK).
2. Select the **BadGPSTracker** shared scheme and an iPhone simulator or a physical device.
3. Set your **Signing & Capabilities → Team** (bundle id defaults to `com.stepan1984.BadGPSTracker`; change if needed).
4. Build & Run (⌘R).

### Device vs simulator

| | Simulator | Physical iPhone |
|---|---|---|
| Core Location | Use **Features → Location** to simulate a path | Real GPS |
| Core Motion / pedometer | Limited / often unavailable | Required for DR/pedometer mode |
| Background location | Not representative | Grant **Always** for fitness background |

On first launch: **Start** → **Request Access** (Location + Motion) → **Start Run**. Use **Live** for the map, **Stop** to finish, **Post-run** to review the smoothed track (orange = lower internal confidence segments).

## Architecture (modules)

Matches `docs/ios-architecture.md` in the project workspace:

| Module | Role |
|---|---|
| **UI** | Start / Live / Post-run |
| **Session** | Run lifecycle; sensors → fusion → map match → persistence |
| **Fusion** | v0: N=**35 m** → DR/pedometer; drop teleport/impossible speed; soft blend on GPS recovery; internal confidence |
| **Sensors** | Core Location (`fitness`), Core Motion pedometer/IMU, barometer |
| **MapMatching** | MapKit snap stub (throttled) |
| **Persistence** | Local `RunSession` / `TrackPoint` JSON store |
| **Permissions** | Location + motion prompts |

Locked constants live in `BadGPSTracker/Shared/Constants/TrackingConstants.swift` (`accuracyThresholdMeters = 35`).

## Pipeline

```
GPS + IMU/DR + pedometer (+ barometer)
        → Fusion Engine (Kalman stub + rules)
        → MapKit matching stub
        → TrackPoint → Persistence + Live map
```

UI never draws raw GPS as-is.

## Info.plist / background

- Usage strings for **When In Use**, **Always**, and **Motion** (fitness tracking).
- `UIBackgroundModes` → `location` for continuous fitness tracking while a run is active.
- Sensors stop after **Stop**; no export formats in v1.

## Notes

- This repository was scaffolded so the project opens on a Mac; it is **not** compiled in Linux CI/cloud VMs (no `xcodebuild` there).
- Map matching is a **stub** (nearby MapKit search + soft snap). Replace with stronger road/trail matching as the next iteration.
- Confidence is **internal only** — no high/med/low picker in the UI.

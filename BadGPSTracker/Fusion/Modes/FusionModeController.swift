import Foundation

/// Mode transitions driven by locked N = 35m and GPS recovery soft blend.
struct FusionModeController {
    private(set) var mode: FusionMode = .gpsOk
    private var blendStartedAt: Date?

    mutating func reset() {
        mode = .gpsOk
        blendStartedAt = nil
    }

    mutating func evaluate(
        hasFix: Bool,
        accuracyMeters: Double?,
        now: Date = Date()
    ) -> FusionMode {
        let badAccuracy = (accuracyMeters ?? .infinity) > TrackingConstants.accuracyThresholdMeters

        switch mode {
        case .gpsOk:
            if !hasFix || badAccuracy {
                mode = .drPedometer
            }
        case .drPedometer:
            if hasFix, !badAccuracy {
                mode = .recoveringBlend
                blendStartedAt = now
            }
        case .recoveringBlend:
            if !hasFix || badAccuracy {
                mode = .drPedometer
                blendStartedAt = nil
            } else if let started = blendStartedAt,
                      now.timeIntervalSince(started) >= TrackingConstants.softBlendDurationSeconds {
                mode = .gpsOk
                blendStartedAt = nil
            }
        }
        return mode
    }

    /// 0 = fully DR estimate, 1 = fully GPS. Used during recoveringBlend.
    func blendWeight(now: Date = Date()) -> Double {
        guard mode == .recoveringBlend, let started = blendStartedAt else {
            return mode == .gpsOk ? 1 : 0
        }
        let t = now.timeIntervalSince(started) / TrackingConstants.softBlendDurationSeconds
        return min(1, max(0, t))
    }
}

import Foundation

/// Cheap internal confidence heuristics (0…1). Not exposed as UX.
enum ConfidenceEstimator {
    static func estimate(
        mode: FusionMode,
        accuracyMeters: Double,
        hadAnomaly: Bool
    ) -> Double {
        var score: Double
        switch mode {
        case .gpsOk:
            // Better accuracy → higher confidence; clamp around threshold band.
            if accuracyMeters <= 10 {
                score = 0.95
            } else if accuracyMeters <= TrackingConstants.accuracyThresholdMeters {
                score = 0.75
            } else {
                score = 0.45
            }
        case .drPedometer:
            score = 0.55
        case .recoveringBlend:
            score = 0.65
        }
        if hadAnomaly {
            score *= 0.6
        }
        return min(1, max(0, score))
    }
}

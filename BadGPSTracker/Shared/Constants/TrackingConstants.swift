import Foundation

/// Locked product constants — do not expose as user-tunable settings in v1.
enum TrackingConstants {
    /// Accuracy threshold N (meters). GPS accuracy worse than this → DR / pedometer mode.
    static let accuracyThresholdMeters: Double = 35

    /// Max plausible running speed (m/s). Faster jumps are treated as impossible / teleport.
    static let maxPlausibleSpeedMetersPerSecond: Double = 12.5

    /// Soft blend duration when GPS recovers after a DR stretch.
    static let softBlendDurationSeconds: TimeInterval = 8

    /// UI map refresh cadence (Hz). Filter may run faster internally.
    static let uiRefreshHertz: Double = 1.5

    /// Minimum interval between map-matching calls (battery throttle).
    static let mapMatchingMinIntervalSeconds: TimeInterval = 2
}

import Foundation

/// One fused + matched track point (product brief §6).
struct TrackPoint: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var lat: Double
    var lon: Double
    var source: TrackSource
    var accuracy: Double
    /// Internal confidence 0…1 — not a user-facing setting.
    var confidence: Double
    var timestamp: Date
    var altitude: Double?
    var anomalyFlags: [AnomalyKind]

    init(
        id: UUID = UUID(),
        lat: Double,
        lon: Double,
        source: TrackSource,
        accuracy: Double,
        confidence: Double,
        timestamp: Date = Date(),
        altitude: Double? = nil,
        anomalyFlags: [AnomalyKind] = []
    ) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.source = source
        self.accuracy = accuracy
        self.confidence = confidence
        self.timestamp = timestamp
        self.altitude = altitude
        self.anomalyFlags = anomalyFlags
    }
}

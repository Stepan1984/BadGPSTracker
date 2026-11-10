import CoreLocation
import Foundation

enum FusionMode: String, Codable, Sendable {
    case gpsOk
    case drPedometer
    case recoveringBlend
}

/// Internal fusion snapshot for Session / soft UI status (not a confidence picker).
struct FusionState: Sendable {
    var mode: FusionMode
    var estimate: CLLocationCoordinate2D?
    var accuracyMeters: Double
    /// Internal 0…1 signal — never exposed as high/med/low UX.
    var confidence: Double
    var lastUpdate: Date

    static let initial = FusionState(
        mode: .gpsOk,
        estimate: nil,
        accuracyMeters: .infinity,
        confidence: 0,
        lastUpdate: Date()
    )
}

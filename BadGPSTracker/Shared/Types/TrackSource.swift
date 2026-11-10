import Foundation

/// Origin of a fused track point. Stored for post-run review; not a UX picker.
enum TrackSource: String, Codable, Sendable, CaseIterable {
    case gps
    case dr
    case pedometer
    case wifi
    case fused
    case barometer
}

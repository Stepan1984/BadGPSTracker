import CoreLocation
import Foundation

/// Raw sensor measurement before fusion. Usually not persisted.
struct SensorSample: Sendable {
    enum Kind: String, Sendable {
        case location
        case pedometer
        case motion
        case barometer
        case coarseNetwork
    }

    let kind: Kind
    let timestamp: Date
    let coordinate: CLLocationCoordinate2D?
    let horizontalAccuracy: CLLocationAccuracy?
    let altitude: Double?
    let speed: CLLocationSpeed?
    let stepCount: Int?
    let distanceFromPedometer: Double?
    let headingDegrees: Double?

    init(
        kind: Kind,
        timestamp: Date = Date(),
        coordinate: CLLocationCoordinate2D? = nil,
        horizontalAccuracy: CLLocationAccuracy? = nil,
        altitude: Double? = nil,
        speed: CLLocationSpeed? = nil,
        stepCount: Int? = nil,
        distanceFromPedometer: Double? = nil,
        headingDegrees: Double? = nil
    ) {
        self.kind = kind
        self.timestamp = timestamp
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.altitude = altitude
        self.speed = speed
        self.stepCount = stepCount
        self.distanceFromPedometer = distanceFromPedometer
        self.headingDegrees = headingDegrees
    }
}

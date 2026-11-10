import CoreLocation
import Foundation

/// Lightweight 2D position filter stub — battery-conscious, not a heavy particle sim.
struct SimpleKalmanFilter {
    private(set) var lat: Double?
    private(set) var lon: Double?
    private var variance: Double = 100

    mutating func reset() {
        lat = nil
        lon = nil
        variance = 100
    }

    mutating func predict(processNoise: Double = 4) {
        variance += processNoise
    }

    mutating func update(coordinate: CLLocationCoordinate2D, measurementVariance: Double) {
        guard let currentLat = lat, let currentLon = lon else {
            lat = coordinate.latitude
            lon = coordinate.longitude
            variance = measurementVariance
            return
        }

        let k = variance / (variance + max(measurementVariance, 1))
        lat = currentLat + k * (coordinate.latitude - currentLat)
        lon = currentLon + k * (coordinate.longitude - currentLon)
        variance = (1 - k) * variance
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var uncertaintyMeters: Double {
        sqrt(max(variance, 0))
    }
}

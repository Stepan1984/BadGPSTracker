import CoreLocation
import Foundation

/// Core Location wrapper. Streams samples only — no fusion decisions.
@MainActor
final class LocationSensor: NSObject, ObservableObject {
    @Published private(set) var lastSample: SensorSample?
    @Published private(set) var isRunning = false

    var onSample: ((SensorSample) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
        manager.activityType = .fitness
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func start(backgroundEnabled: Bool) {
        manager.activityType = .fitness
        manager.allowsBackgroundLocationUpdates = backgroundEnabled
        manager.startUpdatingLocation()
        isRunning = true
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        isRunning = false
    }
}

extension LocationSensor: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let sample = SensorSample(
            kind: .location,
            timestamp: location.timestamp,
            coordinate: location.coordinate,
            horizontalAccuracy: location.horizontalAccuracy,
            altitude: location.altitude,
            speed: location.speed >= 0 ? location.speed : nil,
            headingDegrees: location.course >= 0 ? location.course : nil
        )
        Task { @MainActor in
            lastSample = sample
            onSample?(sample)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Session / Fusion handle gaps; sensor stays quiet.
        _ = error
    }
}

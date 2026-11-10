import CoreMotion
import Foundation

/// Relative altitude from CMAltimeter for elevation on TrackPoint.
@MainActor
final class BarometerSensor: ObservableObject {
    @Published private(set) var lastAltitudeRelative: Double?
    @Published private(set) var isRunning = false

    var onSample: ((SensorSample) -> Void)?

    private let altimeter = CMAltimeter()

    func start() {
        guard CMAltimeter.isRelativeAltitudeAvailable(), !isRunning else { return }
        isRunning = true
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            let altitude = data.relativeAltitude.doubleValue
            let sample = SensorSample(
                kind: .barometer,
                timestamp: Date(),
                altitude: altitude
            )
            self?.lastAltitudeRelative = altitude
            self?.onSample?(sample)
        }
    }

    func stop() {
        altimeter.stopRelativeAltitudeUpdates()
        isRunning = false
    }
}

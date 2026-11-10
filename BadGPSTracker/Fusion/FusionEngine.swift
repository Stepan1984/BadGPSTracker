import CoreLocation
import Foundation

struct FusionOutput: Sendable {
    let point: TrackPoint?
    let state: FusionState
    let anomalies: [AnomalyEvent]
}

/// Fusion Engine v0: N=35m → DR/pedometer; drop teleport/impossible speed; soft blend on GPS recovery.
@MainActor
final class FusionEngine {
    private var filter = SimpleKalmanFilter()
    private var modeController = FusionModeController()
    private var lastAcceptedCoordinate: CLLocationCoordinate2D?
    private var lastAcceptedTimestamp: Date?
    private var lastHeadingDegrees: Double?
    private var lastPedometerDistance: Double?
    private var lastRelativeAltitude: Double?
    private var drEstimate: CLLocationCoordinate2D?

    func reset() {
        filter.reset()
        modeController.reset()
        lastAcceptedCoordinate = nil
        lastAcceptedTimestamp = nil
        lastHeadingDegrees = nil
        lastPedometerDistance = nil
        lastRelativeAltitude = nil
        drEstimate = nil
    }

    func ingest(_ sample: SensorSample) -> FusionOutput {
        var anomalies: [AnomalyEvent] = []

        switch sample.kind {
        case .motion:
            lastHeadingDegrees = sample.headingDegrees
            return FusionOutput(point: nil, state: currentState(), anomalies: [])
        case .barometer:
            lastRelativeAltitude = sample.altitude
            return FusionOutput(point: nil, state: currentState(), anomalies: [])
        case .pedometer:
            return handlePedometer(sample, anomalies: &anomalies)
        case .location, .coarseNetwork:
            return handleLocation(sample, anomalies: &anomalies)
        }
    }

    private func handlePedometer(_ sample: SensorSample, anomalies: inout [AnomalyEvent]) -> FusionOutput {
        defer { lastPedometerDistance = sample.distanceFromPedometer }

        let mode = modeController.evaluate(
            hasFix: false,
            accuracyMeters: nil,
            now: sample.timestamp
        )

        guard mode == .drPedometer || mode == .recoveringBlend else {
            return FusionOutput(point: nil, state: currentState(mode: mode), anomalies: [])
        }

        guard let base = drEstimate ?? lastAcceptedCoordinate else {
            return FusionOutput(point: nil, state: currentState(mode: mode), anomalies: [])
        }

        let previousDistance = lastPedometerDistance ?? sample.distanceFromPedometer ?? 0
        let currentDistance = sample.distanceFromPedometer ?? previousDistance
        let delta = max(0, currentDistance - previousDistance)
        let heading = lastHeadingDegrees ?? 0
        let advanced = advance(coordinate: base, meters: delta, headingDegrees: heading)
        drEstimate = advanced
        filter.predict(processNoise: 6)
        filter.update(coordinate: advanced, measurementVariance: 40)

        let confidence = ConfidenceEstimator.estimate(
            mode: mode,
            accuracyMeters: 25,
            hadAnomaly: false
        )
        let point = TrackPoint(
            lat: advanced.latitude,
            lon: advanced.longitude,
            source: .pedometer,
            accuracy: 25,
            confidence: confidence,
            timestamp: sample.timestamp,
            altitude: lastRelativeAltitude
        )
        lastAcceptedCoordinate = advanced
        lastAcceptedTimestamp = sample.timestamp

        return FusionOutput(
            point: point,
            state: FusionState(
                mode: mode,
                estimate: advanced,
                accuracyMeters: 25,
                confidence: confidence,
                lastUpdate: sample.timestamp
            ),
            anomalies: anomalies
        )
    }

    private func handleLocation(_ sample: SensorSample, anomalies: inout [AnomalyEvent]) -> FusionOutput {
        guard let coordinate = sample.coordinate else {
            let mode = modeController.evaluate(hasFix: false, accuracyMeters: nil, now: sample.timestamp)
            return FusionOutput(point: nil, state: currentState(mode: mode), anomalies: [])
        }

        let accuracy = sample.horizontalAccuracy ?? .infinity
        let hasUsableFix = accuracy > 0 && accuracy <= TrackingConstants.accuracyThresholdMeters

        // Accuracy gate: worse than N → do not trust GPS as primary.
        if accuracy > TrackingConstants.accuracyThresholdMeters {
            anomalies.append(
                AnomalyEvent(
                    timestamp: sample.timestamp,
                    kind: .accuracyRejected,
                    message: String(format: "GPS accuracy %.0fm > %.0fm threshold", accuracy, TrackingConstants.accuracyThresholdMeters)
                )
            )
        }

        // Teleport / impossible speed check against last accepted point.
        if let last = lastAcceptedCoordinate, let lastTime = lastAcceptedTimestamp {
            let distance = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            let dt = max(sample.timestamp.timeIntervalSince(lastTime), 0.001)
            let speed = distance / dt
            if speed > TrackingConstants.maxPlausibleSpeedMetersPerSecond {
                let kind: AnomalyKind = distance > 80 ? .teleport : .impossibleSpeed
                anomalies.append(
                    AnomalyEvent(
                        timestamp: sample.timestamp,
                        kind: kind,
                        message: String(format: "Dropped GPS jump %.0fm in %.1fs (%.1f m/s)", distance, dt, speed)
                    )
                )
                let mode = modeController.evaluate(hasFix: false, accuracyMeters: accuracy, now: sample.timestamp)
                return FusionOutput(point: nil, state: currentState(mode: mode), anomalies: anomalies)
            }
        }

        let mode = modeController.evaluate(
            hasFix: hasUsableFix || (accuracy > 0 && accuracy.isFinite),
            accuracyMeters: accuracy,
            now: sample.timestamp
        )

        filter.predict()

        var fusedCoordinate = coordinate
        var source: TrackSource = .gps

        switch mode {
        case .gpsOk:
            filter.update(coordinate: coordinate, measurementVariance: max(accuracy * accuracy, 4))
            fusedCoordinate = filter.coordinate ?? coordinate
            source = .gps
            drEstimate = fusedCoordinate
        case .drPedometer:
            // Ignore bad GPS fix for placement; keep DR estimate if any.
            if let dr = drEstimate {
                fusedCoordinate = dr
                source = .dr
            } else {
                return FusionOutput(point: nil, state: currentState(mode: mode), anomalies: anomalies)
            }
        case .recoveringBlend:
            let w = modeController.blendWeight(now: sample.timestamp)
            let dr = drEstimate ?? lastAcceptedCoordinate ?? coordinate
            fusedCoordinate = blend(from: dr, to: coordinate, weight: w)
            filter.update(coordinate: fusedCoordinate, measurementVariance: max(accuracy * accuracy, 9))
            fusedCoordinate = filter.coordinate ?? fusedCoordinate
            source = .fused
            drEstimate = fusedCoordinate
        }

        let confidence = ConfidenceEstimator.estimate(
            mode: mode,
            accuracyMeters: accuracy,
            hadAnomaly: !anomalies.isEmpty
        )

        let point = TrackPoint(
            lat: fusedCoordinate.latitude,
            lon: fusedCoordinate.longitude,
            source: source,
            accuracy: accuracy.isFinite ? accuracy : 35,
            confidence: confidence,
            timestamp: sample.timestamp,
            altitude: sample.altitude ?? lastRelativeAltitude,
            anomalyFlags: anomalies.map(\.kind)
        )

        lastAcceptedCoordinate = fusedCoordinate
        lastAcceptedTimestamp = sample.timestamp

        return FusionOutput(
            point: point,
            state: FusionState(
                mode: mode,
                estimate: fusedCoordinate,
                accuracyMeters: accuracy.isFinite ? accuracy : 35,
                confidence: confidence,
                lastUpdate: sample.timestamp
            ),
            anomalies: anomalies
        )
    }

    private func currentState(mode: FusionMode? = nil) -> FusionState {
        FusionState(
            mode: mode ?? modeController.mode,
            estimate: filter.coordinate ?? lastAcceptedCoordinate,
            accuracyMeters: filter.uncertaintyMeters,
            confidence: ConfidenceEstimator.estimate(
                mode: mode ?? modeController.mode,
                accuracyMeters: filter.uncertaintyMeters,
                hadAnomaly: false
            ),
            lastUpdate: lastAcceptedTimestamp ?? Date()
        )
    }

    private func blend(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        weight: Double
    ) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: from.latitude + (to.latitude - from.latitude) * weight,
            longitude: from.longitude + (to.longitude - from.longitude) * weight
        )
    }

    private func advance(
        coordinate: CLLocationCoordinate2D,
        meters: Double,
        headingDegrees: Double
    ) -> CLLocationCoordinate2D {
        guard meters > 0 else { return coordinate }
        let earthRadius = 6_371_000.0
        let bearing = headingDegrees * .pi / 180
        let lat1 = coordinate.latitude * .pi / 180
        let lon1 = coordinate.longitude * .pi / 180
        let angDist = meters / earthRadius
        let lat2 = asin(sin(lat1) * cos(angDist) + cos(lat1) * sin(angDist) * cos(bearing))
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angDist) * cos(lat1),
            cos(angDist) - sin(lat1) * sin(lat2)
        )
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }
}

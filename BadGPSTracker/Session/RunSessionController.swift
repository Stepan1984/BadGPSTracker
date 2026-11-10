import Combine
import CoreLocation
import Foundation

/// Orchestrates one run: permissions → sensors → fusion → map match → persistence → UI state.
@MainActor
final class RunSessionController: ObservableObject {
    @Published private(set) var session: RunSession?
    @Published private(set) var fusionState: FusionState = .initial
    @Published private(set) var livePoints: [TrackPoint] = []
    @Published private(set) var statusMessage: String = "Ready"
    @Published var selectedReviewSessionID: UUID?

    let permissions: PermissionsService
    let store: RunStore

    private let locationSensor = LocationSensor()
    private let motionSensor = MotionSensor()
    private let barometerSensor = BarometerSensor()
    private let fusion = FusionEngine()
    private let matcher = MapKitMatcher()

    private var lastUIPublish: Date = .distantPast
    private let uiMinInterval: TimeInterval = 1.0 / TrackingConstants.uiRefreshHertz

    init(permissions: PermissionsService, store: RunStore) {
        self.permissions = permissions
        self.store = store
        wireSensors()
    }

    private func wireSensors() {
        locationSensor.onSample = { [weak self] sample in
            Task { @MainActor in
                await self?.handle(sample)
            }
        }
        motionSensor.onSample = { [weak self] sample in
            Task { @MainActor in
                await self?.handle(sample)
            }
        }
        barometerSensor.onSample = { [weak self] sample in
            Task { @MainActor in
                await self?.handle(sample)
            }
        }
    }

    func preparePermissions() {
        permissions.refresh()
        permissions.requestLocationWhenInUse()
        permissions.requestMotionIfNeeded()
        if permissions.snapshot.location == .authorizedWhenInUse {
            permissions.requestLocationAlways()
        }
    }

    func startRun() {
        guard permissions.snapshot.canStartRun else {
            statusMessage = "Location permission required"
            preparePermissions()
            return
        }

        fusion.reset()
        livePoints = []
        fusionState = .initial

        var newSession = RunSession(status: .running)
        session = newSession
        store.upsert(newSession)

        let background = permissions.snapshot.location == .authorizedAlways
        locationSensor.start(backgroundEnabled: background)
        motionSensor.start()
        barometerSensor.start()

        statusMessage = background ? "Tracking (background OK)" : "Tracking (when-in-use)"
        persistWorkingCopy()
        _ = newSession
    }

    func stopRun() {
        locationSensor.stop()
        motionSensor.stop()
        barometerSensor.stop()

        guard var current = session else { return }
        current.status = .stopped
        current.endedAt = Date()
        current.points = livePoints
        current.summary = makeSummary(for: current)
        session = current
        store.upsert(current)
        selectedReviewSessionID = current.id
        statusMessage = "Run saved"
    }

    private func handle(_ sample: SensorSample) async {
        guard session?.status == .running else { return }

        let output = fusion.ingest(sample)
        fusionState = output.state

        if !output.anomalies.isEmpty, var current = session {
            current.anomalies.append(contentsOf: output.anomalies)
            session = current
        }

        guard var point = output.point else {
            publishSoftStatus()
            return
        }

        point = await matcher.match(point)
        livePoints.append(point)

        let now = Date()
        if now.timeIntervalSince(lastUIPublish) >= uiMinInterval {
            lastUIPublish = now
            persistWorkingCopy()
        }
        publishSoftStatus()
    }

    private func persistWorkingCopy() {
        guard var current = session else { return }
        current.points = livePoints
        current.status = .running
        session = current
        store.upsert(current)
    }

    private func publishSoftStatus() {
        switch fusionState.mode {
        case .gpsOk:
            statusMessage = "GPS"
        case .drPedometer:
            statusMessage = "Steps / dead reckoning"
        case .recoveringBlend:
            statusMessage = "Blending GPS recovery"
        }
    }

    private func makeSummary(for session: RunSession) -> RunSessionSummary {
        let duration = (session.endedAt ?? Date()).timeIntervalSince(session.startedAt)
        var distance: Double = 0
        if session.points.count > 1 {
            for i in 1..<session.points.count {
                let a = session.points[i - 1]
                let b = session.points[i]
                distance += CLLocation(latitude: a.lat, longitude: a.lon)
                    .distance(from: CLLocation(latitude: b.lat, longitude: b.lon))
            }
        }
        return RunSessionSummary(
            distanceMeters: distance,
            durationSeconds: duration,
            pointCount: session.points.count,
            anomalyCount: session.anomalies.count
        )
    }
}

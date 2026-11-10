import CoreLocation
import CoreMotion
import Foundation

/// Thin wrapper around location / motion authorization. UI asks here before Start.
@MainActor
final class PermissionsService: NSObject, ObservableObject {
    @Published private(set) var snapshot = PermissionSnapshot(
        location: .notDetermined,
        motion: .notDetermined
    )

    private let locationManager = CLLocationManager()
    private let motionActivityManager = CMMotionActivityManager()

    override init() {
        super.init()
        locationManager.delegate = self
        refresh()
    }

    func refresh() {
        snapshot.location = map(locationManager.authorizationStatus)
        if CMPedometer.isStepCountingAvailable() {
            // Pedometer itself has no direct status API on all OS versions;
            // motion activity availability is a reasonable proxy for fitness access.
            if CMMotionActivityManager.isActivityAvailable() {
                // Leave as-is until we request; notDetermined until first request.
                if snapshot.motion == .notDetermined {
                    snapshot.motion = .notDetermined
                }
            } else {
                snapshot.motion = .unavailable
            }
        } else {
            snapshot.motion = .unavailable
        }
    }

    func requestLocationWhenInUse() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Background fitness tracking needs Always after When In Use.
    func requestLocationAlways() {
        locationManager.requestAlwaysAuthorization()
    }

    func requestMotionIfNeeded() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            snapshot.motion = .unavailable
            return
        }
        motionActivityManager.queryActivityStarting(
            from: Date().addingTimeInterval(-60),
            to: Date(),
            to: .main
        ) { [weak self] _, error in
            Task { @MainActor in
                if error != nil {
                    self?.snapshot.motion = .denied
                } else {
                    self?.snapshot.motion = .authorized
                }
            }
        }
    }

    private func map(_ status: CLAuthorizationStatus) -> LocationPermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        case .authorizedWhenInUse: return .authorizedWhenInUse
        case .authorizedAlways: return .authorizedAlways
        @unknown default: return .denied
        }
    }
}

extension PermissionsService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            refresh()
        }
    }
}

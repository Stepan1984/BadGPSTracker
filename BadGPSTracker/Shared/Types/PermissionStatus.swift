import Foundation

enum LocationPermissionStatus: String, Sendable {
    case notDetermined
    case denied
    case restricted
    case authorizedWhenInUse
    case authorizedAlways
}

enum MotionPermissionStatus: String, Sendable {
    case notDetermined
    case denied
    case authorized
    case unavailable
}

struct PermissionSnapshot: Sendable {
    var location: LocationPermissionStatus
    var motion: MotionPermissionStatus

    var canStartRun: Bool {
        switch location {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }
}

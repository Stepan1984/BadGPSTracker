import Foundation

enum AnomalyKind: String, Codable, Sendable, CaseIterable {
    case teleport
    case impossibleSpeed
    case spoofSuspect
    case accuracyRejected
}

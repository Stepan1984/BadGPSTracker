import Foundation

enum RunSessionStatus: String, Codable, Sendable {
    case preparing
    case running
    case stopped
}

struct RunSessionSummary: Codable, Sendable, Equatable {
    var distanceMeters: Double
    var durationSeconds: TimeInterval
    var pointCount: Int
    var anomalyCount: Int
}

struct RunSession: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?
    var status: RunSessionStatus
    var points: [TrackPoint]
    var anomalies: [AnomalyEvent]
    var summary: RunSessionSummary?

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        status: RunSessionStatus = .preparing,
        points: [TrackPoint] = [],
        anomalies: [AnomalyEvent] = [],
        summary: RunSessionSummary? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.points = points
        self.anomalies = anomalies
        self.summary = summary
    }
}

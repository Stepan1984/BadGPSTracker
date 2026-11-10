import Foundation

struct AnomalyEvent: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let kind: AnomalyKind
    let message: String
    let relatedPointID: UUID?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: AnomalyKind,
        message: String,
        relatedPointID: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.message = message
        self.relatedPointID = relatedPointID
    }
}

import MapKit
import SwiftUI

struct PostRunView: View {
    @EnvironmentObject private var sessionController: RunSessionController
    @EnvironmentObject private var store: RunStore

    private var reviewSession: RunSession? {
        if let id = sessionController.selectedReviewSessionID {
            return store.session(id: id) ?? sessionController.session
        }
        return store.sessions.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let run = reviewSession {
                    content(for: run)
                } else {
                    ContentUnavailableView(
                        "No run to review",
                        systemImage: "figure.run",
                        description: Text("Finish a run from Start / Live to review the smoothed track here. GPX/FIT export is out of v1.")
                    )
                }
            }
            .navigationTitle("Post-run")
        }
    }

    @ViewBuilder
    private func content(for run: RunSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Map {
                    if run.points.count > 1 {
                        MapPolyline(coordinates: run.points.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                        })
                        .stroke(.green, lineWidth: 4)

                        // Low-confidence segments as result visualization (not a setting).
                        ForEach(Array(lowConfidenceSegments(in: run.points).enumerated()), id: \.offset) { _, coords in
                            MapPolyline(coordinates: coords)
                                .stroke(.orange.opacity(0.85), lineWidth: 6)
                        }
                    }
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                summaryBlock(for: run)

                if !run.anomalies.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Anomalies")
                            .font(.headline)
                        ForEach(run.anomalies) { event in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.kind.rawValue)
                                    .font(.subheadline.bold())
                                Text(event.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func summaryBlock(for run: RunSession) -> some View {
        let summary = run.summary
        return VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)
            labeled("Started", run.startedAt.formatted(date: .abbreviated, time: .shortened))
            if let ended = run.endedAt {
                labeled("Ended", ended.formatted(date: .omitted, time: .shortened))
            }
            labeled("Points", "\(summary?.pointCount ?? run.points.count)")
            if let distance = summary?.distanceMeters {
                labeled("Distance", String(format: "%.0f m", distance))
            }
            if let duration = summary?.durationSeconds {
                labeled("Duration", formatDuration(duration))
            }
            labeled("Anomalies", "\(summary?.anomalyCount ?? run.anomalies.count)")
            Text("Confidence stays internal; orange segments mark weaker stretches for review only.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Groups consecutive low-confidence points for orange overlay.
    private func lowConfidenceSegments(in points: [TrackPoint]) -> [[CLLocationCoordinate2D]] {
        var segments: [[CLLocationCoordinate2D]] = []
        var current: [CLLocationCoordinate2D] = []
        for point in points {
            if point.confidence < 0.6 {
                current.append(CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon))
            } else if !current.isEmpty {
                if current.count > 1 { segments.append(current) }
                current = []
            }
        }
        if current.count > 1 { segments.append(current) }
        return segments
    }
}

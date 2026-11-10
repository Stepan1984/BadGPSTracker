import CoreLocation
import Foundation
import MapKit

/// MapKit map-matching stub. Wired into the pipeline; snaps lightly / identity when lookup fails.
@MainActor
final class MapKitMatcher {
    private var lastMatchAt: Date = .distantPast

    func match(_ point: TrackPoint, force: Bool = false) async -> TrackPoint {
        let now = Date()
        if !force,
           now.timeIntervalSince(lastMatchAt) < TrackingConstants.mapMatchingMinIntervalSeconds {
            return point
        }
        lastMatchAt = now

        let coordinate = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "road"
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 120,
            longitudinalMeters: 120
        )

        do {
            let response = try await MKLocalSearch(request: request).start()
            let candidates = response.mapItems.map(\.placemark.coordinate)
            guard let nearest = candidates.min(by: { lhs, rhs in
                distance(coordinate, lhs) < distance(coordinate, rhs)
            }) else {
                return point
            }

            // Soft snap: blend toward nearest placemark instead of hard teleport.
            let snapped = CLLocationCoordinate2D(
                latitude: point.lat * 0.7 + nearest.latitude * 0.3,
                longitude: point.lon * 0.7 + nearest.longitude * 0.3
            )
            var matched = point
            matched.lat = snapped.latitude
            matched.lon = snapped.longitude
            if matched.source == .gps || matched.source == .fused {
                matched.source = .fused
            }
            return matched
        } catch {
            // Placeholder behavior: keep fused point unchanged when MapKit search fails
            // (simulator / offline / no nearby items).
            return point
        }
    }

    private func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}

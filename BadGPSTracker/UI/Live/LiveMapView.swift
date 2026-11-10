import MapKit
import SwiftUI

struct LiveMapView: View {
    @EnvironmentObject private var sessionController: RunSessionController

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                map
                controls
            }
            .navigationTitle("Live")
            .onChange(of: sessionController.livePoints.count) { _, _ in
                recenterIfNeeded()
            }
        }
    }

    private var map: some View {
        Map(position: $position) {
            if sessionController.livePoints.count > 1 {
                MapPolyline(coordinates: sessionController.livePoints.map {
                    CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                })
                .stroke(.blue, lineWidth: 4)
            }

            if let last = sessionController.livePoints.last {
                Annotation("You", coordinate: CLLocationCoordinate2D(latitude: last.lat, longitude: last.lon)) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .ignoresSafeArea(edges: .bottom)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sessionController.statusMessage)
                        .font(.headline)
                    Text("\(sessionController.livePoints.count) points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if sessionController.session?.status == .running {
                    Button("Stop", role: .destructive) {
                        sessionController.stopRun()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Text("Not tracking")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.bar)
    }

    private func recenterIfNeeded() {
        guard let last = sessionController.livePoints.last else { return }
        // Smooth camera — avoid jumpy marker feel by animating to fused point only.
        withAnimation(.easeInOut(duration: 0.6)) {
            position = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: last.lat, longitude: last.lon),
                    latitudinalMeters: 250,
                    longitudinalMeters: 250
                )
            )
        }
    }
}

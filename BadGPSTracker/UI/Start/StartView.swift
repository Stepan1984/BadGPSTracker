import SwiftUI

struct StartView: View {
    @EnvironmentObject private var sessionController: RunSessionController
    @EnvironmentObject private var permissions: PermissionsService
    @EnvironmentObject private var store: RunStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("BadGPSTracker")
                        .font(.largeTitle.bold())
                    Text("Stable run tracks when GPS gets ugly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                permissionCard

                Button {
                    sessionController.preparePermissions()
                    sessionController.startRun()
                } label: {
                    Text("Start Run")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(sessionController.session?.status == .running)

                if sessionController.session?.status == .running {
                    Text("Session running — open Live tab")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                recentList
                Spacer()
            }
            .padding()
            .navigationTitle("Start")
            .onAppear {
                permissions.refresh()
            }
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Permissions")
                .font(.headline)
            labeledRow("Location", value: permissions.snapshot.location.rawValue)
            labeledRow("Motion", value: permissions.snapshot.motion.rawValue)
            Button("Request Access") {
                sessionController.preparePermissions()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent runs")
                .font(.headline)
            if store.sessions.isEmpty {
                Text("No saved runs yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.sessions.prefix(5)) { run in
                    Button {
                        sessionController.selectedReviewSessionID = run.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                                Text("\(run.points.count) points · \(run.status.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeledRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .font(.callout.monospaced())
        }
    }
}

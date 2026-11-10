import Foundation

/// Composition root — wires Permissions, Persistence, and Session once.
@MainActor
final class AppModel: ObservableObject {
    let permissions: PermissionsService
    let store: RunStore
    let sessionController: RunSessionController

    init() {
        let permissions = PermissionsService()
        let store = RunStore()
        self.permissions = permissions
        self.store = store
        self.sessionController = RunSessionController(permissions: permissions, store: store)
    }
}

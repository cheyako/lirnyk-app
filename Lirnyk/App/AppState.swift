import Foundation
import Observation

/// Drives the menu-bar icon pulse while a rephrase is running.
@Observable
final class AppState {
    private(set) var iconPulse = false
    @ObservationIgnored private var pulseTask: Task<Void, Never>?

    func setBusy(_ busy: Bool) {
        pulseTask?.cancel()
        iconPulse = false
        guard busy else { return }
        pulseTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                self?.iconPulse.toggle()
            }
        }
    }
}

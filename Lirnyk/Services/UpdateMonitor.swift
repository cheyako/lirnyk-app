import Foundation
import Observation

/// Checks GitHub for a newer release in the background and remembers what it found.
/// Background checks stay silent on errors; manual checks from Settings report them.
@Observable
final class UpdateMonitor {
    private static let automaticKey = "checksForUpdatesAutomatically"
    private static let lastCheckKey = "lastUpdateCheck"
    static let checkInterval: TimeInterval = 24 * 60 * 60

    struct Update: Equatable {
        let version: String
        let url: URL
    }

    /// Newer release found by the latest successful check.
    private(set) var available: Update?

    var checksAutomatically: Bool {
        didSet { defaults.set(checksAutomatically, forKey: Self.automaticKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let fetch: () async throws -> UpdateCheckResult
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var loop: Task<Void, Never>?

    init(defaults: UserDefaults = .standard,
         now: @escaping () -> Date = Date.init,
         fetch: @escaping () async throws -> UpdateCheckResult) {
        self.defaults = defaults
        self.now = now
        self.fetch = fetch
        checksAutomatically = defaults.object(forKey: Self.automaticKey) as? Bool ?? true
    }

    static func isCheckDue(lastCheck: Date?, now: Date) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= checkInterval
    }

    /// Checks shortly after launch, then re-evaluates hourly; a check runs only when one is due.
    func start(initialDelay: Duration = .seconds(10)) {
        loop?.cancel()
        loop = Task { [weak self] in
            try? await Task.sleep(for: initialDelay)
            while !Task.isCancelled {
                await self?.checkIfDue()
                try? await Task.sleep(for: .seconds(60 * 60))
            }
        }
    }

    func checkIfDue() async {
        let lastCheck = defaults.object(forKey: Self.lastCheckKey) as? Date
        guard checksAutomatically, Self.isCheckDue(lastCheck: lastCheck, now: now()) else { return }
        _ = try? await check()
    }

    /// Runs a check now and records its outcome; errors are thrown to the caller.
    @discardableResult
    func check() async throws -> UpdateCheckResult {
        let result = try await fetch()
        defaults.set(now(), forKey: Self.lastCheckKey)
        switch result {
        case .upToDate: available = nil
        case let .available(version, url): available = Update(version: version, url: url)
        }
        return result
    }
}

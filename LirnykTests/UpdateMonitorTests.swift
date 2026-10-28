import Foundation
import Testing
@testable import Lirnyk

struct UpdateMonitorTests {
    let suiteName = "lirnyk-tests-\(UUID().uuidString)"
    static let release = URL(string: "https://github.com/cheyako/lirnyk-app/releases/tag/v9.0.0")!

    @Test func checkIsDueWithoutHistoryOrAfterADay() {
        let now = Date()
        #expect(UpdateMonitor.isCheckDue(lastCheck: nil, now: now))
        #expect(UpdateMonitor.isCheckDue(lastCheck: now.addingTimeInterval(-UpdateMonitor.checkInterval), now: now))
        #expect(!UpdateMonitor.isCheckDue(lastCheck: now.addingTimeInterval(-60 * 60), now: now))
    }

    @Test func automaticCheckRecordsAvailableUpdateOncePerDay() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var fetches: [Bool] = []
        let monitor = UpdateMonitor(defaults: defaults) { counted in
            fetches.append(counted)
            return .available(version: "9.0.0", url: Self.release)
        }

        await monitor.checkIfDue()
        await monitor.checkIfDue()

        #expect(fetches == [true])
        #expect(monitor.available == UpdateMonitor.Update(version: "9.0.0", url: Self.release))
    }

    @Test func automaticCheckSkippedWhenTurnedOff() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var fetches = 0
        let monitor = UpdateMonitor(defaults: defaults) { _ in
            fetches += 1
            return .upToDate
        }
        #expect(monitor.checksAutomatically)

        monitor.checksAutomatically = false
        await monitor.checkIfDue()

        #expect(fetches == 0)
        #expect(!UpdateMonitor(defaults: defaults) { _ in .upToDate }.checksAutomatically)
    }

    @Test func automaticCheckSwallowsErrorsAndRetriesLater() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var fetches = 0
        let monitor = UpdateMonitor(defaults: defaults) { _ in
            fetches += 1
            throw UpdateCheckError.server(status: 503)
        }

        await monitor.checkIfDue()
        await monitor.checkIfDue()

        #expect(fetches == 2)
        #expect(monitor.available == nil)
    }

    @Test func manualCheckIsNotCounted() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var fetches: [Bool] = []
        let monitor = UpdateMonitor(defaults: defaults) { counted in
            fetches.append(counted)
            return .upToDate
        }

        try await monitor.check()

        #expect(fetches == [false])
    }
}

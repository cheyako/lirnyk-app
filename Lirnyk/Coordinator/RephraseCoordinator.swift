import Foundation
import Observation

protocol AccessibilityChecking: AnyObject {
    func checkTrusted() -> Bool
}

protocol FocusTracking: AnyObject {
    func frontmostAppID() -> pid_t?
    func activate(pid: pid_t) async
}

protocol RephraseFeedback: AnyObject {
    func showWorking(_ title: String)
    func showError(_ message: String)
    func showInfo(_ message: String)
    func hide()
}

protocol CancelKeyMonitoring: AnyObject {
    func start(onCancel: @escaping () -> Void)
    func stop()
}

@Observable
final class RephraseCoordinator {
    static let busyMessage = "Busy — still rephrasing"

    private(set) var activeProfile: Profile? {
        didSet { onBusyChanged(activeProfile != nil) }
    }
    var isBusy: Bool { activeProfile != nil }

    @ObservationIgnored var openSettings: () -> Void = {}
    @ObservationIgnored var onBusyChanged: (Bool) -> Void = { _ in }

    @ObservationIgnored private let selection: SelectionService
    @ObservationIgnored private let client: RephraseClient
    @ObservationIgnored private let accessibility: AccessibilityChecking
    @ObservationIgnored private let focus: FocusTracking
    @ObservationIgnored private let feedback: RephraseFeedback
    @ObservationIgnored private let cancelKey: CancelKeyMonitoring
    @ObservationIgnored private let hasAPIKey: () -> Bool
    @ObservationIgnored private var requestTask: Task<String, Error>?

    init(selection: SelectionService, client: RephraseClient, accessibility: AccessibilityChecking,
         focus: FocusTracking, feedback: RephraseFeedback, cancelKey: CancelKeyMonitoring,
         hasAPIKey: @escaping () -> Bool) {
        self.selection = selection
        self.client = client
        self.accessibility = accessibility
        self.focus = focus
        self.feedback = feedback
        self.cancelKey = cancelKey
        self.hasAPIKey = hasAPIKey
    }

    func run(_ profile: Profile) async {
        guard !isBusy else {
            feedback.showInfo(Self.busyMessage)
            return
        }
        guard accessibility.checkTrusted() else {
            report(RephraseError.accessibilityNotGranted)
            openSettings()
            return
        }
        guard hasAPIKey() else {
            report(RephraseError.missingAPIKey)
            openSettings()
            return
        }

        activeProfile = profile
        defer {
            cancelKey.stop()
            requestTask = nil
            activeProfile = nil
        }

        let originApp = focus.frontmostAppID()
        let original: String
        do {
            original = try await selection.readSelection()
        } catch {
            report(error)
            return
        }

        feedback.showWorking(profile.title)
        cancelKey.start { [weak self] in self?.cancel() }

        let client = self.client
        let task = Task { try await client.rephrase(text: original, systemPrompt: profile.prompt) }
        requestTask = task
        do {
            let result = try await task.value
            if task.isCancelled { throw RephraseError.cancelled }
            cancelKey.stop()
            if let originApp, focus.frontmostAppID() != originApp {
                await focus.activate(pid: originApp)
            }
            await selection.replaceSelection(with: Whitespace.preserving(of: original, in: result))
            feedback.hide()
        } catch {
            selection.restoreClipboard()
            report(error)
        }
    }

    func cancel() {
        requestTask?.cancel()
    }

    private func report(_ error: Error) {
        let rephraseError: RephraseError = switch error {
        case let error as RephraseError: error
        case is CancellationError: .cancelled
        default: .network(error.localizedDescription)
        }
        if rephraseError == .cancelled {
            feedback.showInfo(rephraseError.message)
        } else {
            feedback.showError(rephraseError.message)
        }
    }
}

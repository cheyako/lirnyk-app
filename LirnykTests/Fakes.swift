import Foundation
@testable import Lirnyk

final class FakeSelection: SelectionService {
    var text: String? = "helo wrld"
    var replaced: [String] = []
    var restoreCount = 0

    func readSelection() async throws -> String {
        guard let text else { throw RephraseError.nothingSelected }
        return text
    }
    func replaceSelection(with text: String) async { replaced.append(text) }
    func restoreClipboard() { restoreCount += 1 }
}

final class FakeClient: RephraseClient {
    var handler: (String, String) async throws -> String = { _, _ in "hello world" }
    var calls: [(text: String, prompt: String)] = []

    func rephrase(text: String, systemPrompt: String) async throws -> String {
        calls.append((text, systemPrompt))
        return try await handler(text, systemPrompt)
    }
}

final class FakeAccessibility: AccessibilityChecking {
    var trusted = true
    func checkTrusted() -> Bool { trusted }
}

final class FakeFocus: FocusTracking {
    var frontmost: pid_t? = 100
    var activated: [pid_t] = []
    func frontmostAppID() -> pid_t? { frontmost }
    func activate(pid: pid_t) async {
        activated.append(pid)
        frontmost = pid
    }
}

final class FakeFeedback: RephraseFeedback {
    enum Event: Equatable { case working(String), error(String), info(String), hidden }
    var events: [Event] = []
    func showWorking(_ title: String) { events.append(.working(title)) }
    func showError(_ message: String) { events.append(.error(message)) }
    func showInfo(_ message: String) { events.append(.info(message)) }
    func hide() { events.append(.hidden) }
}

final class FakeCancelKey: CancelKeyMonitoring {
    var onCancel: (() -> Void)?
    func start(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    func stop() { onCancel = nil }
}

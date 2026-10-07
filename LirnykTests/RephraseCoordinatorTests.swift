import Foundation
import Testing
@testable import Lirnyk

struct RephraseCoordinatorTests {
    let selection = FakeSelection()
    let client = FakeClient()
    let accessibility = FakeAccessibility()
    let focus = FakeFocus()
    let feedback = FakeFeedback()
    let cancelKey = FakeCancelKey()
    let profile = Profile(title: "Friendly", prompt: "Be friendly")

    func makeCoordinator(hasAPIKey: Bool = true) -> RephraseCoordinator {
        RephraseCoordinator(
            selection: selection, client: client, accessibility: accessibility,
            focus: focus, feedback: feedback, cancelKey: cancelKey,
            hasAPIKey: { hasAPIKey })
    }

    /// Waits until the coordinator is inside the AI request (Esc monitor installed).
    func waitUntilRequesting() async {
        while cancelKey.onCancel == nil { await Task.yield() }
    }

    @Test func happyPathReplacesSelection() async {
        let coordinator = makeCoordinator()
        await coordinator.run(profile)

        #expect(client.calls.map(\.text) == ["helo wrld"])
        #expect(client.calls.map(\.prompt) == ["Be friendly"])
        #expect(selection.replaced == ["hello world"])
        #expect(selection.restoreCount == 0)
        #expect(feedback.events == [.working("Friendly"), .hidden])
        #expect(!coordinator.isBusy)
        #expect(cancelKey.onCancel == nil)
    }

    @Test func preservesOriginalOuterWhitespace() async {
        selection.text = "helo\n"
        client.handler = { _, _ in "hello" }
        await makeCoordinator().run(profile)
        #expect(selection.replaced == ["hello\n"])
    }

    @Test func nothingSelectedShowsError() async {
        selection.text = nil
        await makeCoordinator().run(profile)
        #expect(client.calls.isEmpty)
        #expect(feedback.events == [.error(RephraseError.nothingSelected.message)])
    }

    @Test func missingPermissionOpensSettings() async {
        accessibility.trusted = false
        let coordinator = makeCoordinator()
        var opened = 0
        coordinator.openSettings = { opened += 1 }
        await coordinator.run(profile)
        #expect(opened == 1)
        #expect(client.calls.isEmpty)
        #expect(feedback.events == [.error(RephraseError.accessibilityNotGranted.message)])
    }

    @Test func missingAPIKeyOpensSettings() async {
        let coordinator = makeCoordinator(hasAPIKey: false)
        var opened = 0
        coordinator.openSettings = { opened += 1 }
        await coordinator.run(profile)
        #expect(opened == 1)
        #expect(client.calls.isEmpty)
        #expect(feedback.events == [.error(RephraseError.missingAPIKey.message)])
    }

    @Test func clientErrorRestoresClipboard() async {
        client.handler = { _, _ in throw RephraseError.unauthorized }
        let coordinator = makeCoordinator()
        await coordinator.run(profile)
        #expect(selection.replaced.isEmpty)
        #expect(selection.restoreCount == 1)
        #expect(feedback.events.last == .error(RephraseError.unauthorized.message))
        #expect(!coordinator.isBusy)
    }

    @Test func escCancelsRequest() async {
        client.handler = { _, _ in
            try await Task.sleep(for: .seconds(10))
            return "late"
        }
        let coordinator = makeCoordinator()
        let run = Task { await coordinator.run(profile) }
        await waitUntilRequesting()
        cancelKey.onCancel?()
        await run.value

        #expect(selection.replaced.isEmpty)
        #expect(selection.restoreCount == 1)
        #expect(feedback.events.last == .info("Cancelled"))
        #expect(!coordinator.isBusy)
    }

    @Test func secondRunWhileBusyIsIgnored() async {
        client.handler = { _, _ in
            try await Task.sleep(for: .seconds(10))
            return "late"
        }
        let coordinator = makeCoordinator()
        let first = Task { await coordinator.run(profile) }
        await waitUntilRequesting()

        await coordinator.run(profile)
        #expect(client.calls.count == 1)
        #expect(feedback.events.contains(.info(RephraseCoordinator.busyMessage)))

        coordinator.cancel()
        await first.value
    }

    @Test func reactivatesOriginAppWhenFocusMoved() async {
        client.handler = { [focus] _, _ in
            focus.frontmost = 200
            return "hello world"
        }
        await makeCoordinator().run(profile)
        #expect(focus.activated == [100])
        #expect(selection.replaced == ["hello world"])
    }

    @Test func doesNotReactivateWhenFocusUnchanged() async {
        await makeCoordinator().run(profile)
        #expect(focus.activated.isEmpty)
    }

    @Test func reportsBusyChanges() async {
        let coordinator = makeCoordinator()
        var states: [Bool] = []
        coordinator.onBusyChanged = { states.append($0) }
        await coordinator.run(profile)
        #expect(states == [true, false])
    }
}

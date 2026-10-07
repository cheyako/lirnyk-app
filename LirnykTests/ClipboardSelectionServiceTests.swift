import AppKit
import Testing
@testable import Lirnyk

final class FakeKeys: KeyPosting {
    var onCopy: () -> Void = {}
    var onPaste: () -> Void = {}
    func post(_ command: KeyEventPoster.Command) {
        command == .copy ? onCopy() : onPaste()
    }
    func waitForModifiersReleased() async {}
}

struct ClipboardSelectionServiceTests {
    let pasteboard = NSPasteboard(name: .init("com.metajourney.lirnyk.tests.\(UUID().uuidString)"))
    let keys = FakeKeys()

    init() {
        pasteboard.clearContents()
        pasteboard.setString("original clipboard", forType: .string)
    }

    func makeService() -> ClipboardSelectionService {
        ClipboardSelectionService(pasteboard: pasteboard, keys: keys, restoreDelay: .zero)
    }

    func simulateCopy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    @Test func readsSelectionAndRestoresAfterReplace() async throws {
        keys.onCopy = { simulateCopy("helo") }
        var pastedText: String?
        keys.onPaste = { pastedText = pasteboard.string(forType: .string) }
        let service = makeService()

        #expect(try await service.readSelection() == "helo")
        await service.replaceSelection(with: "hello")

        #expect(pastedText == "hello")
        #expect(pasteboard.string(forType: .string) == "original clipboard")
    }

    @Test func nothingSelectedRestoresClipboard() async {
        let service = makeService()
        await #expect(throws: RephraseError.nothingSelected) { try await service.readSelection() }
        #expect(pasteboard.string(forType: .string) == "original clipboard")
    }

    @Test func userCopyDuringRequestSurvivesFailure() async throws {
        keys.onCopy = { simulateCopy("helo") }
        let service = makeService()
        _ = try await service.readSelection()

        simulateCopy("https://user.copied/url")
        service.restoreClipboard()

        #expect(pasteboard.string(forType: .string) == "https://user.copied/url")
    }

    @Test func userCopyDuringRequestSurvivesReplace() async throws {
        keys.onCopy = { simulateCopy("helo") }
        var pastedText: String?
        keys.onPaste = { pastedText = pasteboard.string(forType: .string) }
        let service = makeService()
        _ = try await service.readSelection()

        simulateCopy("https://user.copied/url")
        await service.replaceSelection(with: "hello")

        #expect(pastedText == "hello")
        #expect(pasteboard.string(forType: .string) == "https://user.copied/url")
    }

    @Test func copyToClipboardLeavesResultForManualPaste() async throws {
        keys.onCopy = { simulateCopy("helo") }
        let service = makeService()
        _ = try await service.readSelection()

        service.copyToClipboard("hello")
        service.restoreClipboard()

        #expect(pasteboard.string(forType: .string) == "hello")
        #expect(pasteboard.types?.contains(.transient) == false)
    }

    @Test func defaultRestoreDelayGivesSlowAppsTimeToPaste() {
        #expect(ClipboardSelectionService.defaultRestoreDelay >= .seconds(1))
    }
}

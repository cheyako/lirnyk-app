import AppKit

protocol SelectionService: AnyObject {
    /// Copies the current selection. Throws `RephraseError.nothingSelected`.
    func readSelection() async throws -> String
    /// Pastes `text` over the selection, then restores the user's clipboard.
    func replaceSelection(with text: String) async
    /// Restores the clipboard saved by `readSelection` (no-op if none, or if the user copied something since).
    func restoreClipboard()
    /// Leaves `text` on the clipboard for the user to paste manually; the saved clipboard is discarded.
    func copyToClipboard(_ text: String)
}

extension NSPasteboard.PasteboardType {
    static let transient = Self("org.nspasteboard.TransientType")
}

final class ClipboardSelectionService: SelectionService {
    /// Slow pasters (Electron apps, browsers under load) can read the pasteboard well after ⌘V.
    static let defaultRestoreDelay: Duration = .seconds(1)

    private let pasteboard: NSPasteboard
    private let keys: KeyPosting
    private let restoreDelay: Duration
    private var snapshot: PasteboardSnapshot?
    /// Pasteboard change count right after our ⌘C; any later change means the user copied something.
    private var changeCountAfterCopy: Int?

    init(pasteboard: NSPasteboard = .general, keys: KeyPosting = KeyEventPoster(),
         restoreDelay: Duration = ClipboardSelectionService.defaultRestoreDelay) {
        self.pasteboard = pasteboard
        self.keys = keys
        self.restoreDelay = restoreDelay
    }

    func readSelection() async throws -> String {
        await keys.waitForModifiersReleased()
        snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        changeCountAfterCopy = nil
        pasteboard.clearContents()
        let baseline = pasteboard.changeCount

        keys.post(.copy)
        for _ in 0..<30 where pasteboard.changeCount == baseline {
            try? await Task.sleep(for: .milliseconds(20))
        }

        guard pasteboard.changeCount != baseline,
              let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            restoreClipboard()
            throw RephraseError.nothingSelected
        }
        changeCountAfterCopy = pasteboard.changeCount
        return text
    }

    func replaceSelection(with text: String) async {
        if userCopiedSinceRead {
            snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        }
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: .transient)
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
        changeCountAfterCopy = pasteboard.changeCount

        keys.post(.paste)
        try? await Task.sleep(for: restoreDelay)
        restoreClipboard()
    }

    func restoreClipboard() {
        if !userCopiedSinceRead {
            snapshot?.restore(to: pasteboard)
        }
        snapshot = nil
        changeCountAfterCopy = nil
    }

    func copyToClipboard(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        snapshot = nil
        changeCountAfterCopy = nil
    }

    private var userCopiedSinceRead: Bool {
        guard let changeCountAfterCopy else { return false }
        return pasteboard.changeCount != changeCountAfterCopy
    }
}

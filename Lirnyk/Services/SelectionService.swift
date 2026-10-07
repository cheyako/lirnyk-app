import AppKit

protocol SelectionService: AnyObject {
    /// Copies the current selection. Throws `RephraseError.nothingSelected`.
    func readSelection() async throws -> String
    /// Pastes `text` over the selection, then restores the user's clipboard.
    func replaceSelection(with text: String) async
    /// Restores the clipboard saved by `readSelection` (no-op if none).
    func restoreClipboard()
}

extension NSPasteboard.PasteboardType {
    static let transient = Self("org.nspasteboard.TransientType")
}

final class ClipboardSelectionService: SelectionService {
    private let pasteboard: NSPasteboard
    private let keys: KeyEventPoster
    private var snapshot: PasteboardSnapshot?

    init(pasteboard: NSPasteboard = .general, keys: KeyEventPoster = KeyEventPoster()) {
        self.pasteboard = pasteboard
        self.keys = keys
    }

    func readSelection() async throws -> String {
        await keys.waitForModifiersReleased()
        snapshot = PasteboardSnapshot(pasteboard: pasteboard)
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
        return text
    }

    func replaceSelection(with text: String) async {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: .transient)
        pasteboard.clearContents()
        pasteboard.writeObjects([item])

        keys.post(.paste)
        try? await Task.sleep(for: .milliseconds(500))
        restoreClipboard()
    }

    func restoreClipboard() {
        snapshot?.restore(to: pasteboard)
        snapshot = nil
    }
}

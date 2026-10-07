import AppKit
import Testing
@testable import Lirnyk

struct PasteboardSnapshotTests {
    @Test func restoresAllTypesOfAllItems() {
        let pasteboard = NSPasteboard(name: .init("com.metajourney.lirnyk.tests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }

        let rtf = Data(#"{\rtf1 hello}"#.utf8)
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF])
        let first = NSPasteboardItem()
        first.setString("hello", forType: .string)
        first.setData(rtf, forType: .rtf)
        let second = NSPasteboardItem()
        second.setData(png, forType: .png)
        pasteboard.clearContents()
        pasteboard.writeObjects([first, second])

        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("overwritten", forType: .string)
        snapshot.restore(to: pasteboard)

        let items = pasteboard.pasteboardItems ?? []
        #expect(items.count == 2)
        #expect(items.first?.string(forType: .string) == "hello")
        #expect(items.first?.data(forType: .rtf) == rtf)
        #expect(items.last?.data(forType: .png) == png)
    }

    @Test func restoringEmptySnapshotLeavesPasteboardEmpty() {
        let pasteboard = NSPasteboard(name: .init("com.metajourney.lirnyk.tests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()

        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        pasteboard.setString("temp", forType: .string)
        snapshot.restore(to: pasteboard)

        #expect(pasteboard.string(forType: .string) == nil)
    }
}

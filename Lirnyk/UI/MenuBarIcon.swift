import AppKit
import SwiftUI

/// Menu-bar label: the Lirnyk template glyph, alternating with a dimmed copy while busy.
struct MenuBarIcon: View {
    let appState: AppState

    var body: some View {
        Image(nsImage: appState.iconPulse ? Self.dimmed : Self.normal)
    }

    private static let size = NSSize(width: 18, height: 18)

    private static let normal: NSImage = {
        let image = (NSImage(named: "MenuBarIcon")?.copy() as? NSImage) ?? NSImage()
        image.size = size
        image.isTemplate = true
        return image
    }()

    private static let dimmed: NSImage = {
        let image = NSImage(size: size, flipped: false) { rect in
            normal.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.35)
            return true
        }
        image.isTemplate = true
        return image
    }()
}

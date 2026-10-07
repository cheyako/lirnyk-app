import AppKit
import SwiftUI

enum HUDState: Equatable {
    case working(String)
    case error(String)
    case info(String)
}

struct HUDView: View {
    let state: HUDState

    var body: some View {
        HStack(spacing: 8) {
            switch state {
            case let .working(title):
                ProgressView().controlSize(.small)
                Text("\(title)…").font(.system(size: 13, weight: .medium))
                Text("esc").font(.system(size: 11)).foregroundStyle(.secondary)
            case let .error(message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text(message).font(.system(size: 13, weight: .medium))
            case let .info(message):
                Image(systemName: "info.circle.fill").foregroundStyle(.secondary)
                Text(message).font(.system(size: 13, weight: .medium))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .padding(10)
        .fixedSize()
    }
}

final class HUDController: RephraseFeedback {
    private let hosting = NSHostingView(rootView: HUDView(state: .info("")))
    private lazy var panel: NSPanel = makePanel()
    private var hideTask: Task<Void, Never>?

    func showWorking(_ title: String) { show(.working(title), autoHide: nil) }
    func showError(_ message: String) { show(.error(message), autoHide: .seconds(3)) }
    func showInfo(_ message: String) { show(.info(message), autoHide: .milliseconds(1200)) }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        panel.orderOut(nil)
    }

    private func show(_ state: HUDState, autoHide: Duration?) {
        hideTask?.cancel()
        hosting.rootView = HUDView(state: state)
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        panel.setFrame(NSRect(origin: origin(for: size), size: size), display: true)
        panel.orderFrontRegardless()

        guard let autoHide else { return }
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: autoHide)
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    /// Below-right of the mouse, clamped to the visible frame of the screen under it.
    private func origin(for size: NSSize) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        var origin = NSPoint(x: mouse.x + 12, y: mouse.y - 12 - size.height)
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        }
        return origin
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = hosting
        return panel
    }
}

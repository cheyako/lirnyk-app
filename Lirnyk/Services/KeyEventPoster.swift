import CoreGraphics

protocol KeyPosting {
    func post(_ command: KeyEventPoster.Command)
    func waitForModifiersReleased() async
}

struct KeyEventPoster: KeyPosting {
    enum Command {
        case copy, paste

        /// ANSI virtual key codes (kVK_ANSI_C = 8, kVK_ANSI_V = 9).
        var keyCode: CGKeyCode { self == .copy ? 8 : 9 }
    }

    func post(_ command: Command) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: command.keyCode, keyDown: isDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }

    /// Waits until the user releases ⌘⇧⌥⌃ so the synthetic ⌘C isn't merged with held modifiers.
    func waitForModifiersReleased() async {
        await waitForModifiersReleased(timeout: .seconds(1))
    }

    func waitForModifiersReleased(timeout: Duration) async {
        let modifiers: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if CGEventSource.flagsState(.combinedSessionState).intersection(modifiers).isEmpty { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

# Lirnyk manual test checklist

Setup: `make install`, grant Accessibility, set API key, "Test connection" shows ✓.

For each app — TextEdit, Notes, Mail (compose), Safari textarea, Chrome textarea, Slack message box, VS Code:
- [ ] Select "helo wrld how r u", press ⌃⌥F → text replaced, HUD shows "Friendly…" then hides, menu icon pulses meanwhile.
- [ ] ⌘Z restores the original text.
- [ ] Copy an image beforehand → after rephrase the image is still on the clipboard.

General:
- [ ] Triple-click a line (selects trailing newline) → rephrased line still ends with newline.
- [ ] Press hotkey with nothing selected → HUD "Nothing selected", no change.
- [ ] Press hotkey, then Esc during the request → HUD "Cancelled", no change, clipboard intact.
- [ ] Press hotkey, switch to another app within 1 s → Lirnyk re-activates the original app and pastes there. If macOS refuses activation, nothing is pasted and HUD says the result was copied.
- [ ] Press hotkey twice quickly → second shows "Busy — still rephrasing".
- [ ] Wrong API key → HUD "OpenRouter rejected the API key (401)".
- [ ] Ukrainian keyboard layout active → copy/paste still work.
- [ ] Add a profile, record a shortcut, use it; delete it → shortcut no longer fires.
- [ ] Click a profile in the menu → runs on current selection in the previous app.
- [ ] Revoke Accessibility → hotkey opens Settings with the warning banner.
- [ ] Log out / in → Lirnyk starts automatically.

Known limitation: ⌘C/⌘V are posted as ANSI key codes; a pure Dvorak layout would receive other shortcuts.
Known limitation: in VS Code/JetBrains ⌘C with no selection copies the current line, so that line gets rephrased.
- [ ] Copy a URL while a rephrase is running → after it finishes the URL is still on the clipboard.

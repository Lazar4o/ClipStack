# ClipStack

Personal clipboard history for macOS (a free Win+V for the Mac). It remembers the text, images and
⌘⇧4 screenshots you copy, keeps the last 10 / 20 / 50 / 100 items, and pastes any of them back into
the app you're in.

Native Swift/AppKit + SwiftUI, no third-party code, ~60–80 MB of memory. Requires macOS 26.

## Install / update

```bash
scripts/install.sh
```

Builds, signs, copies to `~/Applications/ClipStack.app` and (re)launches it. Run it again after any change.
History and settings survive reinstalls.

**One-time signing setup** (already done on this Mac): a self-signed code-signing certificate named
`ClipStack Dev` in the login keychain (Keychain Access → Certificate Assistant → Create a Certificate…,
Self-Signed Root, Code Signing). It keeps the signature stable so macOS doesn't forget the Accessibility
permission after every rebuild. Without it the build falls back to ad-hoc signing and prints a warning.

## Using it

| Key | Action |
|---|---|
| **⇧⌘V** | Open / close the history panel (change it in Settings) |
| type | Search (case- and accent-insensitive; Cyrillic works) |
| ↑ ↓ / Page Up/Down | Move the selection |
| ↩ or click | Paste the item into the app you were in |
| ⇧↩ | Paste as plain text (no formatting) |
| ⌘1 … ⌘9 | Paste item 1–9 directly |
| ⌘P | Pin / unpin (pinned items are kept forever and don't count toward the limit) |
| ⌘⌫ | Delete the item |
| Tab / ⇧Tab | Switch filter: All · Text · Images · Pinned |
| Esc | Clear the search, press again to close |
| ⌘, | Settings |

Right-click a row for the same actions plus "Copy Without Pasting".
Menu-bar icon: left-click opens the panel, right-click shows the menu (Keep Last, Pause Capturing,
Clear History…, Settings…, Quit).

**What is recorded:** text (with its formatting), images and screenshots. **Not recorded:** copies from
password managers (1Password, Bitwarden, Passwords, Keychain, anything marked as concealed), Finder file
copies, and anything copied while capturing is paused.

**Where it's stored:** `~/Library/Application Support/ClipStack/` (`history.json` + `blobs/`).

## Permissions

- **Accessibility** (System Settings › Privacy & Security › Accessibility): lets ClipStack press ⌘V for
  you. Without it, picking an item only copies it, and the panel footer shows a warning.
- **Paste from Other Apps** (Privacy & Security, macOS 15.4+): if macOS ever asks whether ClipStack may
  read the clipboard, choose Allow. Settings › Clipboard access shows the current state.

## Security & privacy

- **Nothing leaves your Mac.** No network code, no listening ports, no URL scheme, no AppleScript
  dictionary, no inter-process hooks (development hooks are compiled out of release builds), no third-party
  dependencies.
- **What it stores:** everything you copy, except password-manager copies (nspasteboard.org concealed/transient
  markers, plus Passwords, Keychain Access, 1Password and Bitwarden) and Finder file copies. History is kept
  unencrypted in `~/Library/Application Support/ClipStack` (folder readable only by you; FileVault protects it
  at rest). A program already running as you could read it, just as it could read the clipboard. For
  sensitive work: Pause Capturing, ⌘⌫ to delete an item, or keep the limit small.
- **Accessibility** is used only to press ⌘V after you pick an item. The app is signed with the hardened
  runtime, so other programs can't inject code into it to borrow that permission.
- **Pasting into Terminal** pastes exactly what was copied, like ⌘V does. Check commands copied from web pages
  before pasting them (they can hide extra lines).
- Copied images are decoded by macOS's own ImageIO to make thumbnails (the same decoder Preview uses).

## Troubleshooting

- **Paste stopped working after a rebuild / the Accessibility switch is on but nothing pastes:** the
  signature changed (ad-hoc build). Remove ClipStack from the Accessibility list with "–" and add it again,
  or run `tccutil reset Accessibility local.tools.ClipStack` and grant it again.
- **Menu-bar icon missing:** on a MacBook it may be hidden behind the notch, or switched off in
  System Settings › Menu Bar. The shortcut still works.
- **Shortcut does nothing:** another app may own it. Settings shows a red note; record a different one.
- **⇧⌘V conflicts:** it replaces "Paste and Match Style" in Chrome/Slack and "Markdown Preview" in VS Code.
  Use ⇧↩ in ClipStack for plain-text paste, or pick another shortcut.
- **Logs:** `log stream --style compact --predicate 'subsystem == "local.tools.ClipStack"'`
  (types and sizes only; clipboard contents are never logged).

## Development

```bash
swift test                                  # core unit tests (never touch the real clipboard)
scripts/install.sh                          # build + install + relaunch
scripts/fill-history.sh 15                  # copy "clip 01"… (overwrites the clipboard)
swift scripts/test-image.swift              # put a 1440×900 PNG on the clipboard
swift scripts/test-concealed.swift          # fake password-manager copy (must NOT be recorded)
swift scripts/make-icon.swift               # regenerate Resources/AppIcon.icns
```

Debug hooks (render the panel to PNG, set the query, toggle the panel from scripts) exist only in debug
builds: `CONFIG=debug scripts/install.sh`, `defaults write local.tools.ClipStack DebugHooks -bool YES`, relaunch,
then `swift scripts/debug-hook.swift <toggle|query|snapshot|settings> [arg]`. Run `scripts/install.sh` again
to go back to the release build.

Layout: `Sources/ClipStackCore` (capture rules, storage, eviction, search — unit-tested) and
`Sources/ClipStack` (AppKit app: panel, hotkey, paste, settings). Design notes and gotchas: `docs/PLAN.md`.

## Uninstall

Quit ClipStack, then:

```bash
rm -rf ~/Applications/ClipStack.app "$HOME/Library/Application Support/ClipStack"
defaults delete local.tools.ClipStack
tccutil reset Accessibility local.tools.ClipStack
```

and remove it from System Settings › General › Login Items if it's still listed.

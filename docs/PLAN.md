# ClipStack — personal clipboard history for macOS

> **Executor (Sonnet): read this whole file before writing any code.** Work phase by phase and stop at every ✅ checkpoint to verify before moving on. The section **"Rules that break the app if ignored"** is mandatory — every item there is a real failure mode.

## Context

The user switched from Windows to Mac ~2 years ago and misses **Win+V clipboard history**. The good Mac clipboard managers are paid. Goal: our own free, native, fast menu-bar app that remembers copied **text, images and ⌘⇧4 screenshots**, keeps a user-chosen number of items (**10 / 20 / 50 / 100**, oldest dropped first), opens with a global shortcut, and pastes the picked item straight into the app you were in.

Verified on this Mac (2026-11-22):

| Fact | Value | Consequence |
|---|---|---|
| macOS | 26.6 Tahoe, arm64 | Deployment target **macOS 26.0** → Liquid Glass (`NSGlassEffectView`) with no fallback code |
| Toolchain | Xcode 27.2, Swift 6.4.2, SDK 27.2 | SwiftPM builds; XCTest available |
| Screenshots | `defaults read com.apple.screencapture` → `target = clipboard` | ⌘⇧4 puts an image (PNG) on the pasteboard → captured like any copy |
| Code-signing identities | **none** | Needs a self-signed cert so permissions survive rebuilds (Step 0) |
| Keyboard layouts | ABC + **Bulgarian – Phonetic** | Match shortcuts by **key code**, never by typed character |
| Homebrew / XcodeGen | not installed | No external tools: plain SwiftPM + a shell script |
| Project folder | `~/Desktop/Projects Folder/Tools` (empty, not git, **path contains spaces**) | Create `Tools/ClipStack/`; quote every path in scripts |

FYI: Tahoe has a basic clipboard history inside Spotlight (⌘Space → ⌘4; off by default; keeps items by time, 30 min / 8 h / 7 days). It has no count limit, no pinning and no paste-into-app panel, so building ClipStack is still worth it.

## What v1 does

- **Captures** text (keeps plain + RTF + HTML so formatting survives a re-paste) and images (PNG/TIFF/JPEG/HEIC, including ⌘⇧4 screenshots). It does **not** capture Finder file copies (Win+V doesn't either) or anything copied from a password manager.
- **History size** 10 / 20 / 50 / 100 (default 50). When a new item goes over the limit, the oldest **unpinned** item and its files are deleted. Pinned items are kept forever and don't count toward the limit (same as Windows).
- **No duplicates**: copying something already in the history moves it to the top. Picking an item from the history also moves it to the top.
- **Saved to disk** in `~/Library/Application Support/ClipStack/`, so it survives quitting and rebooting. Images are files with small thumbnails, so memory stays around 30–80 MB.
- **Open** with **⇧⌘V** (changeable): a floating glass panel at the mouse cursor (or screen center), also over full-screen apps. Menu-bar icon: left-click opens the panel, right-click opens the menu.
- **Keys**: type to search (case- and accent-insensitive, Cyrillic works) · ↑↓ move · ↩ paste · ⇧↩ paste as plain text · ⌘1…⌘9 paste item N · click a row = paste · ⌘P pin/unpin · ⌘⌫ delete · Tab/⇧Tab switch filter (All · Text · Images · Pinned) · Esc clears the search, a second Esc closes · ⌘, Settings.
- **Paste** = put the item on the clipboard, close the panel, send ⌘V to the previous app. This needs the Accessibility permission. Without it (or in "copy only" mode) the item is only placed on the clipboard.
- **Menu**: Open History · Keep Last ▸ 10/20/50/100 · Pause Capturing · Clear History… · Settings… · Quit.
- **Settings**: history size, shortcut recorder, paste mode, panel position, capture text/images toggles, launch at login, Accessibility and clipboard-access status with fix buttons, storage used, Show in Finder, Clear History.

Panel sketch (440 × 560 pt):
```
╭────────────────────────────────────────────────╮
│ 🔍  Search clipboard…                           │
│ (All) (Text) (Images) (Pinned)                  │
├────────────────────────────────────────────────┤
│▌[Safari] const user = await fetch(`/api/u…  ⌘1 │ ← selected: accent tint
│▌         Safari · now · 143 chars               │
│ [Chrome] ┌───────────────┐                  ⌘2 │
│          │   thumbnail   │                      │
│          └───────────────┘                      │
│          Image · 1440×900 · 2.1 MB · 3m         │
│ [Notes]  Meeting notes for Monday…     📌   ⌘3 │
│          Notes · 1h · 1,204 chars               │
├────────────────────────────────────────────────┤
│ 12 of 50 · 3 pinned       ↩ Paste  ⇧↩ Plain  ⚙ │
╰────────────────────────────────────────────────╯
```

## Decisions already taken (all easy to change later)

| Topic | Decision |
|---|---|
| Name / bundle ID | **ClipStack** / `local.tools.ClipStack`. Rename only *before* the first install: changing the bundle ID later resets permissions, settings and the login item. |
| Shortcut | **⇧⌘V**, the usual Mac clipboard-manager default (Flycut, Clipy, Pastebot). It takes over "Paste and Match Style" in Chrome/Slack and "Markdown Preview" in VS Code; ClipStack's ⇧↩ covers plain-text paste. Changeable in Settings. |
| Default size | 50 |
| Click on a row | Pastes immediately (Win+V behaviour) |
| Minimum macOS | 26.0 (personal tool; enables Liquid Glass with no fallback branch) |
| Install location | `~/Applications/ClipStack.app` |
| Launch at login | Turned on at first launch, but only when running from an Applications folder |

## Step 0 — one-time setup by the USER (needed before Phase 5)

**Why:** macOS ties the Accessibility permission (and "Paste from Other Apps") to the app's code signature. Ad-hoc signing produces a new signature on every rebuild. System Settings then still shows ClipStack as ON, but auto-paste silently stops working. A self-signed certificate keeps the identity stable across rebuilds.

1. Open Keychain Access: `open -a "Keychain Access"` (on macOS 26 it lives in `/System/Library/CoreServices/Applications/`).
2. Menu **Keychain Access → Certificate Assistant → Create a Certificate…**
3. Name `ClipStack Dev` · Identity Type **Self-Signed Root** · Certificate Type **Code Signing** → Create → Done (goes into the login keychain).
4. Check: `security find-identity -p codesigning` lists `"ClipStack Dev"`. A `CSSMERR_TP_NOT_TRUSTED` note is fine for local signing.
5. The **first build that signs with it opens a Keychain dialog** ("codesign wants to use key…"). Enter the login password and click **Always Allow**. If Sonnet runs the build, the dialog appears on screen and the command waits until you click.
6. Only if codesign reports a trust error: double-click the cert → Trust → Code Signing: **Always Trust**.

Without the cert, `build.sh` falls back to ad-hoc signing and prints a warning. Accessibility then has to be re-granted after every rebuild: remove ClipStack from the list with "–" and add it again, or run `tccutil reset Accessibility local.tools.ClipStack`.

## Tech choices (why)

- **Swift + AppKit app lifecycle, SwiftUI only for the views** (inside `NSHostingView`/`NSHostingController`). Native means low memory, instant opening, and full access to `NSPasteboard`, global hotkeys and non-activating panels.
- **SwiftPM package + `scripts/build.sh`** that assembles `ClipStack.app`. No `.xcodeproj`: hand-written project files are fragile. `Package.swift` can still be opened in Xcode for editing.
- **Zero third-party packages.** Avoids network fetches and the SwiftPM resource-bundle crash (`Bundle.module`) in hand-assembled apps. The hotkey and recorder code needed is small and given below.
- **JSON index + blob files** (no Core Data / SwiftData). A few hundred items, easy to inspect.
- **Poll `NSPasteboard.general.changeCount` every 0.5 s.** macOS has no clipboard-changed notification; every clipboard manager does this, and it costs almost nothing.
- **Carbon `RegisterEventHotKey`** for the global shortcut. It needs no permission, unlike event taps or global monitors.
- **CGEvent ⌘V** for auto-paste. It's the only option and needs Accessibility.

## Project layout

```
Tools/ClipStack/
├── Package.swift
├── README.md
├── docs/PLAN.md                         ← copy of this plan (Phase 1)
├── Resources/Info.plist
├── Resources/AppIcon.icns               ← Phase 7
├── scripts/build.sh · install.sh · make-icon.swift · test-concealed.swift
├── Sources/ClipStackCore/               ← pure logic, unit-tested, no UI
│   ├── ClipItem.swift                   model (Codable)
│   ├── PasteboardReading.swift          protocol + NSPasteboard conformance
│   ├── ClipClassifier.swift             capture rules → CapturedClip?
│   ├── ImageProcessing.swift            ImageIO: normalize to PNG, thumbnail, pixel size
│   ├── Hashing.swift                    CryptoKit SHA-256
│   ├── HistoryPersistence.swift         history.json + blobs/, atomic + debounced
│   ├── HistoryStore.swift               ObservableObject: insert/dedup/evict/pin/delete
│   └── Search.swift                     filter + query matching
├── Sources/ClipStack/                   ← the app
│   ├── main.swift · AppDelegate.swift   wiring, single instance, SIGTERM, first run, actions
│   ├── Preferences.swift                UserDefaults-backed ObservableObject
│   ├── PasteboardMonitor.swift          timer, ignore own writes, source app
│   ├── CaptureProcessor.swift           background hashing / PNG / thumbnail
│   ├── PasteService.swift · KeySimulator.swift
│   ├── HotKeyManager.swift · Shortcut.swift
│   ├── Permissions.swift · LaunchAtLogin.swift · MainMenu.swift
│   ├── StatusItemController.swift
│   ├── Panel/  FloatingPanel · PanelController · HistoryViewModel · HistoryView · ClipRowView · SearchField · ThumbnailCache · AppIconCache
│   └── Settings/  SettingsWindowController · SettingsView · ShortcutRecorder
└── Tests/ClipStackCoreTests/  ClassifierTests · HistoryStoreTests · PersistenceTests · ImageProcessingTests
```

## Phases and checkpoints

**Phase 1 — Skeleton and build pipeline**
- `git init` inside `ClipStack/` (local only, never push). `.gitignore`: `.build/`, `build/`, `*.iconset/`, `.DS_Store`. Commit at every checkpoint.
- Copy this plan to `docs/PLAN.md`.
- `Package.swift`, `Info.plist`, `build.sh`, `install.sh` exactly as in **Build files** below.
- `main.swift` + `AppDelegate`: accessory policy, status item (SF Symbol `list.clipboard`, fallback `doc.on.clipboard`, template image) with a menu containing Quit, `MainMenu.install()`, single-instance guard, SIGTERM handler.
- ✅ `./scripts/install.sh` → menu-bar icon visible, **no Dock icon**, Quit works. `codesign -dv ~/Applications/ClipStack.app 2>&1 | grep Authority` shows `ClipStack Dev`, or the script printed the ad-hoc warning.

**Phase 2 — Core and unit tests** (only `ClipStackCore` + tests)
- `ClipItem`, `PasteboardReading`, `ClipClassifier`, `ImageProcessing`, `Hashing`, `HistoryPersistence`, `HistoryStore`, `Search`, per **Component specs**.
- ✅ `swift test` green (cases listed under Verification A).

**Phase 3 — Capture**
- `PasteboardMonitor` + `CaptureProcessor` feed `HistoryStore`. Log with `os.Logger` (types and sizes only).
- ✅ Verification B1–B5 pass, checked through `history.json` and `blobs/`.

**Phase 4 — Panel and hotkey**
- `FloatingPanel`, `PanelController`, `HistoryViewModel`, `HistoryView`, `ClipRowView`, `SearchField`, `ThumbnailCache`, `AppIconCache`, `HotKeyManager` (default ⇧⌘V), status-item left-click opens the panel below the icon.
- In this phase ↩ and click only **copy**; ⌘V comes in Phase 5.
- ✅ ⇧⌘V opens the panel at the cursor with the search field focused. Typing filters (try ABC and Bulgarian). ↑↓ keep the selection scrolled into view. Esc, a click outside, or ⇧⌘V again closes it. It also opens over a full-screen app.

**Phase 5 — Auto-paste** (Step 0 done first)
- `PasteService`, `KeySimulator`, Accessibility handling in `Permissions`, copy-only fallback, footer warning when the permission is missing.
- ✅ Verification C.

**Phase 6 — Settings, menu, first run**
- `SettingsWindowController` + `SettingsView` + `ShortcutRecorder`. Menu items: Keep Last submenu, Pause Capturing, Clear History…, Settings…. Confirmation before shrinking the limit, first-run welcome, `LaunchAtLogin`, clipboard-access status.
- ✅ Verification D.

**Phase 7 — Polish**
- App icon (`make-icon.swift` → `iconutil`), 0.12 s fade-in, empty states, right-click context menu on rows, README (usage, shortcuts, troubleshooting, uninstall).
- ✅ The whole Verification list.

## Build files (use as written)

**Package.swift**
```swift
// swift-tools-version: 5.10
// Keep 5.10. Tools-version 6.x switches to Swift 6 language mode → hundreds of strict-concurrency errors.
import PackageDescription

let package = Package(
    name: "ClipStack",
    platforms: [.macOS("26.0")],                 // string form: works with tools-version 5.10
    products: [.executable(name: "ClipStack", targets: ["ClipStack"])],
    targets: [
        .target(name: "ClipStackCore", path: "Sources/ClipStackCore"),
        .executableTarget(name: "ClipStack", dependencies: ["ClipStackCore"], path: "Sources/ClipStack"),
        .testTarget(name: "ClipStackCoreTests", dependencies: ["ClipStackCore"], path: "Tests/ClipStackCoreTests"),
    ]
)
```

**Resources/Info.plist**: keys `CFBundleExecutable=ClipStack` (must equal the product name), `CFBundleIdentifier=local.tools.ClipStack`, `CFBundleName`/`CFBundleDisplayName=ClipStack`, `CFBundlePackageType=APPL`, `CFBundleShortVersionString=1.0.0`, `CFBundleVersion=1`, `CFBundleIconFile=AppIcon`, `CFBundleInfoDictionaryVersion=6.0`, `CFBundleDevelopmentRegion=en`, `LSMinimumSystemVersion=26.0`, **`LSUIElement=true`** (no Dock icon), `NSHighResolutionCapable=true`, `NSPrincipalClass=NSApplication`. No entitlements file, **no App Sandbox, no hardened runtime**.

**scripts/build.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # path has spaces → quote everything
APP_NAME="ClipStack"
SIGN_ID="${SIGN_ID:-ClipStack Dev}"
cd "$ROOT"
swift build -c release --product "$APP_NAME"
BIN="$(swift build -c release --show-bin-path)/$APP_NAME"
APP="$ROOT/build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"; fi
plutil -lint "$APP/Contents/Info.plist" >/dev/null
if security find-identity -p codesigning | grep -q "\"$SIGN_ID\""; then
  codesign --force --timestamp=none --sign "$SIGN_ID" "$APP"
else
  echo "WARNING: signing identity \"$SIGN_ID\" not found → ad-hoc signature." >&2
  echo "         Accessibility must be re-granted after every rebuild (PLAN Step 0)." >&2
  codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP"
echo "Built $APP"
```

**scripts/install.sh**: build, quit the running copy, replace, relaunch, keep only one copy on disk.
```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ClipStack"; DEST="$HOME/Applications"
"$ROOT/scripts/build.sh"
if pgrep -x "$APP_NAME" >/dev/null; then
  pkill -TERM -x "$APP_NAME" || true            # app turns SIGTERM into a normal terminate → history flushed
  for _ in {1..30}; do pgrep -x "$APP_NAME" >/dev/null || break; sleep 0.1; done
  pkill -KILL -x "$APP_NAME" 2>/dev/null || true
fi
mkdir -p "$DEST"
rm -rf "$DEST/$APP_NAME.app"
ditto "$ROOT/build/$APP_NAME.app" "$DEST/$APP_NAME.app"
rm -rf "$ROOT/build/$APP_NAME.app"               # one copy only: avoids launching the wrong one / duplicate Spotlight hits
open "$DEST/$APP_NAME.app"                        # ALWAYS launch via `open` (see Rules)
echo "Installed $DEST/$APP_NAME.app"
```

**main.swift**
```swift
import AppKit
let delegate = AppDelegate()            // global: NSApplication.delegate is weak, a local could be freed early
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
```

## Component specs

### Capture rules (`ClipClassifier`), applied in this order on every changeCount change
1. No types → ignore.
2. Any of these types present → ignore (password managers and transient data, nspasteboard.org convention): `org.nspasteboard.ConcealedType`, `org.nspasteboard.TransientType`, `org.nspasteboard.AutoGeneratedType`, `com.agilebits.onepassword`, `de.petermaurer.TransientPasteboardType`, `com.typeit4me.clipping`, `Pasteboard generator type`.
3. Source app bundle ID in the ignore list → ignore: `com.apple.keychainaccess`, `com.apple.Passwords`, `com.1password.1password`, `com.agilebits.onepassword7`, `com.bitwarden.desktop`.
4. `public.file-url` present → ignore. A Finder file copy also carries the file's **icon as TIFF**, which must never be stored as an "image".
5. text = `public.utf8-plain-text` (NSPasteboard converts other string flavours automatically); counts only if it isn't whitespace-only. image = first present of `public.png`, `public.tiff`, `public.jpeg`, `public.heic`.
6. **Text wins over image**, unless the text is a single URL (`http(s)://` or `file://`, no whitespace), e.g. Safari "Copy Image". Reason: Excel/Numbers/Word/Keynote copy a *picture* of the selection next to the text, and we want the text.
7. Caps: text ≤ 5 MB; RTF/HTML ≤ 5 MB each (drop only that flavour if bigger); image ≤ 50 MB raw. Over the cap → ignore.
8. Respect the "Capture text" / "Capture images" settings.

`PasteboardReading` protocol: `availableTypes: [String]`, `readString(type:)`, `readData(type:)`. Use these names; overloading `string(forType:)` with `String` causes ambiguity or recursion. `NSPasteboard` conforms; tests use a fake struct.

**Source app** = the `org.nspasteboard.source` string if present, else `NSWorkspace.shared.frontmostApplication`. This is correct because our panel never activates our app.

### Processing (`CaptureProcessor`, background serial queue → result back on main)
- Text: hash, `previewText` = first 300 chars (row display), `searchText` = first 10 000 chars, `charCount`.
- Image: hash of the **raw** bytes, normalized PNG, pixel size, thumbnail PNG (max 720 px), then `ThumbnailCache.insert` so the row renders without a disk read.
- Hash = `"t:" + sha256(utf8 text)` / `"i:" + sha256(raw image bytes)` via CryptoKit.
- `ImageProcessing` uses ImageIO only: `CGImageSourceCreateWithData`; pick the largest image index (TIFFs can hold 1x and 2x); if already PNG keep the original bytes; else `CGImageDestinationAddImageFromSource` into a PNG destination (keeps DPI and color profile, so Retina screenshots paste at the right size). Thumbnail: `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceCreateThumbnailFromImageAlways: true`, `kCGImageSourceThumbnailMaxPixelSize: 720`, `kCGImageSourceCreateThumbnailWithTransform: true`.

### `ClipItem` (Codable, Identifiable, Hashable)
`id: UUID`, `kind: ClipKind (.text/.image)`, `createdAt`, `lastUsedAt` (sort key, newest first), `isPinned`, `contentHash`, `previewText?`, `searchText?`, `charCount?`, `hasRTF`, `hasHTML`, `pixelWidth?`, `pixelHeight?`, `byteSize`, `sourceBundleID?`, `sourceAppName?`. **Any field added after v1 must be Optional** so old files still decode.

### Persistence (`HistoryPersistence(baseURL:)`)
```
~/Library/Application Support/ClipStack/
  history.json      {"version":1,"items":[ClipItem…]}   ← small, never holds blobs
  blobs/<uuid>.txt | .rtf | .html | .png | -thumb.png
```
- `baseURL` is injected; tests use a temp dir, never the real one.
- Index writes: debounced 0.3 s on a serial queue, `Data.write(to:options: .atomic)`, `JSONEncoder` **default date strategy** (ISO 8601 drops sub-second precision and breaks ordering). `flush()` writes synchronously and is called from `applicationWillTerminate`.
- Blob reads go through the same serial queue (`queue.sync`), so a paste right after a capture waits for the write to finish.
- Load: missing file → empty. Decode error → rename it to `history.corrupt-<unix-time>.json` and start empty (never crash). Drop items whose main blob is missing. Delete files in `blobs/` that no item references (crash leftovers).

### `HistoryStore` (ObservableObject, main-thread only)
Don't annotate it `@MainActor` (keeps XCTest simple); add `dispatchPrecondition(condition: .onQueue(.main))` in mutating methods.
- `@Published private(set) var items`, sorted by `lastUsedAt` desc. Pinned items stay in place, Windows-style; the Pinned filter lists them.
- `insertOrBump`: an item with the same `contentHash` exists → `lastUsedAt = now`, re-sort, save. Else write blobs, insert at the top, evict.
- **Eviction runs only on insert and on limit change**: keep the newest `limit` unpinned items, delete the rest and their blobs. Unpinning does not evict right away (otherwise an item could vanish the moment you unpin it).
- Also: `bump(id)`, `togglePin(id)`, `delete(id)`, `clearUnpinned()`, `clearAll()`, `setLimit(_:)`, `evictionCount(forLimit:)` (for the confirmation), `totalBytes`, `flush()`.

### Pasteboard monitor
```swift
private var lastChangeCount = -1            // -1 → the current clipboard is captured once at launch (dedup handles repeats)
private var ownWrites = Set<Int>()          // changeCounts produced by PasteService
func markOwnWrite(_ changeCount: Int) { ownWrites.insert(changeCount) }   // called by PasteService right after writing
func start() {
    let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
    t.tolerance = 0.1
    RunLoop.main.add(t, forMode: .common)   // .common: keeps firing while a menu is open
    timer = t
}
private func tick() {
    let count = NSPasteboard.general.changeCount
    guard count != lastChangeCount else { return }
    lastChangeCount = count
    if ownWrites.remove(count) != nil { return }          // our own paste: not a new clip
    guard !isPaused else { return }
    let source = SourceApp.detect(NSPasteboard.general)   // needed by rule 3 (app ignore list)
    guard let clip = ClipClassifier.classify(NSPasteboard.general, sourceBundleID: source.bundleID,
                                             rules: currentRules()) else { return }
    processor.process(clip, source: source)
}
```
Only `changeCount` is read on every tick. Contents are read only after a change, because on macOS 15.4+ reading contents is what may trigger the "Paste from Other Apps" privacy alert.

### The panel
```swift
final class FloatingPanel: NSPanel {
    var onResignKey: (() -> Void)?
    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],   // .nonactivatingPanel must be set HERE, not later
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .clear; isOpaque = false; hasShadow = true
        animationBehavior = .none
    }
    override var canBecomeKey: Bool { true }    // borderless windows can't become key by default → typing would go nowhere
    override var canBecomeMain: Bool { false }
    override func resignKey() { super.resignKey(); onResignKey?() }
}
```
Content: `NSGlassEffectView` (`style = .regular`, `cornerRadius = 22`) as `panel.contentView`; its `contentView` = `NSHostingView(rootView: HistoryView(...))` with `frame = glass.bounds` and `autoresizingMask = [.width, .height]`. Clip the SwiftUI root with `.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))`. Keep row backgrounds translucent so the glass shows through.
Fallback only if glass looks wrong: `NSVisualEffectView` with `material = .popover`, `blendingMode = .behindWindow`, **`state = .active`** (otherwise it renders grey because our app is never active), `layer.cornerRadius = 22`, `masksToBounds = true`.

`PanelController.show()`:
```swift
previousApp = NSWorkspace.shared.frontmostApplication
if previousApp?.processIdentifier == ProcessInfo.processInfo.processIdentifier { previousApp = nil } // Settings was in front → copy only
viewModel.prepareForShow()          // query = "", filter = .all, selection = 0, focusRequest += 1
positionPanel()                     // anchor: mouse / screen center / below status item
panel.alphaValue = 0
panel.orderFrontRegardless()
panel.makeKey()                     // NEVER NSApp.activate here: the previous app must stay active so ⌘V lands there
panel.invalidateShadow()
NSAnimationContext.runAnimationGroup { $0.duration = 0.12; panel.animator().alphaValue = 1 }
installKeyMonitor()
```
`hide()`: remove the key monitor, `orderOut(nil)`, store `lastHideTime`. **Close triggers**: `onResignKey`, Esc, the hotkey again, after a pick, ⌘,.
**Toggle debounce**: if the panel was hidden by resignKey less than 0.25 s ago, a status-item click must not reopen it. Otherwise clicking the icon to close it makes it reappear.

Positioning (AppKit coordinates: origin is **bottom-left**; `NSEvent.mouseLocation` is global):
```swift
let size = panel.frame.size, mouse = NSEvent.mouseLocation
let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
guard let vf = screen?.visibleFrame else { return }
var o: NSPoint
switch anchor {
case .mouse:           o = NSPoint(x: mouse.x - 24, y: mouse.y - size.height + 12)        // top-left just above the cursor
case .center:          o = NSPoint(x: vf.midX - size.width / 2, y: vf.midY - size.height / 2 + vf.height * 0.08)
case .statusItem(let r): o = NSPoint(x: r.midX - size.width / 2, y: r.minY - size.height - 6)  // r = button frame in screen coords
}
o.x = min(max(o.x, vf.minX + 8), vf.maxX - size.width - 8)
o.y = min(max(o.y, vf.minY + 8), vf.maxY - size.height - 8)
panel.setFrameOrigin(o)
```

**Search field** = `NSViewRepresentable` around `NSTextField` (`isBordered = false`, `isBezeled = false`, `drawsBackground = false`, `focusRingType = .none`, 17 pt system font, placeholder "Search clipboard…", single line). Its coordinator's `controlTextDidChange` writes the binding. `updateNSView` sets `stringValue` only when it differs, and when `focusRequest` changed it calls `DispatchQueue.main.async { field.window?.makeFirstResponder(field) }`. Don't use SwiftUI `TextField` + `@FocusState`: focus is unreliable in a non-activating panel, and `onAppear` doesn't refire because the hosting view is reused.

**List**: `ScrollViewReader` + `ScrollView` + `LazyVStack(spacing: 2)` + `ForEach(Array(vm.visible.enumerated()), id: \.element.id)`. Use `.onChange(of: vm.selectedIndex) { _, new in proxy.scrollTo(vm.visible[new].id) }` with a bounds check (anchor `nil` = minimal scroll). Rows get `.contentShape(Rectangle())` before `.onTapGesture` (otherwise clicks on empty row areas are ignored) and `.onHover` for a subtle highlight. Don't use SwiftUI `List`: its own selection and focus handling fight our keyboard control.

**HistoryViewModel**: `query`, `filter`, `visible`, `selectedIndex`, `focusRequest`. It subscribes to `store.$items`. **Use the value passed to the sink, not `store.items`**: `@Published` emits *before* the property changes. After a store change, keep the selection on the same item id if it's still visible, else clamp. Changing the query or filter resets the selection to 0. Search: split the query on whitespace; every word must match `searchText` or `sourceAppName` with `.caseInsensitive` + `.diacriticInsensitive`.

**Row design** (13 pt preview, 11 pt meta): leading 28×28 tile with the source-app icon (`AppIconCache`: `NSWorkspace.urlForApplication(withBundleIdentifier:)` → `icon(forFile:)`, cached), falling back to SF Symbol `doc.text` / `photo`. Text: `previewText`, `lineLimit(3)`. Image: thumbnail, aspect-fit, max height 120, corner radius 8, 0.5 pt hairline. Meta line: `Safari · 2m · 143 chars` or `Image · 1440×900 · 2.1 MB · 3m`. Trailing: `⌘1…⌘9` badge (monospaced, secondary) on the first nine rows, `pin.fill` when pinned. Selected row: rounded 12 pt background `accentColor.opacity(0.22)`; hover `primary.opacity(0.06)`. Compact relative time: now / 5m / 3h / Yesterday / Mon / 12 Mar. Thumbnails load via `.task(id: item.id)` from `ThumbnailCache` (`NSCache` + background disk read). **Never decode full-size images for rows.**

**Footer**: `12 of 50 · 3 pinned`, key hints, gear button (opens Settings). When the mode is auto-paste and Accessibility is missing, show a warning chip "Paste needs Accessibility" that opens Settings.
**Empty states**: "Nothing here yet — copy some text or take a screenshot (⌘⇧4)". No search results: `No matches for "…"`.

### Keyboard map
A local monitor runs while the panel is visible. Match on `keyCode` (layout-independent, so it works on Bulgarian). Return `nil` to swallow an event, or the event to let it reach the search field.
```swift
keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
    MainActor.assumeIsolated {
        guard let self, e.window === self.panel else { return e }
        return self.handleKey(e) ? nil : e
    }
}
```
| Key | Code (Carbon `kVK_…`) | Action |
|---|---|---|
| ↓ / ↑ | `kVK_DownArrow` / `kVK_UpArrow` | move selection |
| ↩ / keypad Enter | `kVK_Return` / `kVK_ANSI_KeypadEnter` | paste selected (⇧ held → plain text) |
| Esc | `kVK_Escape` | clear query, or hide if the query is already empty |
| Tab / ⇧Tab | `kVK_Tab` | next / previous filter |
| ⌘⌫ | `kVK_Delete` + ⌘ | delete selected |
| ⌘P | `kVK_ANSI_P` + ⌘ | pin / unpin selected |
| ⌘, | `kVK_ANSI_Comma` + ⌘ | hide, open Settings |
| ⌘1…⌘9 | `[kVK_ANSI_1, kVK_ANSI_2, … kVK_ANSI_9]` | paste visible item N. **The codes are NOT sequential** (0x12, 0x13, 0x14, 0x15, 0x17, 0x16, 0x1A, 0x1C, 0x19); use an array lookup, never arithmetic |
| anything else | – | pass through (typing; ⌘A/⌘C/⌘V/⌘X/⌘Z come from the hidden Edit menu) |

### Global hotkey (Carbon, no permission needed)
```swift
import Carbon.HIToolbox
final class HotKeyManager {                     // not @MainActor: called from a C callback
    static let shared = HotKeyManager()
    var onPressed: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    @discardableResult
    func register(keyCode: UInt32, carbonModifiers: UInt32) -> Bool {
        unregister(); installHandlerIfNeeded()
        let id = EventHotKeyID(signature: OSType(0x434C5354), id: 1)        // 'CLST'
        let status = RegisterEventHotKey(keyCode, carbonModifiers, id, GetEventDispatcherTarget(), 0, &hotKeyRef)
        return status == noErr
    }
    func unregister() { if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }; hotKeyRef = nil }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, _, userData in      // C callback: cannot capture → use userData
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.onPressed?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }
}
```
- Carbon modifier masks are **not** NSEvent flags: `cmdKey = 0x100`, `shiftKey = 0x200`, `optionKey = 0x800`, `controlKey = 0x1000`. Default shortcut: keyCode `kVK_ANSI_V` (9), modifiers `UInt32(cmdKey | shiftKey)` (0x300), display `⇧⌘V`.
- `Shortcut` struct (Codable, stored in UserDefaults as JSON): `keyCode`, `carbonModifiers`, `display`. Display = modifier symbols in the fixed order **⌃ ⌥ ⇧ ⌘** + key name. Key name comes from a **static keyCode → name table**: `kVK_ANSI_A…Z`, `0…9`, punctuation, plus Space, ↩, ⇥, ⌫, ⌦, ⎋, ←→↑↓, ↖ ↘ ⇞ ⇟, and F1–F20 via the `kVK_F*` constants (also non-sequential). Don't derive names from typed characters: on the Bulgarian layout that would display Cyrillic.
- If registering fails at launch (taken by another app), open Settings showing "Shortcut unavailable — pick another".

**ShortcutRecorder** (SwiftUI button, "Press shortcut…" while recording): on start, `HotKeyManager.shared.unregister()` so pressing the current combo doesn't open the panel, then add a local keyDown monitor. Esc cancels. Require ⌘, ⌃ or ⌥ (or an F-key), otherwise beep. Try `register`; on failure show "Shortcut unavailable" and re-register the old one. Always remove the monitor and re-register a shortcut on stop, cancel and `onDisappear`.

### Auto-paste
```swift
func pick(_ item: ClipItem, plainText: Bool) {
    guard pasteService.write(item, plainTextOnly: plainText) else { NSSound.beep(); return }
    let target = previousApp
    hide()
    guard prefs.pasteMode == .autoPaste, target != nil, AXIsProcessTrusted() else { return }   // copy-only fallback
    let wasActive = NSApp.isActive
    if wasActive { NSApp.hide(nil) }                       // shouldn't happen with a non-activating panel; safety net
    DispatchQueue.main.asyncAfter(deadline: .now() + (wasActive ? 0.15 : 0.05)) { KeySimulator.pressCommandV() }
}

enum KeySimulator {                                         // requires Accessibility
    static func pressCommandV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        src?.setLocalEventsFilterDuringSuppressionState([.permitLocalMouseEvents, .permitSystemDefinedEvents],
                                                        state: .eventSuppressionStateSuppressionInterval)
        let v = CGKeyCode(kVK_ANSI_V)                       // physical V; ⌘-shortcuts on Bulgarian use the Latin layout
        let flags = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x000008)  // + left-⌘ device bit; some apps check it
        let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
        down?.flags = flags; up?.flags = flags
        down?.post(tap: .cgSessionEventTap); up?.post(tap: .cgSessionEventTap)
    }
}
```
`PasteService.write`: build one `NSPasteboardItem`. Text → `.rtf` and `.html` (unless plain-only) + `.string`. Image → `.png` + `.tiff` (`NSBitmapImageRep(data: png)?.tiffRepresentation(using: .lzw, factor: 0)`, for apps that only read TIFF). Then `clearContents()`, `writeObjects([item])`, **`monitor.markOwnWrite(pb.changeCount)` with the count read after the write**, `store.bump(id)`. Known limit: Dvorak would need a layout lookup for V; not needed for ABC/Bulgarian.

### Settings window
```swift
func show(welcome: Bool = false) {
    if window == nil {
        let host = NSHostingController(rootView: SettingsView(/* deps */))
        host.sizingOptions = [.preferredContentSize]
        let w = NSWindow(contentViewController: host)
        w.title = "ClipStack Settings"
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.isReleasedWhenClosed = false          // else reopening after close crashes
        w.center()
        window = w
    }
    NSApp.activate()                            // accessory app: without this the window opens behind others
    window?.makeKeyAndOrderFront(nil)
}
```
`SettingsView`: SwiftUI `Form` with `.formStyle(.grouped)`, width 480. Sections:
1. Welcome banner (first run only): "Press ⇧⌘V anytime to open your clipboard history."
2. **History**: segmented Picker *Keep last* 10/20/50/100; caption "Pinned items are kept and don't count"; "23 items · 48 MB"; buttons Show in Finder, Clear History….
3. **Shortcut**: recorder + Reset to ⇧⌘V.
4. **Pasting**: radio "Paste into the active app" / "Only copy to the clipboard"; Accessibility row "Granted ✓" or "Not granted" + **Grant Access…**, which calls the prompt and then opens the pane.
5. **Clipboard access** from `NSPasteboard.general.accessBehavior`: `.default`/`.alwaysAllow` → "Allowed"; `.ask` → "macOS will ask — set ClipStack to Allow in Privacy & Security › Paste from Other Apps"; `.alwaysDeny` → red "Blocked — nothing can be recorded" + Open Privacy & Security; `@unknown default` → like `.default`.
6. **Capture**: toggles Text, Images & screenshots.
7. **General**: Launch at login toggle (show "Needs approval in Login Items" when `.requiresApproval`, with a button to `SMAppService.openSystemSettingsLoginItems()`), *Open at*: Mouse cursor / Screen center. Footer: version + Quit.
While Settings is visible, refresh Accessibility and clipboard-access status every 1 s (Timer, invalidated on close).

**Limit change** (Settings picker and the menu submenu both call one method). Inside a SwiftUI binding setter, wrap the call in `DispatchQueue.main.async`: running a modal alert during a view update misbehaves.
```swift
func requestLimitChange(to n: Int) {
    let removed = store.evictionCount(forLimit: n)
    if removed > 0 {
        NSApp.activate()
        let a = NSAlert()
        a.messageText = "Keep only the last \(n) items?"
        a.informativeText = "The \(removed) oldest unpinned items will be deleted. Pinned items are kept."
        a.alertStyle = .warning
        a.addButton(withTitle: "Delete \(removed) Items"); a.addButton(withTitle: "Cancel")
        guard a.runModal() == .alertFirstButtonReturn else { prefs.objectWillChange.send(); return }  // picker snaps back
    }
    prefs.historyLimit = n; store.setLimit(n)
}
```
"Clear History…" uses the same alert pattern (clears unpinned only).

### Menu-bar item
```swift
statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
statusItem.button?.image = (NSImage(systemSymbolName: "list.clipboard", accessibilityDescription: "ClipStack")
                            ?? NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipStack"))
statusItem.button?.image?.isTemplate = true
statusItem.button?.target = self
statusItem.button?.action = #selector(clicked(_:))
statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

@objc func clicked(_ sender: NSStatusBarButton) {
    let e = NSApp.currentEvent
    if e?.type == .rightMouseUp || e?.modifierFlags.contains(.control) == true {
        statusItem.menu = menu; sender.performClick(nil); statusItem.menu = nil   // show menu only on right-click
    } else {
        panelController.toggle(anchor: .statusItem(sender.window!.convertToScreen(sender.convert(sender.bounds, to: nil))))
    }
}
```
Pause Capturing toggles `monitor.isPaused` and `statusItem.button?.appearsDisabled`. It is **not** persisted, so a restart never leaves capture silently off. Keep Last submenu items get a checkmark on the current value.

### Hidden main menu (`MainMenu.install()`)
An `LSUIElement` app has no visible menu bar, but **⌘C/⌘V/⌘X/⌘A/⌘Z in text fields only work through `NSApp.mainMenu` items**. Build an app menu (Settings… ⌘, → `openSettings`, Quit ⌘Q → `NSApplication.terminate(_:)`), an Edit menu (Undo `undo:` ⌘Z, Redo `redo:` ⇧⌘Z, Cut `NSText.cut(_:)`, Copy `NSText.copy(_:)`, Paste `NSText.paste(_:)`, Select All `NSText.selectAll(_:)`), and Close Window ⌘W → `performClose:`. If ⌘V still does nothing in the panel's search field, map ⌘A/⌘C/⌘V/⌘X in the panel key monitor to `NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)` etc.

### Permissions, login item, lifecycle
```swift
static var accessibilityGranted: Bool { AXIsProcessTrusted() }               // updates live; no relaunch needed
static func requestAccessibility() {                                          // system prompt + adds ClipStack to the list
    let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String     // Unmanaged<CFString> → must unwrap
    _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
}
// Deep links: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
//             "x-apple.systempreferences:com.apple.preference.security"   (then "Paste from Other Apps")
static func setLaunchAtLogin(_ on: Bool) throws {                            // if/else: `try` inside a ?: doesn't compile
    if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
}
```
- **Single instance**: in `applicationDidFinishLaunching`, if `NSRunningApplication.runningApplications(withBundleIdentifier:)` contains another process, terminate yourself (a second copy couldn't register the hotkey anyway).
- **SIGTERM** → normal quit: `signal(SIGTERM, SIG_IGN)`, then a `DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)` whose handler calls `NSApp.terminate(nil)`. **Keep a strong reference** to the source.
- `applicationWillTerminate` → `store.flush()`. `applicationShouldHandleReopen` (app opened again from Finder or Spotlight) → open Settings, so launching it again visibly does something.
- **First run** (`hasLaunchedBefore == false`): set the flag. Enable launch at login only if `Bundle.main.bundleURL.path` starts with `/Applications/` or `~/Applications/`. Open Settings with the welcome banner.
- `Preferences` keys: `historyLimit` (validate it's in [10, 20, 50, 100], else 50), `shortcut` (JSON), `pasteMode` (autoPaste|copyOnly), `panelPosition` (mouse|center), `captureText`, `captureImages`, `hasLaunchedBefore`. Call `UserDefaults.standard.register(defaults:)` at init.
- Logging: `Logger(subsystem: "local.tools.ClipStack", category: …)`. Log decisions, types and byte sizes. **Never log clipboard contents.**

## Rules that break the app if ignored

1. **No SwiftUI `App`/`Scene`/`MenuBarExtra`/`Settings` scene.** Use the AppKit lifecycle (`main.swift` + `NSApplicationDelegate`). Opening a SwiftUI Settings scene from an accessory app is blocked or flaky on macOS 14+.
2. **`swift-tools-version: 5.10`**, not 6.x (Swift 6 mode = strict-concurrency errors). Mark app-target UI classes `@MainActor`. For AppKit callbacks that run on main (Timer on the main run loop, local NSEvent monitors), wrap calls in `MainActor.assumeIsolated { }`.
3. **No third-party packages, no SwiftData/Core Data, no `@Observable`.** Use Codable JSON and `ObservableObject`/`@Published`.
4. **Always launch the app with `open …/ClipStack.app`**, never by running `Contents/MacOS/ClipStack` from a shell. Otherwise macOS attributes the Accessibility permission to the terminal instead of ClipStack.
5. **Stable signing identity** (Step 0). Symptom when it's wrong: Accessibility toggle is ON but paste doesn't work.
6. **Keep the bundle ID `local.tools.ClipStack` forever.** Permissions, settings and the login item are keyed to it.
7. **`.nonactivatingPanel` passed in the panel initializer**, `canBecomeKey` overridden to `true`, and **never `NSApp.activate()` when showing the panel**. This is what keeps the target app active so ⌘V lands in it. `NSApp.activate()` is only for the Settings window and alerts.
8. **Use `orderFrontRegardless()` + `makeKey()`**: plain `makeKeyAndOrderFront` can fail to front a window of an inactive app.
9. **Keyboard handling through one local NSEvent monitor**, installed on show and removed on hide (a leaked monitor double-handles keys). Match **key codes**; ⌘1–9 codes are not sequential.
10. **Search field = `NSTextField` via `NSViewRepresentable`**, focused with `makeFirstResponder` after showing.
11. **Hidden main menu with an Edit menu**, or copy/paste/select-all won't work in any text field.
12. **Programmatic windows: `isReleasedWhenClosed = false`.**
13. **Timers in `RunLoop.main` `.common` mode.** Read pasteboard **contents only when `changeCount` changed**, and record our own writes' changeCount so they're not re-captured.
14. **Skip concealed/transient types and `public.file-url`.** Text beats image unless the text is a lone URL.
15. **Carbon modifiers ≠ NSEvent flags** (table above). The C callback gets context via `userData`. Unregister the hotkey while recording a new one.
16. **No `NSEvent.addGlobalMonitorForEvents` / CGEventTap for the hotkey** (needs Input Monitoring and is fragile). The app needs **no** Screen Recording or Input Monitoring permission; don't add any.
17. **Auto-paste needs Accessibility.** Check `AXIsProcessTrusted()` before posting, and fall back to copy-only. Use `kAXTrustedCheckOptionPrompt.takeUnretainedValue()`.
18. **Thumbnails are generated once at capture (ImageIO) and cached.** Never load full images into the list.
19. **Atomic, debounced JSON writes; flush on terminate; corrupt-file recovery; orphan sweep.** Store and persistence take an injectable base directory.
20. **Tests must never touch `NSPasteboard.general`** (it wipes the user's real clipboard). Use a fake `PasteboardReading` or `NSPasteboard(name: .init("ClipStackTests-\(UUID().uuidString)"))` + `releaseGlobally()`, and temp dirs.
21. **Quote every path in scripts** (`Projects Folder` has a space). Use `if … then … fi` instead of `[[ ]] && cmd` under `set -e`.
22. **Do not enable App Sandbox or hardened runtime.** Sandboxed apps can't post CGEvents, and neither is needed locally.
23. **Don't create certificates, change TCC permissions or approve dialogs yourself.** Ask the user (Step 0, Accessibility toggle, Keychain "Always Allow", "Paste from Other Apps").
24. `@Published` sinks get the new value *before* the property updates: use the closure parameter.
25. On a `kill -TERM`, quit through `NSApp.terminate` (SIGTERM source), or the last capture may be lost.

## Verification

**A. Automated** — `swift test` from `Tools/ClipStack`:
- Classifier: concealed / transient → nil; file-url + TIFF icon → nil; text only → text; PNG only → image(png); TIFF only → image(tiff); text + TIFF (Excel-like) → text; URL text + TIFF → image; whitespace-only → nil; text > 5 MB → nil; images disabled + PNG → nil; RTF/HTML kept, oversized RTF dropped.
- Store: limit 10 + 12 inserts → newest 10 remain and the 2 oldest blobs are gone; pinned items survive and don't count; duplicate bumps to top without growing; `setLimit` 50→10 evicts; `evictionCount` correct; `clearUnpinned` keeps pins; `delete` removes blobs.
- Persistence: save/load round-trip; corrupt file → renamed + empty; orphan sweep; item with missing blob dropped.
- ImageProcessing (test images drawn with CGContext): TIFF→PNG output starts with `89 50 4E 47`; thumbnail ≤ 720 px; pixel size correct.
- Real *named* pasteboard: write string + PNG, classify through the NSPasteboard conformance, `releaseGlobally()`.

**B. Capture** (app installed; logs: `log stream --style compact --predicate 'subsystem == "local.tools.ClipStack"'` in a separate terminal or as a background task). Note: these commands overwrite the real clipboard.
1. Limit 10, then `for i in $(seq 1 15); do printf "clip %02d" "$i" | pbcopy; sleep 0.8; done` (put it in `scripts/fill-history.sh` if the shell tool refuses inline `sleep`) → panel shows clip 15 … clip 06; `ls ~/Library/Application\ Support/ClipStack/blobs | grep -c '\.txt$'` → 10.
2. ⌘⇧4 a region → image row with thumbnail and correct pixel size; `blobs/<id>.png` and `<id>-thumb.png` exist.
3. Copy the same text twice → one entry, at the top.
4. `swift scripts/test-concealed.swift` (writes "pretend-secret" with `org.nspasteboard.ConcealedType`) → **not** captured. Finder ⌘C on a file → not captured. Numbers/Excel cells → a text item.
5. Quit + relaunch → items and pins intact.

**C. Paste** (Accessibility granted)
1. TextEdit, cursor in a document → ⇧⌘V → ↓ → ↩ → the 2nd item is pasted; TextEdit stays frontmost; panel gone.
2. Rich text from Safari: ↩ keeps formatting in a rich TextEdit doc, ⇧↩ pastes plain.
3. A screenshot pastes into TextEdit / Notes / Slack. ⌘3 pastes the 3rd item directly. A click on a row pastes.
4. Switch to **Bulgarian – Phonetic**: ⇧⌘V, ↩, ⌘P, ⌘⌫, ⌘1 still work; Cyrillic search works.
5. Over a full-screen app: the panel appears and paste works.
6. Turn Accessibility off → ↩ only copies, the footer warns, Settings shows "Not granted".
7. Rebuild with `install.sh` → paste still works **without re-granting** (proves Step 0).

**D. Settings and menu**
1. 30 items, limit 100 → 10: alert says 20 will be deleted. Cancel keeps everything and the picker snaps back; Confirm trims to 10.
2. Record ⌥⌘V → works at once and ⇧⌘V is dead; survives relaunch; Reset restores ⇧⌘V.
3. Launch at login ON → listed in System Settings › General › Login Items; after a reboot the app is running.
4. Pause → copies aren't recorded and the icon is dimmed; Resume works. Clear History… keeps pinned items.
5. Optional privacy simulation: `defaults write local.tools.ClipStack EnablePasteboardPrivacyDeveloperPreview -bool yes`, relaunch, copy → macOS asks → Settings shows the matching status; then `defaults delete local.tools.ClipStack EnablePasteboardPrivacyDeveloperPreview`.

**E. Robustness**
- `ps -o rss= -p "$(pgrep -x ClipStack)"` stays under ~100 MB with 100 items including screenshots; opening and closing the panel 30× shows no steady growth.
- `kill -TERM "$(pgrep -x ClipStack)"` right after a copy → the copy is still there after relaunch.
- Light and dark mode both legible on glass. If the computer-use tool is available, screenshot the panel to check; otherwise ask the user.

## Phase 7 details
- `scripts/make-icon.swift` (run with `swift scripts/make-icon.swift`): draw a 1024 px canvas with an 824 px continuous rounded rect (radius ≈ 185, macOS icon grid), a gradient fill and a white SF Symbol `list.clipboard.fill`. Write `AppIcon.iconset/` with **exactly** `icon_16x16.png, icon_16x16@2x.png, icon_32x32.png, icon_32x32@2x.png, icon_128x128.png, icon_128x128@2x.png, icon_256x256.png, icon_256x256@2x.png, icon_512x512.png, icon_512x512@2x.png` (@2x = double pixels), then `iconutil -c icns AppIcon.iconset -o Resources/AppIcon.icns`.
- README: install (`scripts/install.sh`), Step 0, shortcuts table, settings, troubleshooting (icon hidden behind the MacBook notch or disabled in System Settings › Menu Bar; paste not working → Step 0 / re-grant; shortcut conflicts; clipboard-access status), uninstall (quit; delete `~/Applications/ClipStack.app` and `~/Library/Application Support/ClipStack`; `defaults delete local.tools.ClipStack`; remove from Login Items; `tccutil reset Accessibility local.tools.ClipStack`).

## Later (not v1)
Finder file copies as items · **search text inside screenshots (Vision OCR)** · big preview on hold-Space / ⌘Y · editable app ignore list · edit text before pasting · "paste stack" (paste several in sequence) · sync between Macs.

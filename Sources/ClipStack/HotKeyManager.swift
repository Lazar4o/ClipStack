import Carbon.HIToolbox
import Foundation

/// Global shortcut via Carbon `RegisterEventHotKey`: needs no permission (unlike event taps / global monitors).
/// Not @MainActor: it is called from a C callback. Use from the main thread only.
final class HotKeyManager {
    static let shared = HotKeyManager()

    /// Called on the main queue when the shortcut is pressed.
    var onPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Returns false when the combination can't be registered (e.g. another app owns it).
    @discardableResult
    func register(keyCode: UInt32, carbonModifiers: UInt32) -> Bool {
        unregister()
        installHandlerIfNeeded()
        let id = EventHotKeyID(signature: OSType(0x434C_5354), id: 1)       // 'CLST'
        let status = RegisterEventHotKey(keyCode, carbonModifiers, id, GetEventDispatcherTarget(), 0, &hotKeyRef)
        if status != noErr { hotKeyRef = nil }
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // C callback: it cannot capture context, so `self` travels through userData.
        InstallEventHandler(GetEventDispatcherTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.onPressed?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }
}

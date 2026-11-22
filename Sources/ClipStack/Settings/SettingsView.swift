import ClipStackCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var prefs: Preferences
    @ObservedObject var store: HistoryStore
    @ObservedObject var ui: SettingsUIState

    var body: some View {
        Form {
            if ui.showWelcome { welcomeSection }
            historySection
            shortcutSection
            pastingSection
            clipboardAccessSection
            captureSection
            generalSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 680)
    }

    // MARK: - Sections

    private var welcomeSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to ClipStack").font(.headline)
                    Text("Press \(prefs.shortcut.display) anytime to open your clipboard history. "
                         + "Grant Accessibility below so a picked item is pasted straight into your app.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var historySection: some View {
        Section {
            Picker("Keep last", selection: limitBinding) {
                ForEach(Preferences.limitOptions, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            LabeledContent("Stored") {
                Text("\(store.items.count) items · "
                     + ByteCountFormatter.string(fromByteCount: Int64(store.totalBytes), countStyle: .file))
            }
            HStack {
                Button("Show in Finder") { controller.showStorageInFinder() }
                Spacer()
                Button("Clear History…") { controller.confirmClearHistory() }
            }
        } header: {
            Text("History")
        } footer: {
            Text("When the limit is reached, the oldest item is removed. Pinned items (⌘P) are kept and don't count.")
        }
    }

    private var shortcutSection: some View {
        Section("Shortcut") {
            LabeledContent("Open ClipStack") {
                HStack(spacing: 8) {
                    ShortcutRecorder(controller: controller, prefs: prefs)
                    Button("Reset") { controller.applyShortcut(.defaultShortcut) }
                        .disabled(prefs.shortcut == .defaultShortcut)
                }
            }
            if let error = controller.shortcutError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var pastingSection: some View {
        Section {
            Picker("When you pick an item", selection: $prefs.pasteMode) {
                Text("Paste it into the active app").tag(Preferences.PasteMode.autoPaste)
                Text("Only copy it to the clipboard").tag(Preferences.PasteMode.copyOnly)
            }
            .pickerStyle(.radioGroup)
            LabeledContent("Accessibility") {
                if controller.accessibilityGranted {
                    Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    HStack(spacing: 8) {
                        Text("Not granted").foregroundStyle(.orange)
                        Button("Grant Access…") {
                            Permissions.requestAccessibility()
                            Permissions.openAccessibilitySettings()
                        }
                    }
                }
            }
        } header: {
            Text("Pasting")
        } footer: {
            Text("Accessibility lets ClipStack press ⌘V for you. Without it, picked items are only copied.")
        }
    }

    private var clipboardAccessSection: some View {
        Section("Clipboard access") {
            switch controller.clipboardAccess {
            case .allowed:
                Label("ClipStack can read the clipboard", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .ask:
                VStack(alignment: .leading, spacing: 6) {
                    Label("macOS asks before each read", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Set ClipStack to Allow in Privacy & Security › Paste from Other Apps.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Open Privacy & Security") { Permissions.openPrivacySettings() }
                }
            case .denied:
                VStack(alignment: .leading, spacing: 6) {
                    Label("Blocked — nothing can be recorded", systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                    Text("Allow ClipStack in Privacy & Security › Paste from Other Apps.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Open Privacy & Security") { Permissions.openPrivacySettings() }
                }
            }
        }
    }

    private var captureSection: some View {
        Section {
            Toggle("Text", isOn: $prefs.captureText)
            Toggle("Images & screenshots", isOn: $prefs.captureImages)
        } header: {
            Text("Capture")
        } footer: {
            Text("Copies from password managers and Finder file copies are never recorded.")
        }
    }

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch at login", isOn: loginBinding)
            if controller.loginNeedsApproval {
                HStack {
                    Text("Needs approval in Login Items").font(.caption).foregroundStyle(.orange)
                    Spacer()
                    Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                }
            }
            Picker("Open panel at", selection: $prefs.panelPosition) {
                Text("Mouse cursor").tag(Preferences.PanelPosition.mouse)
                Text("Screen center").tag(Preferences.PanelPosition.center)
            }
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("ClipStack \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit ClipStack") { NSApp.terminate(nil) }
            }
        }
    }

    // MARK: - Bindings

    /// Shrinking may delete items, so it goes through a confirmation (run after the view update).
    private var limitBinding: Binding<Int> {
        Binding(
            get: { prefs.historyLimit },
            set: { newValue in DispatchQueue.main.async { controller.requestLimitChange(to: newValue) } }
        )
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { controller.loginEnabled },
            set: { newValue in controller.setLaunchAtLogin(newValue) }
        )
    }
}

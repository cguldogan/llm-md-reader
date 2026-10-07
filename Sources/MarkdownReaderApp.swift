import AppKit
import SwiftUI

@main
struct MarkdownReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let model = AppModel.shared

    var body: some Scene {
        WindowGroup("Markdown Reader") {
            ContentView()
                .environmentObject(model)
                .onOpenURL { url in
                    Task { @MainActor in
                        AppModel.shared.open(at: url)
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    AppModel.shared.openPanel()
                }
                .keyboardShortcut("o")
            }

            CommandMenu("View") {
                Button("Reader View") {
                    AppModel.shared.showsSource = false
                }
                .keyboardShortcut("1")

                Button("Source View") {
                    AppModel.shared.showsSource = true
                }
                .keyboardShortcut("2")

                Divider()

                Button("Increase Text Size") {
                    AppModel.shared.bumpFontSize(1)
                }
                .keyboardShortcut("=", modifiers: .command)

                Button("Decrease Text Size") {
                    AppModel.shared.bumpFontSize(-1)
                }
                .keyboardShortcut("-", modifiers: .command)

                Divider()

                ForEach(AppearancePreference.allCases) { preference in
                    Button(preference.label) {
                        AppModel.shared.appearance = preference
                    }
                }

                Divider()

                Button("Toggle Sidebar") {
                    AppModel.shared.toggleSidebar()
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
        }
    }
}

/// Handles the AppleScript `open documents` event so files dropped on the Dock
/// icon or opened via “Open With” work on cold launch, before SwiftUI's
/// `onOpenURL` machinery would see anything.
///
/// Double delivery (here and via `onOpenURL`) is harmless: opening is idempotent.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocumentsEvent(_:replyEvent:)),
            forEventClass: 0x61657674, // 'aevt'
            andEventID: 0x6F646F63 // 'odoc'
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc private func handleOpenDocumentsEvent(_ event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        guard let directObject = event.paramDescriptor(forKeyword: 0x2D2D2D2D) else { return } // '----'

        let items: [NSAppleEventDescriptor] =
            directObject.descriptorType == 0x6C697374 // 'list'
                ? (1...max(1, directObject.numberOfItems)).compactMap { directObject.atIndex($0) }
                : [directObject]

        for item in items {
            let coerced = (try? item.coerce(toDescriptorType: 0x6675726C)) ?? item // 'furl'
            guard let url = coerced.fileURLValue else { continue }
            Task { @MainActor in
                AppModel.shared.open(at: url)
            }
        }
    }
}

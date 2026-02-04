import AppKit
import SwiftUI

@main
struct NimoyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty Settings scene - we create our window manually in AppDelegate
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Page") {
                    appDelegate.appState.createNewPage()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("Quick Open...") {
                    appDelegate.appState.showSearch = true
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Actions...") {
                    appDelegate.appState.showActions = true
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Generate...") {
                    appDelegate.appState.showGenerate = true
                }
                .keyboardShortcut("g", modifiers: .command)

                Divider()

                Button("Export...") {
                    appDelegate.appState.exportCurrentPage()
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("Copy to Clipboard") {
                    appDelegate.appState.copyCurrentPageToClipboard()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var appState = AppState()
    var mainWindow: NSWindow?
    var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        createMainWindow()
        setupEventMonitor()
    }

    private func createMainWindow() {
        let theme = ThemeManager.shared.currentTheme

        // Create window with full control - this is pure AppKit
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure titlebar - THIS is what we couldn't do properly from SwiftUI
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.backgroundColor = theme.backgroundColor

        // Set appearance based on theme
        window.appearance = windowAppearance(for: theme)

        // Create SwiftUI content and wrap in NSHostingView
        let contentView = MainWindowContent()
            .environmentObject(appState)

        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView

        // Position and show
        window.center()
        window.makeKeyAndOrderFront(nil)

        mainWindow = window

        // Listen for theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: NSNotification.Name("ThemeDidChange"),
            object: nil
        )
    }

    @objc
    private func themeDidChange() {
        guard let window = mainWindow else { return }
        let theme = ThemeManager.shared.currentTheme
        window.backgroundColor = theme.backgroundColor
        window.appearance = windowAppearance(for: theme)
    }

    private func windowAppearance(for theme: Theme) -> NSAppearance? {
        let bgColor = theme.backgroundColor
        guard let rgb = bgColor.usingColorSpace(.sRGB) else {
            return NSAppearance(named: .darkAqua)
        }
        let luminance = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
        return NSAppearance(named: luminance > 0.5 ? .aqua : .darkAqua)
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "n":
                    DispatchQueue.main.async { self.appState.createNewPage() }
                    return nil
                case "o":
                    DispatchQueue.main.async { self.appState.showSearch = true }
                    return nil
                case "k":
                    DispatchQueue.main.async { self.appState.showActions = true }
                    return nil
                case "g":
                    DispatchQueue.main.async { self.appState.showGenerate = true }
                    return nil
                case "e":
                    DispatchQueue.main.async { self.appState.exportCurrentPage() }
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

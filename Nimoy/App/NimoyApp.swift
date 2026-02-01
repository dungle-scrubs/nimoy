import SwiftUI

@main
struct NimoyApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(appState)
                .onAppear {
                    appDelegate.appState = appState
                }
        }
        // Don't use .hiddenTitleBar - it removes the titlebar entirely
        // Instead, configure titlebar in WindowAccessor
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Page") {
                    appState.createNewPage()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Button("Quick Open...") {
                    appState.showSearch = true
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Actions...") {
                    appState.showActions = true
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Divider()
                
                Button("Export...") {
                    appState.exportCurrentPage()
                }
                .keyboardShortcut("e", modifiers: .command)
                
                Button("Copy to Clipboard") {
                    appState.copyCurrentPageToClipboard()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?
    var eventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Monitor for key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "n":
                    DispatchQueue.main.async {
                        self.appState?.createNewPage()
                    }
                    return nil // Consume the event
                case "o":
                    DispatchQueue.main.async {
                        self.appState?.showSearch = true
                    }
                    return nil
                case "k":
                    DispatchQueue.main.async {
                        self.appState?.showActions = true
                    }
                    return nil
                case "e":
                    DispatchQueue.main.async {
                        self.appState?.exportCurrentPage()
                    }
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
}

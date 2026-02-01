import SwiftUI
import AppKit

struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            PageCarousel()
            
            if appState.showSearch {
                SearchOverlay()
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .background(WindowAccessor { window in
            window?.titlebarAppearsTransparent = true
            window?.titleVisibility = .hidden
            window?.styleMask.insert(.fullSizeContentView)
            window?.isMovableByWindowBackground = true
            window?.backgroundColor = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)
        })
    }
}

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow?) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

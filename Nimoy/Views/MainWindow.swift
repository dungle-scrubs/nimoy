import SwiftUI
import AppKit

struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            PageCarousel()
            
            // Toolbar in upper right
            VStack {
                HStack {
                    Spacer()
                    ToolbarButtons()
                        .padding(.top, 8)
                        .padding(.trailing, 12)
                }
                Spacer()
            }
            
            if appState.showSearch {
                SearchOverlay()
            }
            
            if appState.showActions {
                ActionPalette()
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

struct ToolbarButtons: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 8) {
            // New file button
            Button(action: {
                appState.createNewPage()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
            .help("New Page (⌘N)")
            
            // Export button
            Button(action: {
                appState.exportCurrentPage()
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
            .help("Export (⌘E)")
        }
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

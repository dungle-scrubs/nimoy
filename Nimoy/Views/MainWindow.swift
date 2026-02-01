import SwiftUI
import AppKit

struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            PageCarousel()
            
            // Toolbar buttons in top-right corner
            ToolbarButtons()
                .padding(.top, 6)
                .padding(.trailing, 12)
            
            if appState.showSearch {
                SearchOverlay()
            }
            
            if appState.showActions {
                ActionPalette()
            }
        }
        .ignoresSafeArea()
        .frame(minWidth: 500, minHeight: 300)
        .background(WindowAccessor { window in
            guard let window = window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.backgroundColor = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)
        })
    }
}

struct ToolbarButtons: View {
    @EnvironmentObject var appState: AppState
    @State private var hoveredButton: String? = nil
    
    var body: some View {
        HStack(spacing: 6) {
            // New file button
            Button(action: {
                appState.createNewPage()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(hoveredButton == "new" ? 0.9 : 0.5))
            }
            .buttonStyle(.plain)
            .frame(width: 22, height: 22)
            .background(Color.white.opacity(hoveredButton == "new" ? 0.15 : 0))
            .cornerRadius(4)
            .onHover { hovering in
                hoveredButton = hovering ? "new" : nil
            }
            .help("New Page (⌘N)")
            
            // Export button
            Button(action: {
                appState.exportCurrentPage()
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(hoveredButton == "export" ? 0.9 : 0.5))
            }
            .buttonStyle(.plain)
            .frame(width: 22, height: 22)
            .background(Color.white.opacity(hoveredButton == "export" ? 0.15 : 0))
            .cornerRadius(4)
            .onHover { hovering in
                hoveredButton = hovering ? "export" : nil
            }
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

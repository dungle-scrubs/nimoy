import SwiftUI
import AppKit

struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            PageCarousel()
            
            if appState.showSearch {
                SearchOverlay()
                    .id(appState.searchId)
            }
            
            if appState.showActions {
                ActionPalette()
                    .id(appState.actionsId)
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .background(WindowAccessor(appState: appState))
    }
}



struct WindowAccessor: NSViewRepresentable {
    let appState: AppState
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            
            let bgColor = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)
            
            // Configure window appearance
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.backgroundColor = bgColor
            window.titlebarSeparatorStyle = .none
            
            // Add titlebar accessory for buttons (only once)
            if window.titlebarAccessoryViewControllers.isEmpty {
                let accessory = NSTitlebarAccessoryViewController()
                accessory.layoutAttribute = .trailing
                
                let buttonsView = NSHostingView(rootView: TitlebarButtonsView(appState: appState))
                buttonsView.frame.size = NSSize(width: 90, height: 28)
                accessory.view = buttonsView
                
                window.addTitlebarAccessoryViewController(accessory)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct TitlebarButtonsView: View {
    @ObservedObject var appState: AppState
    @State private var hovered: String? = nil
    
    private let bgColor = Color(nsColor: NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.17, alpha: 1.0))
    
    var body: some View {
        HStack(spacing: 8) {
            TitlebarButton(icon: "plus", isHovered: hovered == "new") {
                appState.createNewPage()
            }
            .onHover { hovered = $0 ? "new" : nil }
            
            TitlebarButton(icon: "magnifyingglass", isHovered: hovered == "search") {
                appState.showSearch = true
            }
            .onHover { hovered = $0 ? "search" : nil }
            
            TitlebarButton(icon: "square.and.arrow.up", isHovered: hovered == "export") {
                appState.exportCurrentPage()
            }
            .onHover { hovered = $0 ? "export" : nil }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bgColor)
    }
}

struct TitlebarButton: View {
    let icon: String
    let isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(isHovered ? 0.9 : 0.6))
        }
        .buttonStyle(.plain)
        .frame(width: 24, height: 24)
        .background(Color.white.opacity(isHovered ? 0.1 : 0))
        .cornerRadius(5)
    }
}

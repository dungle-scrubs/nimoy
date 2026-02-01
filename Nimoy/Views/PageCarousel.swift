import SwiftUI

struct PageCarousel: View {
    @EnvironmentObject var appState: AppState
    @State private var dragOffset: CGFloat = 0
    
    private let swipeThreshold: CGFloat = 100
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(appState.pages.enumerated()), id: \.element.id) { index, page in
                    PageView(page: binding(for: index))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(x: offsetForPage(at: index, in: geometry))
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if abs(value.translation.width) > abs(value.translation.height) {
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        handleSwipeEnd(translation: value.translation.width, velocity: value.predictedEndTranslation.width)
                    }
            )
        }
        .clipped()
    }
    
    private func binding(for index: Int) -> Binding<Page> {
        Binding(
            get: { appState.pages[index] },
            set: { appState.updatePage($0) }
        )
    }
    
    private func offsetForPage(at index: Int, in geometry: GeometryProxy) -> CGFloat {
        let pageOffset = CGFloat(index - appState.currentPageIndex) * geometry.size.width
        return pageOffset + dragOffset
    }
    
    private func handleSwipeEnd(translation: CGFloat, velocity: CGFloat) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if translation < -swipeThreshold || velocity < -500 {
                appState.nextPage()
            } else if translation > swipeThreshold || velocity > 500 {
                appState.previousPage()
            }
            dragOffset = 0
        }
    }
}

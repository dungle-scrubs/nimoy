import SwiftUI

struct LoadingDots: View {
    @State private var frame = 0
    
    private let frames = [".  ", ".. ", "..."]
    private let interval: TimeInterval
    
    init(interval: TimeInterval = 0.5) {
        self.interval = interval
    }
    
    var body: some View {
        Text(frames[frame])
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                    frame = (frame + 1) % frames.count
                }
            }
    }
}

#Preview {
    LoadingDots()
        .font(.system(size: 15, design: .monospaced))
}

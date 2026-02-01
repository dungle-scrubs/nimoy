import SwiftUI
import AppKit

let kLineHeight: CGFloat = 22
let editorFont = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
let editorInset: CGFloat = 20
let titleBarHeight: CGFloat = 6

struct PageView: View {
    @Binding var page: Page
    @StateObject private var viewModel: PageViewModel
    
    init(page: Binding<Page>) {
        self._page = page
        self._viewModel = StateObject(wrappedValue: PageViewModel(content: page.wrappedValue.content))
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // Editor pane
                CalculatorEditor(
                    text: Binding(
                        get: { viewModel.content },
                        set: { viewModel.content = $0 }
                    ),
                    font: editorFont
                )
                .frame(width: geometry.size.width * 0.6)
                
                // Results pane - aligned with editor
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, result in
                        HStack {
                            Spacer()
                            if let evalResult = result.result {
                                ResultText(result: evalResult)
                            }
                        }
                        .frame(height: kLineHeight)
                    }
                    Spacer()
                }
                .padding(.top, editorInset - 4)
                .padding(.trailing, editorInset)
                .frame(width: geometry.size.width * 0.4)
            }
        }
        .padding(.top, titleBarHeight)
        .background(Color(nsColor: NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)))
        .onReceive(viewModel.$results) { _ in
            var updatedPage = page
            updatedPage.updateContent(viewModel.content)
            page = updatedPage
        }
        .onChange(of: page.content) { _, newValue in
            if newValue != viewModel.content {
                viewModel.setContent(newValue)
            }
        }
    }
}

struct CalculatorEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.font = font
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.backgroundColor = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)
        textView.insertionPointColor = .white
        textView.textContainerInset = NSSize(width: editorInset, height: editorInset - 6)
        
        // Set line height
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = kLineHeight
        paragraphStyle.maximumLineHeight = kLineHeight
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.white
        ]
        
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        
        context.coordinator.applyHighlighting(to: textView)
        
        // Focus and move cursor to end
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
            let endPosition = textView.string.count
            textView.setSelectedRange(NSRange(location: endPosition, length: 0))
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            context.coordinator.applyHighlighting(to: textView)
            textView.selectedRanges = selectedRanges
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CalculatorEditor
        private var isUpdating = false
        
        init(_ parent: CalculatorEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdating else { return }
            
            parent.text = textView.string
            applyHighlighting(to: textView)
        }
        
        func applyHighlighting(to textView: NSTextView) {
            isUpdating = true
            defer { isUpdating = false }
            
            let selectedRanges = textView.selectedRanges
            let attributed = SyntaxHighlighter.highlight(textView.string, font: parent.font, lineHeight: kLineHeight)
            
            textView.textStorage?.setAttributedString(attributed)
            textView.selectedRanges = selectedRanges
        }
    }
}

struct ResultText: View {
    let result: EvaluationResult
    
    var body: some View {
        if case .text(let str) = result, str == "Loading..." {
            LoadingDots(interval: 0.5)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(.secondary)
        } else if case .error(_) = result {
            Text("--")
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(.red)
        } else {
            Text(result.displayString)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(resultColor)
                .textSelection(.enabled)
        }
    }
    
    private var resultColor: Color {
        switch result {
        case .number:
            return Color(nsColor: NSColor(calibratedRed: 0.6, green: 0.9, blue: 0.6, alpha: 1.0))
        case .text:
            return .secondary
        case .error:
            return .red
        }
    }
}

@MainActor
class PageViewModel: ObservableObject {
    @Published var results: [LineResult] = []
    
    private var _content: String = ""
    var content: String {
        get { _content }
        set {
            if _content != newValue {
                _content = newValue
                debounceEvaluate()
            }
        }
    }
    
    private let evaluator = Evaluator()
    private var debounceTask: Task<Void, Never>?
    private var priceCheckTimer: Timer?
    
    init(content: String) {
        _content = content
        evaluateAll()
        startPriceCheckTimer()
    }
    
    deinit {
        priceCheckTimer?.invalidate()
    }
    
    func setContent(_ newContent: String) {
        _content = newContent
        evaluateAll()
    }
    
    private func debounceEvaluate() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms debounce
            guard !Task.isCancelled else { return }
            await MainActor.run {
                evaluateAll()
            }
        }
    }
    
    private func startPriceCheckTimer() {
        // Check for price updates every 2 seconds to refresh "Loading..." results
        priceCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                // Only re-evaluate if we have any "Loading..." results
                let hasLoading = self.results.contains { result in
                    if case .text(let str) = result.result, str == "Loading..." {
                        return true
                    }
                    return false
                }
                if hasLoading {
                    self.evaluateAll()
                }
            }
        }
    }
    
    private func evaluateAll() {
        evaluator.reset()
        
        let lines = content.components(separatedBy: "\n")
        results = lines.enumerated().map { index, line in
            let result = evaluator.evaluate(line)
            return LineResult(lineNumber: index + 1, input: line, result: result)
        }
    }
}

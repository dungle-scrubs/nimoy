import AppKit
import SwiftUI

let kLineHeight: CGFloat = 22
let editorFont = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
let editorInset: CGFloat = 20
let titleBarHeight: CGFloat = 6

struct PageView: View {
    @Binding var page: Page
    @StateObject private var viewModel: PageViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var ghostText: String = ""

    init(page: Binding<Page>) {
        _page = page
        _viewModel = StateObject(wrappedValue: PageViewModel(content: page.wrappedValue.content))
    }

    var body: some View {
        GeometryReader { _ in
            SyncedEditorView(
                text: Binding(
                    get: { viewModel.content },
                    set: { newValue in
                        viewModel.content = newValue
                        ghostText = ""
                        viewModel.requestAutocomplete(for: newValue) { suggestion in
                            ghostText = suggestion
                        }
                    }
                ),
                results: viewModel.results,
                ghostText: $ghostText,
                theme: themeManager.currentTheme,
                onAcceptGhost: { textView in
                    let completion = ghostText
                    ghostText = ""
                    textView.insertText(completion, replacementRange: textView.selectedRange())
                }
            )
        }
        .padding(.top, titleBarHeight)
        .background(themeManager.currentTheme.backgroundSwiftUI.ignoresSafeArea())
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
        .onAppear {
            // Re-evaluate when view appears to fix initial load issues
            viewModel.setContent(page.content)
        }
    }
}

/// Custom NSTextView that can draw ghost text without modifying content
class GhostTextView: NSTextView {
    var ghostText: String = ""
    var ghostColor: NSColor = .gray

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw ghost text after cursor if we have one
        guard !ghostText.isEmpty else { return }

        // Only show ghost text if cursor is at end of text
        let cursorPosition = selectedRange().location
        guard cursorPosition == string.count else { return }

        guard let layoutManager,
              let textContainer else { return }

        let theFont = font ?? NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)

        // Get position after the last character
        let xPos: CGFloat
        let yPos: CGFloat

        if string.isEmpty {
            xPos = textContainerInset.width
            yPos = textContainerInset.height
        } else {
            // Get the glyph range and find position after last glyph
            let charIndex = max(0, string.count - 1)
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)

            // Get the line fragment for this glyph
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

            // Get location of the glyph within the line (this is baseline-relative)
            let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)

            // Measure width of the last character
            let lastChar = String(string.suffix(1))
            let charWidth = (lastChar as NSString).size(withAttributes: [.font: theFont]).width

            xPos = textContainerInset.width + lineRect.origin.x + glyphLocation.x + charWidth

            // glyphLocation.y is the baseline offset from top of lineRect
            // We need to draw at baseline - ascender to match
            let baselineY = lineRect.origin.y + glyphLocation.y - theFont.ascender
            yPos = textContainerInset.height + baselineY - 1
        }

        // Draw ghost text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: theFont,
            .foregroundColor: ghostColor,
        ]

        let ghostString = NSAttributedString(string: ghostText, attributes: attributes)
        ghostString.draw(at: NSPoint(x: xPos, y: yPos))
    }
}

struct CalculatorEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var theme: Theme
    @Binding var ghostText: String
    var onAcceptGhost: (NSTextView) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = GhostTextView()

        // Configure text view
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
        textView.backgroundColor = theme.backgroundColor
        textView.insertionPointColor = theme.cursorColor
        textView.textContainerInset = NSSize(width: editorInset, height: editorInset - 6)
        textView.ghostColor = theme.secondaryTextColor.withAlphaComponent(0.5)

        // Set up text container
        let textContainer = NSTextContainer(size: NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.widthTracksTextView = true
        textView.replaceTextContainer(textContainer)

        // Set line height
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = kLineHeight
        paragraphStyle.maximumLineHeight = kLineHeight
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: theme.textColor,
        ]

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)

        // Configure scroll view
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        context.coordinator.textView = textView
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
        guard let textView = scrollView.documentView as? GhostTextView else { return }

        // Update coordinator's parent reference for theme changes
        context.coordinator.parent = self
        context.coordinator.textView = textView

        // Update theme colors
        textView.backgroundColor = theme.backgroundColor
        textView.insertionPointColor = theme.cursorColor
        textView.ghostColor = theme.secondaryTextColor.withAlphaComponent(0.5)

        // Update typing attributes for new text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = kLineHeight
        paragraphStyle.maximumLineHeight = kLineHeight
        textView.typingAttributes = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: theme.textColor,
        ]

        // Update ghost text
        if textView.ghostText != ghostText {
            textView.ghostText = ghostText
            textView.needsDisplay = true
        }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            context.coordinator.applyHighlighting(to: textView)
            textView.selectedRanges = selectedRanges
        } else {
            // Re-apply highlighting for theme changes
            context.coordinator.applyHighlighting(to: textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CalculatorEditor
        weak var textView: GhostTextView?
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

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Handle Tab key to accept ghost text
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                if !parent.ghostText.isEmpty {
                    parent.onAcceptGhost(textView)
                    return true
                }
            }
            // Handle Escape to dismiss ghost text
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if !parent.ghostText.isEmpty {
                    parent.ghostText = ""
                    return true
                }
            }
            return false
        }

        func applyHighlighting(to textView: NSTextView) {
            isUpdating = true
            defer { isUpdating = false }

            let selectedRanges = textView.selectedRanges
            let attributed = SyntaxHighlighter.highlight(
                textView.string,
                font: parent.font,
                lineHeight: kLineHeight,
                theme: parent.theme
            )

            textView.textStorage?.setAttributedString(attributed)
            textView.selectedRanges = selectedRanges
        }
    }
}

// MARK: - Synced Editor View (single scroll for editor + results)

struct SyncedEditorView: NSViewRepresentable {
    @Binding var text: String
    var results: [LineResult]
    @Binding var ghostText: String
    var theme: Theme
    var onAcceptGhost: (NSTextView) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true

        // Create container view that holds both editor and results
        let containerView = FlippedView()
        containerView.wantsLayer = true

        // Create text view (no separate scroll)
        let textView = GhostTextView()
        textView.delegate = context.coordinator
        textView.font = editorFont
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.insertionPointColor = theme.cursorColor
        textView.textContainerInset = NSSize(width: editorInset, height: editorInset - 6)
        textView.ghostColor = theme.secondaryTextColor.withAlphaComponent(0.5)

        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        textView.replaceTextContainer(textContainer)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = kLineHeight
        paragraphStyle.maximumLineHeight = kLineHeight
        paragraphStyle.headIndent = 20 // Indent wrapped lines
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: editorFont,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: theme.textColor,
        ]

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.autoresizingMask = [.width]

        // Create results view
        let resultsView = ResultsNSView()
        resultsView.theme = theme
        resultsView.results = results

        containerView.addSubview(textView)
        containerView.addSubview(resultsView)

        context.coordinator.textView = textView
        context.coordinator.resultsView = resultsView
        context.coordinator.containerView = containerView
        context.coordinator.scrollView = scrollView
        resultsView.textView = textView // Connect for line position lookup

        scrollView.documentView = containerView

        context.coordinator.applyHighlighting(to: textView)
        context.coordinator.updateLayout()
        context.coordinator.setupFrameObserver()

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
            let endPosition = textView.string.count
            textView.setSelectedRange(NSRange(location: endPosition, length: 0))
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        context.coordinator.parent = self

        textView.insertionPointColor = theme.cursorColor
        textView.ghostColor = theme.secondaryTextColor.withAlphaComponent(0.5)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = kLineHeight
        paragraphStyle.maximumLineHeight = kLineHeight
        paragraphStyle.headIndent = 20
        textView.typingAttributes = [
            .font: editorFont,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: theme.textColor,
        ]

        if textView.ghostText != ghostText {
            textView.ghostText = ghostText
            textView.needsDisplay = true
        }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            context.coordinator.applyHighlighting(to: textView)
            textView.selectedRanges = selectedRanges
        }

        // Update results
        context.coordinator.resultsView?.theme = theme
        context.coordinator.resultsView?.results = results
        context.coordinator.resultsView?.needsDisplay = true

        context.coordinator.updateLayout()
    }

    func makeCoordinator() -> SyncedCoordinator {
        SyncedCoordinator(self)
    }

    class SyncedCoordinator: NSObject, NSTextViewDelegate {
        var parent: SyncedEditorView
        weak var textView: GhostTextView?
        weak var resultsView: ResultsNSView?
        weak var containerView: NSView?
        weak var scrollView: NSScrollView?
        private var isUpdating = false
        private var frameObserver: NSObjectProtocol?

        init(_ parent: SyncedEditorView) {
            self.parent = parent
        }

        func setupFrameObserver() {
            guard let scrollView else { return }
            scrollView.postsFrameChangedNotifications = true
            frameObserver = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: scrollView,
                queue: .main
            ) { [weak self] _ in
                self?.updateLayout()
                self?.resultsView?.needsDisplay = true
            }
        }

        deinit {
            if let observer = frameObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdating else { return }

            parent.text = textView.string
            applyHighlighting(to: textView)
            updateLayout()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                if !parent.ghostText.isEmpty {
                    parent.onAcceptGhost(textView)
                    return true
                }
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if !parent.ghostText.isEmpty {
                    parent.ghostText = ""
                    return true
                }
            }
            return false
        }

        func applyHighlighting(to textView: NSTextView) {
            isUpdating = true
            defer { isUpdating = false }

            let selectedRanges = textView.selectedRanges
            let attributed = SyntaxHighlighter.highlight(
                textView.string,
                font: editorFont,
                lineHeight: kLineHeight,
                theme: parent.theme
            )
            textView.textStorage?.setAttributedString(attributed)
            textView.selectedRanges = selectedRanges
        }

        func updateLayout() {
            guard let textView,
                  let resultsView,
                  let containerView,
                  let scrollView else { return }

            let scrollWidth = scrollView.frame.width
            // Give more space to editor, results only need ~150px for numbers
            let resultsWidth: CGFloat = min(180, scrollWidth * 0.25)
            let editorWidth = scrollWidth - resultsWidth

            // Force text view layout
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)

            // Calculate content height based on text
            let lineCount = max(1, textView.string.components(separatedBy: "\n").count)
            let contentHeight = CGFloat(lineCount) * kLineHeight + editorInset * 2

            // Update text container width
            textView.textContainer?.containerSize = NSSize(
                width: editorWidth - editorInset,
                height: CGFloat.greatestFiniteMagnitude
            )

            // Position views
            textView.frame = NSRect(x: 0, y: 0, width: editorWidth, height: contentHeight)
            resultsView.frame = NSRect(x: editorWidth, y: 0, width: resultsWidth, height: contentHeight)

            containerView.frame = NSRect(x: 0, y: 0, width: scrollWidth, height: contentHeight)
        }
    }
}

/// Flipped container view for proper top-to-bottom layout
class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}

/// Custom NSView for drawing results - gets line positions from text view's layout manager
class ResultsNSView: NSView {
    var theme: Theme = BuiltInThemes.dark
    var results: [LineResult] = []
    weak var textView: GhostTextView?

    // Loading dots animation
    private var loadingFrame = 0
    private let loadingFrames = [".  ", ".. ", "..."]
    private var loadingTimer: Timer?

    private var hasLoadingResults: Bool {
        results.contains { result in
            if case let .text(str) = result.result, str == "Loading..." {
                return true
            }
            return false
        }
    }

    func startLoadingAnimation() {
        guard loadingTimer == nil else { return }
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            guard let self, hasLoadingResults else {
                self?.stopLoadingAnimation()
                return
            }
            loadingFrame = (loadingFrame + 1) % loadingFrames.count
            needsDisplay = true
        }
    }

    func stopLoadingAnimation() {
        loadingTimer?.invalidate()
        loadingTimer = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        let text = textView.string
        let lines = text.components(separatedBy: "\n")
        var charIndex = 0

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let hasResult = index < results.count && results[index].result != nil
            let result = hasResult ? results[index].result : nil

            // Check if line should have a value but doesn't
            let shouldHaveValue = !trimmedLine.isEmpty
                && !trimmedLine.hasPrefix("//")
                && !trimmedLine.hasPrefix("#")
                && !trimmedLine.hasPrefix("/*")
                && !trimmedLine.hasPrefix("*/")
                && trimmedLine.contains(where: \.isLetter)

            let needsWarning = shouldHaveValue && result == nil

            // Draw orange dashes for lines without values
            if needsWarning {
                let safeCharIndex = min(charIndex, max(0, text.count - 1))
                if safeCharIndex >= 0, !text.isEmpty {
                    let glyphIndex = layoutManager.glyphIndexForCharacter(at: safeCharIndex)
                    let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
                    let yPos = lineRect.origin.y + textView.textContainerInset.height + 3

                    // Draw orange dashes on the right side
                    let dashAttrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .regular),
                        .foregroundColor: NSColor.systemOrange.withAlphaComponent(0.6),
                    ]
                    let dashRect = NSRect(
                        x: bounds.width - editorInset - 30,
                        y: yPos,
                        width: 30,
                        height: lineRect.height
                    )
                    ("---" as NSString).draw(in: dashRect, withAttributes: dashAttrs)
                }
                charIndex += line.count + 1
                continue
            }

            guard let result else {
                charIndex += line.count + 1
                continue
            }

            var displayString = result.displayString

            // Animate loading dots
            if case let .text(str) = result, str == "Loading..." {
                displayString = loadingFrames[loadingFrame]
                if loadingTimer == nil {
                    DispatchQueue.main.async { [weak self] in
                        self?.startLoadingAnimation()
                    }
                }
            }

            guard !displayString.isEmpty else {
                charIndex += line.count + 1
                continue
            }

            // Get line position from layout manager
            let safeCharIndex = min(charIndex, max(0, text.count - 1))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: safeCharIndex)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

            // Add offset to align baselines (results were rendering too high)
            let yPos = lineRect.origin.y + textView.textContainerInset.height + 3
            let rect = NSRect(x: 0, y: yPos, width: bounds.width - editorInset, height: lineRect.height)

            let isAggregate = result.isAggregate

            let textColor: NSColor = switch result {
            case .number:
                if result.isCurrencyConversion {
                    theme.backgroundColor
                } else if isAggregate {
                    theme.resultColor
                } else {
                    theme.resultColor
                }
            case let .text(str) where str == "Loading...":
                theme.secondaryTextColor
            case .text:
                theme.secondaryTextColor
            case .error:
                .red
            }

            // Use slightly bolder font for aggregates
            let font = isAggregate ? NSFont.monospacedSystemFont(ofSize: 15, weight: .medium) : editorFont

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle,
            ]

            // Draw pill background for currency conversions
            if result.isCurrencyConversion {
                let textSize = (displayString as NSString).size(withAttributes: attributes)
                let pillRect = NSRect(
                    x: rect.maxX - textSize.width - 16,
                    y: yPos + 3,
                    width: textSize.width + 16,
                    height: kLineHeight - 6
                )
                let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 4, yRadius: 4)
                theme.resultColor.setFill()
                pillPath.fill()
            }

            (displayString as NSString).draw(in: rect, withAttributes: attributes)

            charIndex += line.count + 1
        }
    }

    override var isFlipped: Bool {
        true
    }
}

struct ResultText: View {
    let result: EvaluationResult
    let theme: Theme

    var body: some View {
        if case let .text(str) = result, str == "Loading..." {
            LoadingDots(interval: 0.5)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(theme.secondaryTextSwiftUI)
        } else if case .error = result {
            Text("--")
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(.red)
        } else if result.isCurrencyConversion {
            // Currency conversion with pill indicator
            Text(result.displayString)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(theme.backgroundSwiftUI)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.resultSwiftUI)
                )
                .textSelection(.enabled)
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
            theme.resultSwiftUI
        case .text:
            theme.secondaryTextSwiftUI
        case .error:
            .red
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

    private var debounceTask: Task<Void, Never>?
    private var autocompleteTask: Task<Void, Never>?
    private var priceCheckTimer: Timer?

    init(content: String) {
        _content = content

        evaluateAll()
        startPriceCheckTimer()
        startCryptoPriceListener()
    }

    deinit {
        priceCheckTimer?.invalidate()
        if let observer = cryptoPriceObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func setContent(_ newContent: String) {
        _content = newContent
        evaluateAll()
    }

    private var cryptoPriceObserver: NSObjectProtocol?

    private func startCryptoPriceListener() {
        // Re-evaluate when crypto prices are fetched
        cryptoPriceObserver = NotificationCenter.default.addObserver(
            forName: .cryptoPriceUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateAll()
        }
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
                guard let self else { return }
                // Only re-evaluate if we have any "Loading..." results
                let hasLoading = self.results.contains { result in
                    if case let .text(str) = result.result, str == "Loading..." {
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
        let evaluator = Evaluator()

        let lines = content.components(separatedBy: "\n")
        results = lines.enumerated().map { index, line in
            let result = evaluator.evaluate(line)
            return LineResult(lineNumber: index + 1, input: line, result: result)
        }
    }

    /// Request autocomplete for the current input
    func requestAutocomplete(for text: String, completion: @escaping (String) -> Void) {
        autocompleteTask?.cancel()

        // Get the current line (last line of text)
        let lines = text.components(separatedBy: "\n")
        guard let currentLine = lines.last, !currentLine.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        // Don't autocomplete if line already has a result (simple heuristic)
        if currentLine.contains("=") {
            return
        }

        // Keep full context for variable awareness
        let fullContext = text

        autocompleteTask = Task {
            // Wait 500ms before requesting autocomplete
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }

            if let suggestion = await GroqService.shared.autocomplete(input: currentLine, context: fullContext) {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    completion(suggestion)
                }
            }
        }
    }
}

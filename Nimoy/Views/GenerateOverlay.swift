import SwiftUI

struct GenerateOverlay: View {
    @Binding var isPresented: Bool
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var description: String = ""
    @State private var isGenerating: Bool = false
    @State private var error: String? = nil
    @FocusState private var isTextFieldFocused: Bool
    
    var onGenerate: (String) -> Void
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isGenerating {
                        isPresented = false
                    }
                }
            
            // Modal
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(themeManager.currentTheme.resultSwiftUI)
                    Text("Generate Document")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textSwiftUI)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(themeManager.currentTheme.secondaryTextSwiftUI)
                    }
                    .buttonStyle(.plain)
                    .disabled(isGenerating)
                }
                
                // Description
                Text("Describe what you want to calculate:")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.secondaryTextSwiftUI)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Text input
                TextEditor(text: $description)
                    .font(.system(size: 14, design: .default))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.currentTheme.backgroundSwiftUI.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.currentTheme.secondaryTextSwiftUI.opacity(0.3), lineWidth: 1)
                    )
                    .frame(height: 120)
                    .disabled(isGenerating)
                    .focused($isTextFieldFocused)
                
                // Example hint
                Text("Example: \"Monthly budget with rent $1500, utilities $200, groceries $400. Sum each category and show total.\"")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryTextSwiftUI.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Error message
                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Generate button
                Button(action: generate) {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.backgroundSwiftUI))
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isGenerating ? "Generating..." : "Generate")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(description.isEmpty || isGenerating 
                                  ? themeManager.currentTheme.secondaryTextSwiftUI.opacity(0.3)
                                  : themeManager.currentTheme.resultSwiftUI)
                    )
                    .foregroundColor(description.isEmpty || isGenerating 
                                     ? themeManager.currentTheme.secondaryTextSwiftUI
                                     : themeManager.currentTheme.backgroundSwiftUI)
                }
                .buttonStyle(.plain)
                .disabled(description.isEmpty || isGenerating)
            }
            .padding(20)
            .frame(width: 500)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.currentTheme.backgroundSwiftUI)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeManager.currentTheme.secondaryTextSwiftUI.opacity(0.2), lineWidth: 1)
            )
        }
        .onExitCommand {
            if !isGenerating {
                isPresented = false
            }
        }
        .onAppear {
            // Focus the text input when overlay appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func generate() {
        guard !description.isEmpty else { return }
        
        isGenerating = true
        error = nil
        
        Task {
            do {
                let result = try await GroqService.shared.generateDocument(from: description)
                await MainActor.run {
                    isGenerating = false
                    isPresented = false
                    onGenerate(result)
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    self.error = "Generation failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

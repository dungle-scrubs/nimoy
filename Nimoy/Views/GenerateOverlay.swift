import SwiftUI

struct GenerateOverlay: View {
    @Binding var isPresented: Bool
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var llmManager = LLMManager.shared
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
                
                // Show setup instructions if LLM not configured
                if !llmManager.isEnabled {
                    notConfiguredView
                } else {
                    generateFormView
                }
                
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
    
    // MARK: - Not Configured View
    
    private var notConfiguredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 40))
                .foregroundColor(themeManager.currentTheme.secondaryTextSwiftUI)
            
            Text("AI Features Not Configured")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textSwiftUI)
            
            Text("To generate documents with AI, choose a provider:")
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.secondaryTextSwiftUI)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                // Local option
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "desktopcomputer")
                        .frame(width: 20)
                        .foregroundColor(themeManager.currentTheme.resultSwiftUI)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Local (Ollama)")
                            .font(.subheadline.bold())
                            .foregroundColor(themeManager.currentTheme.textSwiftUI)
                        Text("Private, runs on your Mac (~1.2GB RAM)")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryTextSwiftUI)
                        Text("brew install ollama && ollama pull qwen2.5:1.5b")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(themeManager.currentTheme.resultSwiftUI)
                            .padding(6)
                            .background(themeManager.currentTheme.backgroundSwiftUI.opacity(0.5))
                            .cornerRadius(4)
                    }
                }
                
                Divider()
                    .background(themeManager.currentTheme.secondaryTextSwiftUI.opacity(0.3))
                
                // Cloud option
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "cloud")
                        .frame(width: 20)
                        .foregroundColor(themeManager.currentTheme.resultSwiftUI)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cloud (Groq)")
                            .font(.subheadline.bold())
                            .foregroundColor(themeManager.currentTheme.textSwiftUI)
                        Text("Fast, requires free API key from groq.com")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryTextSwiftUI)
                        Text("defaults write com.nimoy.app groq_api_key \"your-key\"")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(themeManager.currentTheme.resultSwiftUI)
                            .padding(6)
                            .background(themeManager.currentTheme.backgroundSwiftUI.opacity(0.5))
                            .cornerRadius(4)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeManager.currentTheme.secondaryTextSwiftUI.opacity(0.2), lineWidth: 1)
            )
            
            Text("Then set your provider:")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryTextSwiftUI)
            
            Text("defaults write com.nimoy.app llm_provider \"Local (Ollama)\"")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.resultSwiftUI)
                .padding(6)
                .background(themeManager.currentTheme.backgroundSwiftUI.opacity(0.5))
                .cornerRadius(4)
        }
    }
    
    // MARK: - Generate Form View
    
    private var generateFormView: some View {
        VStack(spacing: 16) {
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
            Text("Example: \"Monthly budget with rent $1500, utilities $200, groceries $400\"")
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
            
            // Provider indicator + Generate button
            HStack {
                // Show current provider
                HStack(spacing: 4) {
                    Image(systemName: llmManager.providerType.icon)
                    Text(llmManager.providerType.rawValue)
                }
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryTextSwiftUI)
                
                Spacer()
                
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
                    .padding(.horizontal, 20)
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
        }
    }
    
    // MARK: - Generate Action
    
    private func generate() {
        guard !description.isEmpty else { return }
        
        isGenerating = true
        error = nil
        
        Task {
            do {
                let systemPrompt = NimoyTemplates.generationContext
                let result = try await llmManager.generate(
                    prompt: description,
                    systemPrompt: systemPrompt,
                    maxTokens: 1000,
                    temperature: 0.7
                )
                
                // Clean up the response - extract just the Nimoy code
                let cleaned = cleanGeneratedDocument(result)
                
                await MainActor.run {
                    isGenerating = false
                    isPresented = false
                    onGenerate(cleaned)
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    self.error = "Generation failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Clean up LLM response to extract just the Nimoy document
    private func cleanGeneratedDocument(_ text: String) -> String {
        var result = text
        
        // Remove markdown code blocks if present
        if result.contains("```") {
            let pattern = "```(?:nimoy)?\\n?([\\s\\S]*?)```"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)),
               let range = Range(match.range(at: 1), in: result) {
                result = String(result[range])
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

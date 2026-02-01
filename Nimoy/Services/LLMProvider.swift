import Foundation
import os.log

private let logger = Logger(subsystem: "com.nimoy.app", category: "LLMManager")

// MARK: - LLM Provider Protocol

protocol LLMProvider {
    func complete(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        temperature: Double
    ) async throws -> String
    
    var isAvailable: Bool { get }
}

// MARK: - Provider Type

enum LLMProviderType: String, CaseIterable, Codable {
    case none = "None"
    case mlx = "Local (MLX)"
    case ollama = "Local (Ollama)"
    case groq = "Cloud (Groq)"
    
    var icon: String {
        switch self {
        case .none: return "keyboard"
        case .mlx: return "apple.logo"
        case .ollama: return "desktopcomputer"
        case .groq: return "cloud"
        }
    }
    
    var description: String {
        switch self {
        case .none: return "Type manually, no AI features"
        case .mlx: return "Apple native, ~1GB RAM (recommended for M-series)"
        case .ollama: return "Private, runs on your Mac (~1.2GB RAM)"
        case .groq: return "Fast cloud AI, requires API key"
        }
    }
}

// MARK: - Ollama Provider

class OllamaProvider: LLMProvider {
    static let shared = OllamaProvider()
    static let recommendedModel = "qwen2.5:1.5b"  // 1.5B, ~1.2GB RAM
    
    let endpoint: String
    
    init(endpoint: String = "http://localhost:11434") {
        self.endpoint = endpoint
    }
    
    var isAvailable: Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var available = false
        
        guard let url = URL(string: "\(endpoint)/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                available = true
            }
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 1.5)
        return available
    }
    
    func hasModel(_ model: String) async -> Bool {
        guard let url = URL(string: "\(endpoint)/api/tags") else { return false }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let models = json?["models"] as? [[String: Any]] ?? []
            return models.contains { ($0["name"] as? String)?.hasPrefix(model.split(separator: ":").first ?? "") == true }
        } catch {
            return false
        }
    }
    
    func pullModel(_ model: String) async throws {
        guard let url = URL(string: "\(endpoint)/api/pull") else {
            throw LLMError.invalidEndpoint
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": model])
        request.timeoutInterval = 600  // 10 min for download
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LLMError.modelPullFailed
        }
    }
    
    func complete(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        temperature: Double
    ) async throws -> String {
        guard let url = URL(string: "\(endpoint)/api/chat") else {
            throw LLMError.invalidEndpoint
        }
        
        let model = UserDefaults.standard.string(forKey: "ollama_model") ?? Self.recommendedModel
        
        var messages: [[String: String]] = []
        if let system = systemPrompt {
            messages.append(["role": "system", "content": system])
        }
        messages.append(["role": "user", "content": prompt])
        
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": false,
            "options": [
                "num_predict": maxTokens,
                "temperature": temperature
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LLMError.requestFailed
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = json?["message"] as? [String: Any]
        let content = message?["content"] as? String
        
        return content ?? ""
    }
}

// MARK: - LLM Manager

class LLMManager: ObservableObject {
    static let shared = LLMManager()
    
    @Published var providerType: LLMProviderType = .none  // Default: no AI
    @Published var mlxAvailable = false
    @Published var ollamaAvailable = false
    @Published var groqAvailable = false
    
    /// Whether AI features are enabled
    var isEnabled: Bool {
        providerType != .none
    }
    
    init() {
        loadSettings()
        checkAvailability()
    }
    
    func loadSettings() {
        if let saved = UserDefaults.standard.string(forKey: "llm_provider"),
           let type = LLMProviderType(rawValue: saved) {
            providerType = type
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(providerType.rawValue, forKey: "llm_provider")
    }
    
    func checkAvailability() {
        Task {
            let groq = await GroqService.shared.hasAPIKey
            let ollama = OllamaProvider.shared.isAvailable
            let mlx = MLXProvider.shared.isAvailable
            
            await MainActor.run {
                groqAvailable = groq
                ollamaAvailable = ollama
                mlxAvailable = mlx
            }
        }
    }
    
    /// Generate a full document from a description
    func generate(
        prompt: String,
        systemPrompt: String? = nil,
        maxTokens: Int = 500,
        temperature: Double = 0.7
    ) async throws -> String {
        logger.info("LLMManager.generate called with provider: \(self.providerType.rawValue)")
        logger.info("Prompt length: \(prompt.count), maxTokens: \(maxTokens)")
        
        let result: String
        switch providerType {
        case .none:
            logger.error("Provider is .none, throwing notConfigured")
            throw LLMError.notConfigured
        case .mlx:
            logger.info("Routing to MLXProvider...")
            result = try await MLXProvider.shared.complete(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                temperature: temperature
            )
            logger.info("MLXProvider returned result of length: \(result.count)")
            return result
        case .groq:
            logger.info("Routing to GroqService...")
            result = try await GroqService.shared.complete(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                temperature: temperature,
                model: "llama-3.3-70b-versatile"
            )
            logger.info("GroqService returned result of length: \(result.count)")
            return result
        case .ollama:
            logger.info("Routing to OllamaProvider...")
            result = try await OllamaProvider.shared.complete(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                temperature: temperature
            )
            logger.info("OllamaProvider returned result of length: \(result.count)")
            return result
        }
    }
    
    /// Autocomplete the current line
    func autocomplete(
        prompt: String,
        systemPrompt: String? = nil
    ) async throws -> String {
        switch providerType {
        case .none:
            throw LLMError.notConfigured
        case .mlx:
            return try await MLXProvider.shared.complete(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: 100,
                temperature: 0.3
            )
        case .groq:
            return try await GroqService.shared.complete(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: 100,
                temperature: 0.3,
                model: "llama-3.1-8b-instant"
            )
        case .ollama:
            return try await OllamaProvider.shared.complete(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: 100,
                temperature: 0.3
            )
        }
    }
}

// MARK: - Errors

enum LLMError: Error, LocalizedError {
    case notConfigured
    case invalidEndpoint
    case requestFailed
    case noAPIKey
    case modelPullFailed
    case ollamaNotRunning
    
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "AI features not configured. Enable in Settings."
        case .invalidEndpoint: return "Invalid API endpoint"
        case .requestFailed: return "Request failed"
        case .noAPIKey: return "No API key configured"
        case .modelPullFailed: return "Failed to download model"
        case .ollamaNotRunning: return "Ollama is not running. Start it with: ollama serve"
        }
    }
}

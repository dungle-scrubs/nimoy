import Foundation

/// Service for LLM-powered autocomplete using Groq API
actor GroqService {
    static let shared = GroqService()
    
    private let baseURL = "https://api.groq.com/openai/v1/chat/completions"
    private let model = "llama-3.1-8b-instant"
    
    private static let apiKeyKey = "groq_api_key"
    
    private init() {}
    
    /// Get API key (checks environment first, then UserDefaults)
    private var apiKey: String {
        if let envKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        if let storedKey = UserDefaults.standard.string(forKey: Self.apiKeyKey), !storedKey.isEmpty {
            return storedKey
        }
        return ""
    }
    
    /// Set the API key (persists to UserDefaults)
    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: Self.apiKeyKey)
    }
    
    /// Check if API key is configured
    var isConfigured: Bool {
        !apiKey.isEmpty
    }
    
    /// Alias for isConfigured
    var hasAPIKey: Bool {
        !apiKey.isEmpty
    }
    
    /// Autocomplete a calculator expression
    /// - Parameters:
    ///   - input: The current line the user is typing
    ///   - context: The full document content for context (variable definitions, etc.)
    /// - Returns: A suggested completion, or nil if none
    func autocomplete(input: String, context: String) async -> String? {
        guard !apiKey.isEmpty else {
            print("GroqService: No API key configured")
            return nil
        }
        
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }
        
        // Extract variable definitions from context
        let lines = context.components(separatedBy: "\n")
        var variables: [String] = []
        for line in lines {
            if line.contains("=") {
                let parts = line.components(separatedBy: "=")
                if let varName = parts.first?.trimmingCharacters(in: .whitespaces),
                   !varName.isEmpty && !varName.hasPrefix("#") && !varName.hasPrefix("//") {
                    variables.append(varName)
                }
            }
        }
        
        let variableList = variables.isEmpty ? "None" : variables.joined(separator: ", ")
        
        let systemPrompt = """
        You autocomplete calculator expressions. Output ONLY the missing characters to complete the input. Nothing else.
        
        Variables defined: \(variableList)
        
        Rules:
        1. Output ONLY the characters needed to complete the word/expression
        2. If input ends with partial variable name, complete it from the variables list
        3. Output NONE if nothing to complete
        
        Examples:
        Input: "15% of ph" (variable: phone) → "one"
        Input: "sum_so" (variables: sum_software) → "ftware"
        Input: "sqrt(" → "16)"
        Input: "5 + 5" → NONE
        """
        
        let request = GroqRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: "Input: \"\(input)\"")
            ],
            maxTokens: 20,
            temperature: 0.1
        )
        
        do {
            let response = try await sendRequest(request)
            var completion = response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // Strip quotes if present
            completion = completion.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
            
            if completion.isEmpty || completion.uppercased() == "NONE" {
                return nil
            }
            
            return completion
        } catch {
            print("GroqService error: \(error)")
            return nil
        }
    }
    
    private func sendRequest(_ request: GroqRequest) async throws -> GroqResponse {
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 5 // Fast timeout for autocomplete
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GroqError.requestFailed
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GroqResponse.self, from: data)
    }
}

// MARK: - Models

struct GroqRequest: Encodable {
    let model: String
    let messages: [GroqMessage]
    let maxTokens: Int
    let temperature: Double
}

struct GroqMessage: Codable {
    let role: String
    let content: String
}

struct GroqResponse: Decodable {
    let choices: [GroqChoice]
}

struct GroqChoice: Decodable {
    let message: GroqMessage
}

enum GroqError: Error, LocalizedError {
    case requestFailed
    case noAPIKey
    
    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "API request failed"
        case .noAPIKey:
            return "No Groq API key configured. Set GROQ_API_KEY environment variable or add to settings."
        }
    }
}

// MARK: - General Completion

extension GroqService {
    
    /// General completion method for flexible LLM usage
    func complete(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        temperature: Double,
        model: String
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GroqError.noAPIKey
        }
        
        var messages: [GroqMessage] = []
        if let system = systemPrompt {
            messages.append(.init(role: "system", content: system))
        }
        messages.append(.init(role: "user", content: prompt))
        
        let request = GroqRequest(
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            temperature: temperature
        )
        
        let response = try await sendRequest(request)
        return response.choices.first?.message.content ?? ""
    }
}

// MARK: - Document Generation

extension GroqService {
    
    /// Generate a complete Nimoy document from a natural language description
    /// - Parameter description: Natural language description of what to create
    /// - Returns: Generated Nimoy document
    func generateDocument(from description: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GroqError.noAPIKey
        }
        
        let request = GroqRequest(
            model: "llama-3.3-70b-versatile", // Use larger model for generation
            messages: [
                .init(role: "system", content: NimoyTemplates.generationContext),
                .init(role: "user", content: "Create a Nimoy document for: \(description)")
            ],
            maxTokens: 1000,
            temperature: 0.3
        )
        
        let response = try await sendRequest(request)
        var result = response.choices.first?.message.content ?? ""
        
        // Clean up markdown code fences if present
        result = result.replacingOccurrences(of: "```nimoy", with: "")
        result = result.replacingOccurrences(of: "```", with: "")
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return result
    }
}

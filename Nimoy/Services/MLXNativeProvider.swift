import Foundation
import MLXLLM
import MLXLMCommon
import os.log

private let logger = Logger(subsystem: "com.nimoy.app", category: "MLXNativeProvider")

/// Native MLX provider using mlx-swift-lm for on-device inference
@MainActor
class MLXNativeProvider: ObservableObject {
    static let shared = MLXNativeProvider()
    
    // Default small model for code generation
    static let defaultModelId = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
    
    @Published var isModelLoaded = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var statusMessage: String = ""
    @Published var error: String?
    
    private var modelContainer: ModelContainer?
    private var chatSession: ChatSession?
    
    private init() {
        // Check if model is already downloaded
        checkForExistingModel()
    }
    
    // MARK: - Public API
    
    /// Check if model is available (downloaded)
    var isAvailable: Bool {
        isModelLoaded || hasDownloadedModel()
    }
    
    /// Check if a model has been downloaded (in HuggingFace cache)
    func hasDownloadedModel() -> Bool {
        let hfCache = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
        
        let modelCacheName = "models--mlx-community--Qwen2.5-1.5B-Instruct-4bit"
        let cachedModel = hfCache.appendingPathComponent(modelCacheName)
        
        return FileManager.default.fileExists(atPath: cachedModel.path)
    }
    
    /// Check for existing model in standard HuggingFace cache
    func checkForExistingModel() {
        if hasDownloadedModel() {
            statusMessage = "Model available"
            logger.info("Found existing model in HuggingFace cache")
        } else {
            statusMessage = "No model downloaded"
        }
    }
    
    /// Download the model (or load if already cached)
    func downloadModel() async throws {
        guard !isDownloading else { return }
        
        isDownloading = true
        downloadProgress = 0
        error = nil
        statusMessage = "Starting download..."
        
        logger.info("Starting model download: \(Self.defaultModelId)")
        
        do {
            let modelConfig = ModelConfiguration(id: Self.defaultModelId)
            
            statusMessage = "Downloading model (~1GB)..."
            
            // Load the model (this downloads if not cached)
            let container = try await LLMModelFactory.shared.loadContainer(configuration: modelConfig) { progress in
                Task { @MainActor in
                    self.downloadProgress = progress.fractionCompleted
                    self.statusMessage = "Downloading: \(Int(progress.fractionCompleted * 100))%"
                }
            }
            
            self.modelContainer = container
            self.chatSession = ChatSession(container)
            self.isModelLoaded = true
            self.statusMessage = "Model ready"
            
            logger.info("Model loaded successfully")
            
        } catch {
            logger.error("Model download failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
            self.statusMessage = "Download failed"
            self.isDownloading = false
            throw error
        }
        
        isDownloading = false
    }
    
    /// Load the model for inference (if already downloaded)
    func loadModel() async throws {
        guard !isModelLoaded else { return }
        guard hasDownloadedModel() else {
            throw MLXNativeError.modelNotLoaded
        }
        
        statusMessage = "Loading model..."
        
        do {
            let modelConfig = ModelConfiguration(id: Self.defaultModelId)
            let container = try await LLMModelFactory.shared.loadContainer(configuration: modelConfig) { _ in }
            
            self.modelContainer = container
            self.chatSession = ChatSession(container)
            self.isModelLoaded = true
            self.statusMessage = "Model ready"
            
            logger.info("Model loaded for inference")
        } catch {
            logger.error("Failed to load model: \(error.localizedDescription)")
            self.error = error.localizedDescription
            throw error
        }
    }
    
    /// Generate text completion
    func complete(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        temperature: Double
    ) async throws -> String {
        // Ensure model is loaded
        if !isModelLoaded {
            try await loadModel()
        }
        
        guard let session = chatSession else {
            throw MLXNativeError.modelNotLoaded
        }
        
        logger.info("Generating with maxTokens=\(maxTokens), temp=\(temperature)")
        
        // Set system instructions if provided
        if let system = systemPrompt {
            session.instructions = system
        }
        
        // Configure generation parameters
        session.generateParameters = GenerateParameters(temperature: Float(temperature))
        
        // Use ChatSession for generation
        var result = ""
        for try await token in session.streamResponse(to: prompt) {
            result += token
            if result.count >= maxTokens {
                break
            }
        }
        
        logger.info("Generation complete, length=\(result.count)")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Unload model to free memory
    func unloadModel() {
        chatSession = nil
        modelContainer = nil
        isModelLoaded = false
        statusMessage = "Model unloaded"
        logger.info("Model unloaded")
    }
}

// MARK: - Errors

enum MLXNativeError: Error, LocalizedError {
    case modelNotLoaded
    case downloadFailed(String)
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Local model not loaded. Download it first in Settings."
        case .downloadFailed(let reason):
            return "Model download failed: \(reason)"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        }
    }
}

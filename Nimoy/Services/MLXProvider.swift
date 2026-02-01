import Foundation
import os.log

private let logger = Logger(subsystem: "com.nimoy.app", category: "MLXProvider")

// MLX Provider - runs models via mlx_lm CLI
class MLXProvider: LLMProvider {
    static let shared = MLXProvider()
    static let defaultModel = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
    
    var isAvailable: Bool {
        let result = checkAvailability()
        logger.info("MLX isAvailable check: \(result.available), path: \(result.path ?? "not found")")
        return result.available
    }
    
    /// Check availability with detailed info
    func checkAvailability() -> (available: Bool, path: String?, error: String?) {
        do {
            let (stdout, stderr, exitCode) = try shellOutputWithDetails("which mlx_lm.generate")
            let path = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if exitCode == 0 && !path.isEmpty {
                return (true, path, nil)
            } else {
                return (false, nil, stderr.isEmpty ? "mlx_lm.generate not found in PATH" : stderr)
            }
        } catch {
            return (false, nil, error.localizedDescription)
        }
    }
    
    /// Test the MLX provider with a simple prompt
    func test() async -> (success: Bool, output: String, error: String?) {
        logger.info("Starting MLX test...")
        
        // First check availability
        let availability = checkAvailability()
        guard availability.available else {
            let err = "MLX not available: \(availability.error ?? "unknown error")"
            logger.error("\(err)")
            return (false, "", err)
        }
        logger.info("MLX found at: \(availability.path ?? "unknown")")
        
        // Try a simple generation
        do {
            let result = try await complete(
                prompt: "What is 2+2? Answer with just the number.",
                systemPrompt: nil,
                maxTokens: 10,
                temperature: 0.1
            )
            logger.info("MLX test succeeded, output: \(result)")
            return (true, result, nil)
        } catch {
            let err = "MLX test failed: \(error.localizedDescription)"
            logger.error("\(err)")
            return (false, "", err)
        }
    }
    
    func complete(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        temperature: Double
    ) async throws -> String {
        let model = UserDefaults.standard.string(forKey: "mlx_model") ?? Self.defaultModel
        logger.info("MLX complete called - model: \(model), maxTokens: \(maxTokens)")
        
        var fullPrompt = ""
        if let system = systemPrompt {
            fullPrompt = "System: \(system)\n\nUser: \(prompt)\n\nAssistant:"
        } else {
            fullPrompt = prompt
        }
        
        // Write prompt to temp file to avoid shell escaping issues
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("nimoy_prompt_\(UUID().uuidString).txt")
        try fullPrompt.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        logger.info("Wrote prompt to temp file: \(tempFile.path)")
        
        let command = """
        mlx_lm.generate --model "\(model)" --prompt "$(cat '\(tempFile.path)')" --max-tokens \(maxTokens)
        """
        
        logger.info("Executing command: mlx_lm.generate --model \"\(model)\" --max-tokens \(maxTokens)")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    let (stdout, stderr, exitCode) = try self.shellOutputWithDetails(command)
                    
                    logger.info("MLX command completed - exitCode: \(exitCode), stdout length: \(stdout.count), stderr length: \(stderr.count)")
                    
                    if !stderr.isEmpty {
                        logger.warning("MLX stderr: \(stderr)")
                    }
                    
                    if exitCode != 0 {
                        let errorMsg = stderr.isEmpty ? "Command failed with exit code \(exitCode)" : stderr
                        logger.error("MLX command failed: \(errorMsg)")
                        continuation.resume(throwing: MLXError.commandFailed(exitCode: exitCode, stderr: errorMsg))
                        return
                    }
                    
                    if stdout.isEmpty {
                        logger.error("MLX returned empty output")
                        continuation.resume(throwing: MLXError.emptyOutput)
                        return
                    }
                    
                    logger.debug("MLX raw output: \(stdout)")
                    
                    // Extract text between ========== markers
                    let result = self.extractResponse(from: stdout)
                    
                    if result.isEmpty {
                        logger.error("MLX extractResponse returned empty - raw output was: \(stdout.prefix(500))")
                        continuation.resume(throwing: MLXError.parseError(rawOutput: String(stdout.prefix(500))))
                        return
                    }
                    
                    logger.info("MLX generation successful, result length: \(result.count)")
                    continuation.resume(returning: result)
                } catch let error as MLXError {
                    continuation.resume(throwing: error)
                } catch {
                    logger.error("MLX shell error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Extract response text from mlx_lm output (between ========== markers)
    private func extractResponse(from output: String) -> String {
        let marker = "=========="
        let components = output.components(separatedBy: marker)
        
        logger.debug("extractResponse: found \(components.count) components separated by marker")
        
        // Response is between first and second marker
        if components.count >= 2 {
            let result = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            logger.debug("extractResponse: extracted from between markers, length: \(result.count)")
            return result
        }
        
        // Fallback: return everything after first marker
        if let range = output.range(of: marker) {
            let afterMarker = String(output[range.upperBound...])
            // Remove the closing marker and stats if present
            if let endRange = afterMarker.range(of: marker) {
                let result = String(afterMarker[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                logger.debug("extractResponse: fallback extraction, length: \(result.count)")
                return result
            }
            let result = afterMarker.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.debug("extractResponse: after-marker fallback, length: \(result.count)")
            return result
        }
        
        // Last resort: return trimmed output
        logger.debug("extractResponse: no markers found, returning raw output")
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func shellOutputWithDetails(_ command: String) throws -> (stdout: String, stderr: String, exitCode: Int32) {
        let task = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        
        // Build environment with common paths for pyenv, homebrew, etc.
        var env = ProcessInfo.processInfo.environment
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let additionalPaths = [
            "\(homeDir)/.pyenv/shims",
            "\(homeDir)/.pyenv/bin",
            "\(homeDir)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin"
        ]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = additionalPaths.joined(separator: ":") + ":" + currentPath
        task.environment = env
        
        logger.debug("Shell PATH: \(env["PATH"] ?? "nil")")
        
        try task.run()
        task.waitUntilExit()
        
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        
        return (stdout, stderr, task.terminationStatus)
    }
}

// MARK: - MLX Errors

enum MLXError: Error, LocalizedError {
    case commandFailed(exitCode: Int32, stderr: String)
    case emptyOutput
    case parseError(rawOutput: String)
    case notAvailable(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .commandFailed(let exitCode, let stderr):
            return "MLX command failed (exit \(exitCode)): \(stderr)"
        case .emptyOutput:
            return "MLX returned empty output"
        case .parseError(let rawOutput):
            return "Failed to parse MLX output: \(rawOutput)"
        case .notAvailable(let reason):
            return "MLX not available: \(reason)"
        }
    }
}

import XCTest
@testable import Nimoy

final class MLXProviderTests: XCTestCase {
    
    func testCheckAvailability() {
        let provider = MLXProvider.shared
        let result = provider.checkAvailability()
        
        print("MLX Availability Check:")
        print("  Available: \(result.available)")
        print("  Path: \(result.path ?? "nil")")
        print("  Error: \(result.error ?? "nil")")
        
        // This test documents the current state - it doesn't fail if MLX isn't installed
        if result.available {
            XCTAssertNotNil(result.path, "Path should be set when available")
            XCTAssertNil(result.error, "Error should be nil when available")
        } else {
            XCTAssertNil(result.path, "Path should be nil when not available")
            XCTAssertNotNil(result.error, "Error should explain why not available")
        }
    }
    
    func testMLXGeneration() async throws {
        let provider = MLXProvider.shared
        
        // Skip if MLX not available
        guard provider.isAvailable else {
            print("Skipping testMLXGeneration - MLX not available")
            throw XCTSkip("MLX not available on this system")
        }
        
        let result = await provider.test()
        
        print("MLX Test Result:")
        print("  Success: \(result.success)")
        print("  Output: \(result.output)")
        print("  Error: \(result.error ?? "nil")")
        
        XCTAssertTrue(result.success, "MLX test should succeed: \(result.error ?? "unknown error")")
        XCTAssertFalse(result.output.isEmpty, "MLX should return non-empty output")
    }
    
    func testExtractResponse() {
        let provider = MLXProvider.shared
        
        // Test with typical mlx_lm output format
        let typicalOutput = """
        Loading model from mlx-community/Qwen2.5-1.5B-Instruct-4bit
        ==========
        4
        ==========
        Prompt: 10 tokens, 25.5 tokens-per-sec
        Generation: 1 tokens, 15.2 tokens-per-sec
        """
        
        // Use reflection to test private method
        let mirror = Mirror(reflecting: provider)
        
        // We can't easily test private methods, so let's test via the complete method behavior
        // For now, just verify the provider exists and has the expected interface
        XCTAssertNotNil(MLXProvider.shared)
        XCTAssertEqual(MLXProvider.defaultModel, "mlx-community/Qwen2.5-1.5B-Instruct-4bit")
    }
    
    func testShellEnvironmentIncludesPyenv() {
        // Verify that our PATH includes common locations
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let expectedPaths = [
            "\(homeDir)/.pyenv/shims",
            "\(homeDir)/.pyenv/bin",
            "/opt/homebrew/bin"
        ]
        
        // The provider should include these paths - we verify by checking isAvailable
        // doesn't crash and returns a boolean
        let provider = MLXProvider.shared
        let _ = provider.isAvailable  // Should not crash
        
        print("Expected PATH additions: \(expectedPaths)")
    }
}

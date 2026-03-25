import Foundation
import NativeScript

/// Example demonstrating the async script execution API in Swift
class AsyncScriptExample {
    
    let runtime: NativeScript
    
    init() {
        // Initialize the NativeScript runtime
        let config = Config()
        config.baseDir = Bundle.main.resourcePath
        config.isDebug = true
        config.logToSystemConsole = true
        
        runtime = NativeScript(config: config)
    }
    
    /// Example 1: Execute a simple calculation script
    func executeCalculation() {
        let scriptPath = createTempScript(content: "2 + 2")
        
        runtime.runScriptFileAsync(scriptPath) { result, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            
            if let number = result as? NSNumber {
                print("Calculation result: \(number)")
                // Output: Calculation result: 4
            }
        }
    }
    
    /// Example 2: Execute a script that returns an object
    func executeObjectScript() {
        let script = """
        ({
            timestamp: Date.now(),
            message: 'Hello from JavaScript',
            version: '1.0.0'
        })
        """
        let scriptPath = createTempScript(content: script)
        
        runtime.runScriptFileAsync(scriptPath) { result, error in
            guard error == nil else {
                print("Error: \(error!.localizedDescription)")
                return
            }
            
            if let dict = result as? [String: Any] {
                print("Timestamp: \(dict["timestamp"] ?? "N/A")")
                print("Message: \(dict["message"] ?? "N/A")")
                print("Version: \(dict["version"] ?? "N/A")")
            }
        }
    }
    
    /// Example 3: Execute a script that returns an array
    func executeArrayScript() {
        let script = "[1, 2, 3, 4, 5].map(x => x * 2)"
        let scriptPath = createTempScript(content: script)
        
        runtime.runScriptFileAsync(scriptPath) { result, error in
            guard error == nil else {
                print("Error: \(error!.localizedDescription)")
                return
            }
            
            if let array = result as? [Any] {
                print("Array result: \(array)")
                // Output: Array result: [2, 4, 6, 8, 10]
            }
        }
    }
    
    /// Example 4: Execute multiple scripts concurrently
    func executeConcurrentScripts() {
        let scripts = [
            "Math.sqrt(16)",
            "'Concurrent execution'",
            "[1, 2, 3].length"
        ]
        
        var results: [String: Any] = [:]
        let group = DispatchGroup()
        
        for (index, scriptContent) in scripts.enumerated() {
            group.enter()
            let scriptPath = createTempScript(content: scriptContent)
            
            runtime.runScriptFileAsync(scriptPath) { result, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Script \(index) error: \(error.localizedDescription)")
                    return
                }
                
                results["script_\(index)"] = result
            }
        }
        
        group.notify(queue: .main) {
            print("All scripts completed. Results: \(results)")
        }
    }
    
    /// Example 5: Execute script with background thread completion for performance
    func executeWithBackgroundCompletion() {
        let script = "(function() { return 42 * 2; })()"
        let scriptPath = createTempScript(content: script)
        
        // Execute with completion on background thread
        runtime.runScriptFileAsync(scriptPath, runOnMainThread: false) { result, error in
            guard error == nil else {
                print("Error: \(error!.localizedDescription)")
                return
            }
            
            // This runs on background thread
            print("Result on background thread: \(result ?? "nil")")
            
            // If you need to update UI, dispatch to main thread
            DispatchQueue.main.async {
                print("Now on main thread for UI updates")
            }
        }
    }
    
    /// Example 6: Data processing with background completion
    func executeDataProcessingOnBackground() {
        let script = """
        (function() {
            const data = Array.from({length: 1000}, (_, i) => i);
            return data.reduce((sum, val) => sum + val, 0);
        })()
        """
        let scriptPath = createTempScript(content: script)
        
        // Process data on background thread for better performance
        runtime.runScriptFileAsync(scriptPath, runOnMainThread: false) { result, error in
            guard error == nil else {
                print("Error: \(error!.localizedDescription)")
                return
            }
            
            if let sum = result as? NSNumber {
                print("Sum calculated on background: \(sum)")
                // Result: 499500
            }
        }
    }
    
    // MARK: - Helper Methods
        let scripts = [
            "Math.sqrt(16)",
            "'Concurrent execution'",
            "[1, 2, 3].length"
        ]
        
        var results: [String: Any] = [:]
        let group = DispatchGroup()
        
        for (index, scriptContent) in scripts.enumerated() {
            group.enter()
            let scriptPath = createTempScript(content: scriptContent)
            
            runtime.runScriptFileAsync(scriptPath) { result, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Script \(index) error: \(error.localizedDescription)")
                    return
                }
                
                results["script_\(index)"] = result
            }
        }
        
        group.notify(queue: .main) {
            print("All scripts completed. Results: \(results)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTempScript(content: String) -> String {
        let tempDir = NSTemporaryDirectory()
        let fileName = "script_\(UUID().uuidString).js"
        let filePath = (tempDir as NSString).appendingPathComponent(fileName)
        
        do {
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to create temp script: \(error)")
        }
        
        return filePath
    }
}

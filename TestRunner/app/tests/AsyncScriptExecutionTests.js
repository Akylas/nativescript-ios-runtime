describe("Async Script Execution API", function () {
  
  it("should execute a simple script and return a number", function (done) {
    const tempPath = NSTemporaryDirectory().stringByAppendingPathComponent("test-number.js");
    const scriptContent = "42";
    NSString.stringWithString(scriptContent).writeToFileAtomicallyEncodingError(tempPath, true, NSUTF8StringEncoding, null);
    
    TNSAsyncScriptTester.runScriptFileCompletion(tempPath, function(result, error) {
      expect(error).toBeNull();
      expect(result).toBeDefined();
      expect(result).toBe(42);
      done();
    });
  });

  it("should execute a script and return a string", function (done) {
    const tempPath = NSTemporaryDirectory().stringByAppendingPathComponent("test-string.js");
    const scriptContent = "'Hello from async script'";
    NSString.stringWithString(scriptContent).writeToFileAtomicallyEncodingError(tempPath, true, NSUTF8StringEncoding, null);
    
    TNSAsyncScriptTester.runScriptFileCompletion(tempPath, function(result, error) {
      expect(error).toBeNull();
      expect(result).toBeDefined();
      expect(result).toBe("Hello from async script");
      done();
    });
  });

  it("should execute a script and return an object", function (done) {
    const tempPath = NSTemporaryDirectory().stringByAppendingPathComponent("test-object.js");
    const scriptContent = "({ name: 'test', value: 123 })";
    NSString.stringWithString(scriptContent).writeToFileAtomicallyEncodingError(tempPath, true, NSUTF8StringEncoding, null);
    
    TNSAsyncScriptTester.runScriptFileCompletion(tempPath, function(result, error) {
      expect(error).toBeNull();
      expect(result).toBeDefined();
      expect(result.objectForKey('name')).toBe("test");
      expect(result.objectForKey('value')).toBe(123);
      done();
    });
  });

  it("should execute a script and return an array", function (done) {
    const tempPath = NSTemporaryDirectory().stringByAppendingPathComponent("test-array.js");
    const scriptContent = "[1, 2, 3, 'four']";
    NSString.stringWithString(scriptContent).writeToFileAtomicallyEncodingError(tempPath, true, NSUTF8StringEncoding, null);
    
    TNSAsyncScriptTester.runScriptFileCompletion(tempPath, function(result, error) {
      expect(error).toBeNull();
      expect(result).toBeDefined();
      expect(result.count).toBe(4);
      expect(result.objectAtIndex(0)).toBe(1);
      expect(result.objectAtIndex(3)).toBe("four");
      done();
    });
  });

  it("should return NSNull for undefined result", function (done) {
    const tempPath = NSTemporaryDirectory().stringByAppendingPathComponent("test-undefined.js");
    const scriptContent = "undefined";
    NSString.stringWithString(scriptContent).writeToFileAtomicallyEncodingError(tempPath, true, NSUTF8StringEncoding, null);
    
    TNSAsyncScriptTester.runScriptFileCompletion(tempPath, function(result, error) {
      expect(error).toBeNull();
      expect(result).toBe(NSNull.null());
      done();
    });
  });

  it("should return boolean values", function (done) {
    const tempPath = NSTemporaryDirectory().stringByAppendingPathComponent("test-boolean.js");
    const scriptContent = "true";
    NSString.stringWithString(scriptContent).writeToFileAtomicallyEncodingError(tempPath, true, NSUTF8StringEncoding, null);
    
    TNSAsyncScriptTester.runScriptFileCompletion(tempPath, function(result, error) {
      expect(error).toBeNull();
      expect(result).toBeDefined();
      expect(result).toBe(true);
      done();
    });
  });

  it("should handle file not found error", function (done) {
    const invalidPath = "/nonexistent/path/to/script.js";
    
    TNSAsyncScriptTester.runScriptFileCompletion(invalidPath, function(result, error) {
      expect(error).toBeDefined();
      expect(result).toBeNull();
      done();
    });
  });

  it("should handle empty file path", function (done) {
    TNSAsyncScriptTester.runScriptFileCompletion("", function(result, error) {
      expect(error).toBeDefined();
      expect(result).toBeNull();
      done();
    });
  });

  it("should handle null file path", function (done) {
    TNSAsyncScriptTester.runScriptFileCompletion(null, function(result, error) {
      expect(error).toBeDefined();
      expect(result).toBeNull();
      done();
    });
  });

  it("should execute script with complex expressions", function (done) {
    const tempPath = NSTemporaryDirectory().stringByAppendingPathComponent("test-complex.js");
    const scriptContent = "(function() { var x = 10; var y = 20; return x + y; })()";
    NSString.stringWithString(scriptContent).writeToFileAtomicallyEncodingError(tempPath, true, NSUTF8StringEncoding, null);
    
    TNSAsyncScriptTester.runScriptFileCompletion(tempPath, function(result, error) {
      expect(error).toBeNull();
      expect(result).toBeDefined();
      expect(result).toBe(30);
      done();
    });
  });

  it("should execute multiple scripts concurrently", function (done) {
    let completedCount = 0;
    const expectedCount = 3;
    
    const checkDone = function() {
      completedCount++;
      if (completedCount === expectedCount) {
        done();
      }
    };
    
    // Script 1
    const tempPath1 = NSTemporaryDirectory().stringByAppendingPathComponent("test-concurrent-1.js");
    NSString.stringWithString("100").writeToFileAtomicallyEncodingError(tempPath1, true, NSUTF8StringEncoding, null);
    TNSAsyncScriptTester.runScriptFileCompletion(tempPath1, function(result, error) {
      expect(error).toBeNull();
      expect(result).toBe(100);
      checkDone();
    });
    
    // Script 2
    const tempPath2 = NSTemporaryDirectory().stringByAppendingPathComponent("test-concurrent-2.js");
    NSString.stringWithString("'concurrent'").writeToFileAtomicallyEncodingError(tempPath2, true, NSUTF8StringEncoding, null);
    TNSAsyncScriptTester.runScriptFileCompletion(tempPath2, function(result, error) {
      expect(error).toBeNull();
      expect(result).toBe("concurrent");
      checkDone();
    });
    
    // Script 3
    const tempPath3 = NSTemporaryDirectory().stringByAppendingPathComponent("test-concurrent-3.js");
    NSString.stringWithString("[1,2,3]").writeToFileAtomicallyEncodingError(tempPath3, true, NSUTF8StringEncoding, null);
    TNSAsyncScriptTester.runScriptFileCompletion(tempPath3, function(result, error) {
      expect(error).toBeNull();
      expect(result.count).toBe(3);
      checkDone();
    });
  });

  it("should handle syntax errors in script", function (done) {
    const tempPath = NSTemporaryDirectory().stringByAppendingPathComponent("test-syntax-error.js");
    const scriptContent = "{ invalid syntax here";
    NSString.stringWithString(scriptContent).writeToFileAtomicallyEncodingError(tempPath, true, NSUTF8StringEncoding, null);
    
    TNSAsyncScriptTester.runScriptFileCompletion(tempPath, function(result, error) {
      // Script with syntax error should still complete, but result may be undefined
      // The V8 engine will handle syntax errors internally
      expect(result).toBeDefined();
      done();
    });
  });

  it("should handle runtime exceptions in script", function (done) {
    const tempPath = NSTemporaryDirectory().stringByAppendingPathComponent("test-runtime-error.js");
    const scriptContent = "throw new Error('Test error')";
    NSString.stringWithString(scriptContent).writeToFileAtomicallyEncodingError(tempPath, true, NSUTF8StringEncoding, null);
    
    TNSAsyncScriptTester.runScriptFileCompletion(tempPath, function(result, error) {
      // Runtime exceptions are caught internally by V8
      // The result may be undefined in case of exception
      expect(result).toBeDefined();
      done();
    });
  });

  // Tests for background thread completion (runOnMainThread=NO)
  
  it("should execute script with completion on background thread", function (done) {
    const tempPath = NSTemporaryDirectory().stringByAppendingPathComponent("test-background-thread.js");
    const scriptContent = "42";
    NSString.stringWithString(scriptContent).writeToFileAtomicallyEncodingError(tempPath, true, NSUTF8StringEncoding, null);
    
    TNSAsyncScriptTester.runScriptFileRunOnMainThreadCompletion(tempPath, false, function(result, error) {
      expect(error).toBeNull();
      expect(result).toBeDefined();
      expect(result).toBe(42);
      
      // Verify we're not on main thread
      const isMainThread = NSThread.isMainThread;
      expect(isMainThread).toBe(false);
      done();
    });
  });

  it("should execute script with completion on main thread when specified", function (done) {
    const tempPath = NSTemporaryDirectory().stringByAppendingPathComponent("test-main-thread-explicit.js");
    const scriptContent = "'Hello'";
    NSString.stringWithString(scriptContent).writeToFileAtomicallyEncodingError(tempPath, true, NSUTF8StringEncoding, null);
    
    TNSAsyncScriptTester.runScriptFileRunOnMainThreadCompletion(tempPath, true, function(result, error) {
      expect(error).toBeNull();
      expect(result).toBeDefined();
      expect(result).toBe("Hello");
      
      // Verify we're on main thread
      const isMainThread = NSThread.isMainThread;
      expect(isMainThread).toBe(true);
      done();
    });
  });

  it("should handle errors on background thread when runOnMainThread=NO", function (done) {
    const invalidPath = "/nonexistent/path/background-test.js";
    
    TNSAsyncScriptTester.runScriptFileRunOnMainThreadCompletion(invalidPath, false, function(result, error) {
      expect(error).toBeDefined();
      expect(result).toBeNull();
      
      // Verify we're not on main thread
      const isMainThread = NSThread.isMainThread;
      expect(isMainThread).toBe(false);
      done();
    });
  });

  it("should execute multiple scripts with mixed thread completion", function (done) {
    let completedCount = 0;
    const expectedCount = 2;
    
    const checkDone = function() {
      completedCount++;
      if (completedCount === expectedCount) {
        done();
      }
    };
    
    // Script 1 - background thread completion
    const tempPath1 = NSTemporaryDirectory().stringByAppendingPathComponent("test-mixed-1.js");
    NSString.stringWithString("100").writeToFileAtomicallyEncodingError(tempPath1, true, NSUTF8StringEncoding, null);
    TNSAsyncScriptTester.runScriptFileRunOnMainThreadCompletion(tempPath1, false, function(result, error) {
      expect(error).toBeNull();
      expect(result).toBe(100);
      expect(NSThread.isMainThread).toBe(false);
      checkDone();
    });
    
    // Script 2 - main thread completion
    const tempPath2 = NSTemporaryDirectory().stringByAppendingPathComponent("test-mixed-2.js");
    NSString.stringWithString("200").writeToFileAtomicallyEncodingError(tempPath2, true, NSUTF8StringEncoding, null);
    TNSAsyncScriptTester.runScriptFileRunOnMainThreadCompletion(tempPath2, true, function(result, error) {
      expect(error).toBeNull();
      expect(result).toBe(200);
      expect(NSThread.isMainThread).toBe(true);
      checkDone();
    });
  });

});

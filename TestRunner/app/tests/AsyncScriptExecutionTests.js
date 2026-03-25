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

});

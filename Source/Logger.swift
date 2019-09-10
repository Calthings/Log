//
// Logger.swift
//
// Copyright (c) 2015-2016 Damien (http://delba.io)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

private let benchmarker = Benchmarker()

public enum Level: Int {
    case trace, debug, info, warning, error
    
    var description: String {
        return String(describing: self).uppercased()
    }
}

extension Level: Comparable {}

public func ==(x: Level, y: Level) -> Bool {
    return x.rawValue == y.rawValue
}

public func <(x: Level, y: Level) -> Bool {
    return x.rawValue < y.rawValue
}

open class Logger {
    public static let fileName = "log-\(String(Date().timeIntervalSince1970)).log"
    public static let loggedErrorStatements = Set<String>()
    
    /// The logger state.
    public var enabled: Bool = true
    
    /// The logger formatter.
    public var formatter: Formatter {
        didSet { formatter.logger = self }
    }
    
    /// The logger theme.
    public var theme: Theme?
    
    /// The minimum level of severity.
    public var minLevel: Level
    
    /// The logger format.
    public var format: String {
        return formatter.description
    }

    /// The logger colors
    public var colors: String {
        return theme?.description ?? ""
    }

    /// Path for app logs
    public private(set) var logPath: URL

    /// The queue used for logging.
    private let queue = DispatchQueue(label: "delba.log")
    
    public var didAddLogString: ((_ text: String) -> Void)?
    public var didLogError: ((_ filename: String, _ line: Int, _ logMessage: String) -> Void)?

    /**
     Creates and returns a new logger.
     
     - parameter formatter: The formatter.
     - parameter theme:     The theme.
     - parameter minLevel:  The minimum level of severity.
     
     - returns: A newly created logger.
     */
    public init(formatter: Formatter = .default, theme: Theme? = nil, minLevel: Level = .trace) {
        self.logPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(Logger.fileName)
        self.formatter = formatter
        self.theme = theme
        self.minLevel = minLevel
        
        formatter.logger = self

        signal(SIGINT, SIG_IGN)
    }
    
    /**
     Logs a message with a trace severity level.
     
     - parameter items:      The items to log.
     - parameter separator:  The separator between the items.
     - parameter terminator: The terminator of the log message.
     - parameter file:       The file in which the log happens.
     - parameter line:       The line at which the log happens.
     - parameter column:     The column at which the log happens.
     - parameter function:   The function in which the log happens.
     */
    open func trace(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        log(.trace, items, separator, terminator, file, line, column, function)
    }
    
    /**
     Logs a message with a debug severity level.
     
     - parameter items:      The items to log.
     - parameter separator:  The separator between the items.
     - parameter terminator: The terminator of the log message.
     - parameter file:       The file in which the log happens.
     - parameter line:       The line at which the log happens.
     - parameter column:     The column at which the log happens.
     - parameter function:   The function in which the log happens.
     */
    open func debug(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        log(.debug, items, separator, terminator, file, line, column, function)
    }
    
    /**
     Logs a message with an info severity level.
     
     - parameter items:      The items to log.
     - parameter separator:  The separator between the items.
     - parameter terminator: The terminator of the log message.
     - parameter file:       The file in which the log happens.
     - parameter line:       The line at which the log happens.
     - parameter column:     The column at which the log happens.
     - parameter function:   The function in which the log happens.
     */
    open func info(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        log(.info, items, separator, terminator, file, line, column, function)
    }
    
    /**
     Logs a message with a warning severity level.
     
     - parameter items:      The items to log.
     - parameter separator:  The separator between the items.
     - parameter terminator: The terminator of the log message.
     - parameter file:       The file in which the log happens.
     - parameter line:       The line at which the log happens.
     - parameter column:     The column at which the log happens.
     - parameter function:   The function in which the log happens.
     */
    open func warning(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        log(.warning, items, separator, terminator, file, line, column, function)
    }
    
    /**
     Logs a message with an error severity level.
     
     - parameter items:      The items to log.
     - parameter separator:  The separator between the items.
     - parameter terminator: The terminator of the log message.
     - parameter file:       The file in which the log happens.
     - parameter line:       The line at which the log happens.
     - parameter column:     The column at which the log happens.
     - parameter function:   The function in which the log happens.
     */
    open func error(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        log(.error, items, separator, terminator, file, line, column, function)
    }
    
    /**
         The expect() functions below can use used to replace the need to log an error when guarding an expected value
         It will also log at the exact line and column of the unexpected value, instead of at the location of the log
     
         Instead of:
             guard let variable = optional else {
                 Log.error("The expected optional was nil")
                 return
             }
             guard variable != value else {
                Log.warning("Warning!")
                return
             }
             guard let variable1 = optional1, variable2 != value, let variable3 = optional3 else {
                 Log.error("optional1 was \(optional1 ?? ""), optional2 was \(optional2 ?? ""), optional3 was \(optional3)")
                 return
             }
     
         Do:
             guard let variable = expectNonNil(optional) else {
                 return
             }
             guard expect(variable != value, level: .warning) else {
                return
             }
             guard let variable1 = expectNonNil(optional1), expectNonNil(variable2 != value), let variable3 = expectNonNil(optional3) else {
                return
             }
    */
    
    /// Log an error when the optional value is not nil, at the location the expect function was called
    public func expectNonNil<T>(_ optional: T?, level: Level = .error, message: String? = nil, separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) -> T? {
        let message = message ?? "Unexpected value is nil!"
        let expression = (optional != nil)
        
        _ = expect(expression, level: level, message: message, separator: separator, terminator: terminator, file: file, line: line, column: column, function: function)
        
        return optional
    }
    
    /// Log an error when the expression is `condition`, at the location the expression was found to be false
    public func expect(_ expression: Bool, is condition: Bool = true, level: Level = .error, message: String? = nil, separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) -> Bool {
        if expression == condition  {
            return condition
        }
        
        var message = message ?? "Expected \(expression) expression was \(condition)!"
        message += " Column: \(column)"
        
        log(level, [message], separator, terminator, file, line, column, function)
        
        return expression
    }
    
    /**
     Logs a message.
     
     - parameter level:      The severity level.
     - parameter items:      The items to log.
     - parameter separator:  The separator between the items.
     - parameter terminator: The terminator of the log message.
     - parameter file:       The file in which the log happens.
     - parameter line:       The line at which the log happens.
     - parameter column:     The column at which the log happens.
     - parameter function:   The function in which the log happens.
     */
    private func log(_ level: Level, _ items: [Any], _ separator: String, _ terminator: String, _ file: String, _ line: Int, _ column: Int, _ function: String) {
        guard enabled && level >= minLevel else { return }
        
        let date = Date()
        
        let result = formatter.format(
            level: level,
            items: items,
            separator: separator,
            terminator: terminator,
            file: file,
            line: line,
            column: column,
            function: function,
            date: date
        )
        
        if level == .error {
            let filename = formatter.format(file: file, fullPath: false, fileExtension: true)
            didLogError?(filename, line, result)
        }
        
        #if DEBUG
        log(result: result)
        if level == .error {
            let key = "\(file):\(line):\(column)"
            guard !Logger.loggedErrorStatements.contains(key) else { return }
            Logger.loggedErrorStatements.insert(key)
            kill(getpid(), SIGINT) // break
        }
        #else
        queue.async { self.log(result: result) }
        #endif
    }
    
    private func log(result: String) {
        Swift.print(result, separator: "", terminator: "")
        appendStringToLog(result)
    }
    
    /**
     Measures the performance of code.
     
     - parameter description: The measure description.
     - parameter n:           The number of iterations.
     - parameter file:        The file in which the measure happens.
     - parameter line:        The line at which the measure happens.
     - parameter column:      The column at which the measure happens.
     - parameter function:    The function in which the measure happens.
     - parameter block:       The block to measure.
     */
    public func measure(_ description: String? = nil, iterations n: Int = 10, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function, block: () -> Void) {
        guard enabled && .debug >= minLevel else { return }
        
        let measure = benchmarker.measure(description, iterations: n, block: block)
        
        let date = Date()
        
        let result = formatter.format(
            description: measure.description,
            average: measure.average,
            relativeStandardDeviation: measure.relativeStandardDeviation,
            file: file,
            line: line,
            column: column,
            function: function,
            date: date
        )
        
        queue.async {
            Swift.print(result)
        }
    }
    
    public func sessionLog() -> String {
        var log = ""
        do {
         log = try String(contentsOf: logPath, encoding: .utf8)
        } catch {
           self.error("Can't fetch session log")
        }
        return log
    }
    
    // MARK: Private Methods
    
    private func appendStringToLog(_ string: String) {
        let textToAppend = string.data(using: .utf8, allowLossyConversion: false)!
        didAddLogString?(string)
        if FileManager.default.fileExists(atPath: self.logPath.path) {
            do {
                let fileHandle = try FileHandle(forWritingTo: self.logPath)
                fileHandle.seekToEndOfFile()
                fileHandle.write(textToAppend)
                fileHandle.closeFile()
            } catch {
                print("LOG: Can't open fileHandle \(error)")
            }
        } else {
            do {
                try textToAppend.write(to: self.logPath, options: .atomicWrite)
            } catch {
                print("LOG: Can't write to file \"\(self.logPath)\": \(error)")
            }
        }
    }
    
    private func cleanLogFile() {
        do {
            try FileManager.default.removeItem(at: logPath)
        } catch {
            self.error("Can't delete log file at path \(logPath)")
        }
    }
}

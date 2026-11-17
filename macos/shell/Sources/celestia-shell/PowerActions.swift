import Foundation

enum PowerActions {
    private typealias LockFunction = @convention(c) () -> Int32
    private static let loginFramework = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"

    static func lock() {
        guard let handle = dlopen(loginFramework, RTLD_LAZY),
              let symbol = dlsym(handle, "SACLockScreenImmediate")
        else { return shellLog("lock: SACLockScreenImmediate unavailable") }
        _ = unsafeBitCast(symbol, to: LockFunction.self)()
    }

    static func sleep() { run(#"tell application "System Events" to sleep"#) }
    static func restart() { run(#"tell application "loginwindow" to «event aevtrrst»"#) }
    static func logOut() { run(#"tell application "loginwindow" to «event aevtlogo»"#) }
    static func shutDown() { run(#"tell application "loginwindow" to «event aevtrsdn»"#) }

    private static func run(_ script: String) {
        Task.detached {
            if runProcess("/usr/bin/osascript", ["-e", script]) == nil { shellLog("power action failed: \(script)") }
        }
    }
}

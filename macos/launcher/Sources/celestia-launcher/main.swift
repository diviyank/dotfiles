import Foundation
#if canImport(AppKit)
import AppKit
import LauncherCore
#else
FileHandle.standardError.write(Data("celestia-launcher: macOS only\n".utf8))
exit(1)
#endif

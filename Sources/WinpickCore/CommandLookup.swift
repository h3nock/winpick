import Darwin
import Foundation

enum CommandLookup {
    static func exists(_ name: String) -> Bool {
        guard let path = ProcessInfo.processInfo.environment["PATH"] else {
            return false
        }

        return path
            .split(separator: ":")
            .contains { directory in
                let candidate = "\(directory)/\(name)"
                return access(candidate, X_OK) == 0
            }
    }
}

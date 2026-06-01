import AppKit
import Foundation

public struct FrontmostWindowResolver {
    public init() {}

    public func currentWindow(in windows: [WindowRecord]) -> WindowRecord? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            return nil
        }

        return windows
            .filter { $0.pid == pid }
            .sorted { lhs, rhs in
                if lhs.layer != rhs.layer { return lhs.layer < rhs.layer }
                return area(lhs.frame) > area(rhs.frame)
            }
            .first
    }

    private func area(_ frame: WindowFrame) -> Double {
        frame.width * frame.height
    }
}

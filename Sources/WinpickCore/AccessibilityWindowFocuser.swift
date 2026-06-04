import AppKit
import ApplicationServices
import Foundation

public protocol WindowFocusing {
    func focus(_ window: WindowRecord, promptForPermission: Bool) throws
}

public struct AccessibilityWindowFocuser: WindowFocusing {
    public init() {}

    public func focus(_ window: WindowRecord, promptForPermission: Bool = true) throws {
        guard AccessibilityPermission.isTrusted(prompt: promptForPermission) else {
            throw WinpickError.accessibilityPermissionRequired(
                appName: AccessibilityPermission.likelyHostAppName()
            )
        }

        if focusWithYabai(window) {
            return
        }

        let appElement = AXUIElementCreateApplication(window.pid)
        NSRunningApplication(processIdentifier: window.pid)?
            .activate(options: [])

        let axWindow = try matchingWindow(for: window, in: appElement)

        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
        let focusResult = AXUIElementSetAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            axWindow
        )

        guard focusResult == .success else {
            throw WinpickError.focusFailed(app: window.app, title: window.title)
        }
    }

    private func focusWithYabai(_ window: WindowRecord) -> Bool {
        guard let space = window.space, window.id > 0 else {
            return false
        }

        _ = runYabai(arguments: ["-m", "space", "--focus", String(space)])
        return runYabai(arguments: ["-m", "window", "--focus", String(window.id)])
    }

    private func runYabai(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["yabai"] + arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return false
        }

        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private func matchingWindow(for target: WindowRecord, in appElement: AXUIElement) throws -> AXUIElement {
        let retryDelay: TimeInterval = 0.1
        let attempts = 12
        var didReadWindows = false

        for attempt in 0..<attempts {
            if let windows = AccessibilityElementAttributes.windows(of: appElement) {
                didReadWindows = true
                if let match = bestMatch(for: target, in: windows) {
                    return match
                }
            }

            if attempt < attempts - 1 {
                Thread.sleep(forTimeInterval: retryDelay)
            }
        }

        if didReadWindows {
            throw WinpickError.cannotMatchAccessibilityWindow(app: target.app, title: target.title)
        }

        throw WinpickError.cannotReadApplicationWindows(app: target.app)
    }

    private func bestMatch(for target: WindowRecord, in windows: [AXUIElement]) -> AXUIElement? {
        let candidates = windows.map { window in
            (window: window, score: score(window, against: target))
        }

        return candidates
            .filter { $0.score > 0 }
            .max { $0.score < $1.score }?
            .window
    }

    private func score(_ window: AXUIElement, against target: WindowRecord) -> Int {
        var score = 0

        let title = AccessibilityElementAttributes.string(window, kAXTitleAttribute)
        if !target.title.isEmpty, title == target.title {
            score += 100
        } else if target.title.isEmpty, title.isEmpty {
            score += 20
        }

        if let frame = AccessibilityElementAttributes.frame(of: window) {
            let distance = frame.distance(to: target.frame)
            if distance < 8 {
                score += 80
            } else if distance < 32 {
                score += 40
            }
        }

        return score
    }
}

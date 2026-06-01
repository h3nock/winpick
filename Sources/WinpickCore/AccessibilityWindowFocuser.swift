import AppKit
import ApplicationServices
import Foundation

public protocol WindowFocusing {
    func focus(_ window: WindowRecord, promptForPermission: Bool) throws
}

public struct AccessibilityWindowFocuser: WindowFocusing {
    public init() {}

    public func focus(_ window: WindowRecord, promptForPermission: Bool = true) throws {
        guard accessibilityTrusted(prompt: promptForPermission) else {
            throw WinpickError.accessibilityPermissionRequired
        }

        let appElement = AXUIElementCreateApplication(window.pid)
        var windowsValue: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsValue
        )

        guard copyResult == .success, let axWindows = windowsValue as? [AXUIElement] else {
            throw WinpickError.cannotReadApplicationWindows(app: window.app)
        }

        guard let axWindow = bestMatch(for: window, in: axWindows) else {
            throw WinpickError.cannotMatchAccessibilityWindow(app: window.app, title: window.title)
        }

        NSRunningApplication(processIdentifier: window.pid)?
            .activate(options: [])

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

    private func accessibilityTrusted(prompt: Bool) -> Bool {
        let key = "AXTrustedCheckOptionPrompt"
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
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

        let title = stringAttribute(window, kAXTitleAttribute)
        if !target.title.isEmpty, title == target.title {
            score += 100
        } else if target.title.isEmpty, title.isEmpty {
            score += 20
        }

        if let frame = frame(of: window) {
            let distance = abs(frame.x - target.frame.x)
                + abs(frame.y - target.frame.y)
                + abs(frame.width - target.frame.width)
                + abs(frame.height - target.frame.height)
            if distance < 8 {
                score += 80
            } else if distance < 32 {
                score += 40
            }
        }

        return score
    }

    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return ""
        }
        return value as? String ?? ""
    }

    private func frame(of element: AXUIElement) -> WindowFrame? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionAX = positionValue,
              let sizeAX = sizeValue
        else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionAX as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeAX as! AXValue, .cgSize, &size)

        return WindowFrame(
            x: point.x,
            y: point.y,
            width: size.width,
            height: size.height
        )
    }
}

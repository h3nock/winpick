import AppKit
import ApplicationServices
import Foundation

public struct AccessibilityPermissionReport: Codable, Equatable, Sendable {
    public let trusted: Bool
    public let appToEnable: String
    public let settingsPath: String
    public let settingsURL: String
}

public enum AccessibilityPermission {
    public static let settingsPath = "System Settings -> Privacy & Security -> Accessibility"
    public static let settingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    public static func isTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public static func likelyHostAppName() -> String {
        NSWorkspace.shared.frontmostApplication?.localizedName ?? "your terminal app"
    }

    public static func report(prompt: Bool) -> AccessibilityPermissionReport {
        AccessibilityPermissionReport(
            trusted: isTrusted(prompt: prompt),
            appToEnable: likelyHostAppName(),
            settingsPath: settingsPath,
            settingsURL: settingsURL
        )
    }

    public static func openSettings() {
        guard let url = URL(string: settingsURL) else { return }
        NSWorkspace.shared.open(url)
    }

    public static func instructions(appName: String = likelyHostAppName()) -> String {
        """
        Accessibility permission is required to focus windows.
        Enable \(appName) in \(settingsPath).
        You can run: winpick permissions --open-settings
        """
    }
}

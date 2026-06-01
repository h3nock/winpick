import AppKit
import ApplicationServices
import Darwin
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
        if let host = processHostAppName() {
            return host
        }

        return NSWorkspace.shared.frontmostApplication?.localizedName ?? "your terminal app"
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

    private static func processHostAppName() -> String? {
        var pid = getppid()
        var seen = Set<pid_t>()

        while pid > 1, !seen.contains(pid) {
            seen.insert(pid)

            if let app = NSRunningApplication(processIdentifier: pid),
               let name = app.localizedName,
               shouldReportHostApp(app)
            {
                return name
            }

            guard let parent = parentPID(of: pid) else {
                break
            }
            pid = parent
        }

        return nil
    }

    private static func shouldReportHostApp(_ app: NSRunningApplication) -> Bool {
        if app.bundleIdentifier == "com.apple.finder" {
            return false
        }

        switch app.activationPolicy {
        case .regular, .accessory:
            return app.bundleIdentifier != nil
        case .prohibited:
            return false
        @unknown default:
            return app.bundleIdentifier != nil
        }
    }

    private static func parentPID(of pid: pid_t) -> pid_t? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "ppid=", "-p", String(pid)]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            let parent = pid_t(text)
        else {
            return nil
        }

        return parent
    }
}

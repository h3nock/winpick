import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

public protocol WindowListing {
    func listWindows() throws -> [WindowRecord]
    func listAllWindows() throws -> [WindowRecord]
}

public struct SystemWindowLister: WindowListing {
    private struct YabaiWindowInfo {
        let space: Int?
        let title: String?
        let focusable: Bool?
    }

    private struct RawWindowSnapshot {
        let windows: [WindowRecord]
        let yabaiInfoByWindowID: [Int: YabaiWindowInfo]

        var hasYabaiFocusabilityData: Bool {
            yabaiInfoByWindowID.values.contains { $0.focusable != nil }
        }
    }

    public init() {}

    public static func optionalSpaceMetadataProviderName() -> String? {
        CommandLookup.exists("yabai") ? "yabai" : nil
    }

    public func listWindows() throws -> [WindowRecord] {
        guard AccessibilityPermission.isTrusted(prompt: false) else {
            throw WinpickError.accessibilityPermissionRequired(
                appName: AccessibilityPermission.likelyHostAppName()
            )
        }

        let snapshot = listRawWindowSnapshot()
        let rawWindows = snapshot.windows
        let hasSpaceData = rawWindows.contains { $0.space != nil }
        let candidateWindows = hasSpaceData
            ? rawWindows.filter { $0.space != nil }
            : rawWindows

        if snapshot.hasYabaiFocusabilityData {
            return Self.sort(candidateWindows.filter { window in
                snapshot.yabaiInfoByWindowID[window.id]?.focusable == true
            })
        }

        let candidatePIDs = Set(candidateWindows.map(\.pid))
        var focusablePIDs = Set<pid_t>()

        for application in NSWorkspace.shared.runningApplications {
            guard candidatePIDs.contains(application.processIdentifier) else { continue }
            guard Self.shouldInspect(application) else { continue }
            if Self.hasFocusableAccessibilityWindow(application) {
                focusablePIDs.insert(application.processIdentifier)
            }
        }

        return Self.sort(candidateWindows.filter { focusablePIDs.contains($0.pid) })
    }

    public func listAllWindows() throws -> [WindowRecord] {
        Self.sort(listRawWindowSnapshot().windows)
    }

    private func listRawWindowSnapshot() -> RawWindowSnapshot {
        let yabaiInfoByWindowID = Self.yabaiWindowInfoByWindowID()
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []

        let windows = rawWindows.compactMap { window in
            Self.makeRecord(window, yabaiInfoByWindowID: yabaiInfoByWindowID)
        }
        return RawWindowSnapshot(
            windows: windows,
            yabaiInfoByWindowID: yabaiInfoByWindowID
        )
    }

    private static func makeRecord(
        _ window: [String: Any],
        yabaiInfoByWindowID: [Int: YabaiWindowInfo]
    ) -> WindowRecord? {
        guard let id = intValue(window[kCGWindowNumber as String]) else { return nil }
        let yabaiInfo = yabaiInfoByWindowID[id]

        let app = stringValue(window[kCGWindowOwnerName as String])
        if app.isEmpty || app == "Window Server" { return nil }

        let title = preferredTitle(
            coreGraphicsTitle: stringValue(window[kCGWindowName as String]),
            yabaiTitle: yabaiInfo?.title
        )
        let pid = Int32(intValue(window[kCGWindowOwnerPID as String]) ?? 0)
        let layer = intValue(window[kCGWindowLayer as String]) ?? 0
        guard layer == 0 else { return nil }

        let alpha = doubleValue(window[kCGWindowAlpha as String]) ?? 1
        guard alpha > 0 else { return nil }

        guard let bounds = window[kCGWindowBounds as String] as? [String: Any] else {
            return nil
        }

        let width = doubleValue(bounds["Width"]) ?? 0
        let height = doubleValue(bounds["Height"]) ?? 0
        guard width >= 160, height >= 120 else { return nil }

        return WindowRecord(
            id: id,
            app: app,
            title: title,
            pid: pid,
            layer: layer,
            visible: true,
            frame: WindowFrame(
                x: doubleValue(bounds["X"]) ?? 0,
                y: doubleValue(bounds["Y"]) ?? 0,
                width: width,
                height: height
            ),
            space: yabaiInfo?.space
        )
    }

    private static func shouldInspect(_ application: NSRunningApplication) -> Bool {
        switch application.activationPolicy {
        case .regular, .accessory:
            return application.localizedName != nil
        case .prohibited:
            return false
        @unknown default:
            return application.localizedName != nil
        }
    }

    private static func hasFocusableAccessibilityWindow(_ application: NSRunningApplication) -> Bool {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        _ = AXUIElementSetMessagingTimeout(appElement, 0.12)

        if let axWindows = AccessibilityElementAttributes.windows(of: appElement) {
            if axWindows.contains(where: Self.isFocusableAccessibilityWindow) {
                return true
            }
        }

        if let focusedWindow = AccessibilityElementAttributes.element(
            appElement,
            kAXFocusedWindowAttribute
        ) {
            return Self.isFocusableAccessibilityWindow(focusedWindow)
        }

        return false
    }

    private static func isFocusableAccessibilityWindow(_ axWindow: AXUIElement) -> Bool {
        guard AccessibilityElementAttributes.string(axWindow, kAXRoleAttribute) == kAXWindowRole,
              let frame = AccessibilityElementAttributes.frame(of: axWindow),
              frame.width >= 160,
              frame.height >= 120
        else {
            return false
        }

        return true
    }

    private static func preferredTitle(coreGraphicsTitle: String, yabaiTitle: String?) -> String {
        if !coreGraphicsTitle.isEmpty {
            return coreGraphicsTitle
        }

        return yabaiTitle ?? ""
    }

    private static func yabaiWindowInfoByWindowID() -> [Int: YabaiWindowInfo] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["yabai", "-m", "query", "--windows"]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return [:]
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return [:]
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return [:]
        }

        var windows: [Int: YabaiWindowInfo] = [:]
        for row in rows {
            guard let id = intValue(row["id"]) else {
                continue
            }
            windows[id] = YabaiWindowInfo(
                space: intValue(row["space"]),
                title: stringValue(row["title"]),
                focusable: yabaiFocusableValue(row)
            )
        }
        return windows
    }

    static func yabaiFocusableValue(_ row: [String: Any]) -> Bool? {
        let hasFocusabilityFields = row["role"] != nil
            || row["has-ax-reference"] != nil
            || row["is-minimized"] != nil
            || row["is-hidden"] != nil
        guard hasFocusabilityFields else {
            return nil
        }

        let role = stringValue(row["role"])
        if !role.isEmpty && role != kAXWindowRole {
            return false
        }

        if boolValue(row["has-ax-reference"]) == false {
            return false
        }

        if boolValue(row["is-minimized"]) == true || boolValue(row["is-hidden"]) == true {
            return false
        }

        return true
    }

    static func sort(_ windows: [WindowRecord]) -> [WindowRecord] {
        windows.sorted { lhs, rhs in
            let lhsSpace = lhs.space ?? Int.max
            let rhsSpace = rhs.space ?? Int.max
            if lhsSpace != rhsSpace { return lhsSpace < rhsSpace }
            if lhs.layer != rhs.layer { return lhs.layer < rhs.layer }
            if lhs.app != rhs.app { return lhs.app < rhs.app }
            if lhs.title != rhs.title { return lhs.title < rhs.title }
            return lhs.id < rhs.id
        }
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let int = value as? Int { return int }
        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        return nil
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String {
        value as? String ?? ""
    }
}

import CoreGraphics
import Foundation

public protocol WindowListing {
    func listWindows() throws -> [WindowRecord]
}

public struct SystemWindowLister: WindowListing {
    public init() {}

    public func listWindows() throws -> [WindowRecord] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []

        return rawWindows.compactMap(Self.makeRecord)
            .sorted { lhs, rhs in
                if lhs.layer != rhs.layer { return lhs.layer < rhs.layer }
                if lhs.app != rhs.app { return lhs.app < rhs.app }
                if lhs.title != rhs.title { return lhs.title < rhs.title }
                return lhs.id < rhs.id
            }
    }

    private static func makeRecord(_ window: [String: Any]) -> WindowRecord? {
        guard let id = intValue(window[kCGWindowNumber as String]) else { return nil }

        let app = stringValue(window[kCGWindowOwnerName as String])
        if app.isEmpty || app == "Window Server" { return nil }

        let title = stringValue(window[kCGWindowName as String])
        let pid = Int32(intValue(window[kCGWindowOwnerPID as String]) ?? 0)
        let layer = intValue(window[kCGWindowLayer as String]) ?? 0
        let alpha = doubleValue(window[kCGWindowAlpha as String]) ?? 1
        guard alpha > 0 else { return nil }

        guard let bounds = window[kCGWindowBounds as String] as? [String: Any] else {
            return nil
        }

        let width = doubleValue(bounds["Width"]) ?? 0
        let height = doubleValue(bounds["Height"]) ?? 0
        guard width >= 20, height >= 20 else { return nil }

        if layer != 0 && title.isEmpty {
            return nil
        }

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
            )
        )
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

    private static func stringValue(_ value: Any?) -> String {
        value as? String ?? ""
    }
}

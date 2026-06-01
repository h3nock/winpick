import Foundation

public struct WindowFrame: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    func distance(to other: WindowFrame) -> Double {
        abs(x - other.x)
            + abs(y - other.y)
            + abs(width - other.width)
            + abs(height - other.height)
    }
}

public struct WindowRecord: Codable, Equatable, Sendable {
    public let id: Int
    public let app: String
    public let title: String
    public let pid: Int32
    public let layer: Int
    public let visible: Bool
    public let frame: WindowFrame

    public init(
        id: Int,
        app: String,
        title: String,
        pid: Int32,
        layer: Int,
        visible: Bool,
        frame: WindowFrame
    ) {
        self.id = id
        self.app = app
        self.title = title
        self.pid = pid
        self.layer = layer
        self.visible = visible
        self.frame = frame
    }

    public var displayTitle: String {
        title.isEmpty ? app : "\(app) - \(title)"
    }

    public var pickerLine: String {
        let label = title.isEmpty ? app : "\(app) - \(title)"
        let frameText = "\(Int(frame.width))x\(Int(frame.height))+\(Int(frame.x))+\(Int(frame.y))"
        return "\(id)\t\(label)  [id:\(id)] [\(frameText)]"
    }
}

public struct FocusResult: Codable, Equatable, Sendable {
    public let ok: Bool
    public let window: WindowRecord
}

public enum WinpickError: Error, CustomStringConvertible, Equatable {
    case missingWindow(Int)
    case accessibilityPermissionRequired(appName: String)
    case cannotReadApplicationWindows(app: String)
    case cannotMatchAccessibilityWindow(app: String, title: String)
    case focusFailed(app: String, title: String)
    case pickerRequiresTerminal
    case fzfUnavailable
    case pickerCancelled
    case invalidArguments(String)
    case noWindows

    public var description: String {
        switch self {
        case .missingWindow(let id):
            "No window found with id \(id). Run `winpick list` again because window ids can change."
        case .accessibilityPermissionRequired(let appName):
            AccessibilityPermission.instructions(appName: appName)
        case .cannotReadApplicationWindows(let app):
            "Could not read accessibility windows for \(app)."
        case .cannotMatchAccessibilityWindow(let app, let title):
            "Could not match accessibility window for \(app) - \(title)."
        case .focusFailed(let app, let title):
            "Could not focus \(app) - \(title)."
        case .pickerRequiresTerminal:
            "Window picker requires an interactive terminal."
        case .fzfUnavailable:
            "fzf is required for interactive picking but was not found on PATH."
        case .pickerCancelled:
            "Window picker cancelled."
        case .invalidArguments(let message):
            message
        case .noWindows:
            "No windows found."
        }
    }
}

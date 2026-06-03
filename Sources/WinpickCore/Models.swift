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

    var pickerText: String {
        "\(Int(width))x\(Int(height))+\(Int(x))+\(Int(y))"
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
    public let space: Int?

    public init(
        id: Int,
        app: String,
        title: String,
        pid: Int32,
        layer: Int,
        visible: Bool,
        frame: WindowFrame,
        space: Int? = nil
    ) {
        self.id = id
        self.app = app
        self.title = title
        self.pid = pid
        self.layer = layer
        self.visible = visible
        self.frame = frame
        self.space = space
    }

    public var displayTitle: String {
        title.isEmpty ? app : "\(app) - \(title)"
    }

    public var pickerLine: String {
        if title.isEmpty {
            return "\(spaceLabel)\t\(app)"
        }
        return "\(spaceLabel)\t\(app)\t\(title)"
    }

    public var spaceLabel: String {
        guard let space else {
            return "-"
        }
        return "S\(space)"
    }
}

public struct FocusResult: Codable, Equatable, Sendable {
    public let ok: Bool
    public let window: WindowRecord
}

public enum DependencyInstructions {
    public static let fzfInstallHint = """
    Install fzf with Homebrew:
      brew install fzf

    Or install fzf another way and make sure `fzf` is on PATH.
    """
}

public enum WinpickError: Error, CustomStringConvertible, Equatable {
    case missingWindow(Int)
    case notFocusableWindow(id: Int, app: String, title: String)
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
            return "No focusable window found with id \(id). Run `winpick list` again because window ids can change."
        case .notFocusableWindow(let id, let app, let title):
            let label = title.isEmpty ? app : "\(app) - \(title)"
            return "Window \(id) (\(label)) exists in raw macOS window records but is not exposed as a focusable Accessibility window."
        case .accessibilityPermissionRequired(let appName):
            return AccessibilityPermission.instructions(appName: appName)
        case .cannotReadApplicationWindows(let app):
            return "Could not read accessibility windows for \(app)."
        case .cannotMatchAccessibilityWindow(let app, let title):
            return "Could not match accessibility window for \(app) - \(title)."
        case .focusFailed(let app, let title):
            return "Could not focus \(app) - \(title)."
        case .pickerRequiresTerminal:
            return "Window picker requires an interactive terminal."
        case .fzfUnavailable:
            return """
            fzf is required for interactive picking but was not found on PATH.
            \(DependencyInstructions.fzfInstallHint)
            """
        case .pickerCancelled:
            return "Window picker cancelled."
        case .invalidArguments(let message):
            return message
        case .noWindows:
            return "No windows found."
        }
    }
}

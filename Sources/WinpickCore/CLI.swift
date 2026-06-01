import Foundation

public struct CLI {
    private let lister: WindowListing
    private let focuser: WindowFocusing
    private let picker: FzfWindowPicker
    private let frontmostResolver: FrontmostWindowResolver

    public init(lister: WindowListing, focuser: WindowFocusing, picker: FzfWindowPicker) {
        self.lister = lister
        self.focuser = focuser
        self.picker = picker
        self.frontmostResolver = FrontmostWindowResolver()
    }

    public func run(_ arguments: [String]) -> Int32 {
        let wantsJSON = arguments.contains("--json")

        do {
            try runThrowing(arguments)
            return 0
        } catch WinpickError.pickerCancelled {
            if wantsJSON {
                writeErrorJSON("Window picker cancelled.", code: "cancelled")
            }
            return 130
        } catch let error as WinpickError {
            if wantsJSON {
                writeErrorJSON(error.description, code: "error")
            } else {
                FileHandle.standardError.write(Data("winpick: \(error.description)\n".utf8))
            }
            return 1
        } catch {
            if wantsJSON {
                writeErrorJSON(error.localizedDescription, code: "error")
            } else {
                FileHandle.standardError.write(Data("winpick: \(error.localizedDescription)\n".utf8))
            }
            return 1
        }
    }

    private func runThrowing(_ arguments: [String]) throws {
        var args = arguments
        let command = args.first ?? "pick"
        if !args.isEmpty {
            args.removeFirst()
        }

        switch command {
        case "pick":
            try pick(args)
        case "list":
            try list(args)
        case "focus":
            try focus(args)
        case "current":
            try current(args)
        case "help", "-h", "--help":
            print(Self.help)
        case "version", "--version":
            print("winpick 0.1.0")
        default:
            throw WinpickError.invalidArguments("Unknown command: \(command)")
        }
    }

    private func list(_ args: [String]) throws {
        let json = args.contains("--json")
        let windows = try lister.listWindows()

        if json {
            try writeJSON(windows)
            return
        }

        for window in windows {
            print("\(window.id)\t\(window.app)\t\(window.title)")
        }
    }

    private func current(_ args: [String]) throws {
        let json = args.contains("--json")
        let windows = try lister.listWindows()
        guard let window = frontmostResolver.currentWindow(in: windows) else {
            throw WinpickError.noWindows
        }

        if json {
            try writeJSON(window)
        } else {
            print("\(window.id)\t\(window.displayTitle)")
        }
    }

    private func focus(_ args: [String]) throws {
        guard let idText = args.first, let id = Int(idText) else {
            throw WinpickError.invalidArguments("Usage: winpick focus <window-id>")
        }

        let windows = try lister.listWindows()
        guard let window = windows.first(where: { $0.id == id }) else {
            throw WinpickError.missingWindow(id)
        }

        try focuser.focus(window, promptForPermission: true)
        if args.contains("--json") {
            try writeJSON(FocusResult(ok: true, window: window))
        } else {
            print("Focused: \(window.displayTitle)")
        }
    }

    private func pick(_ args: [String]) throws {
        let json = args.contains("--json")
        let windows = try lister.listWindows()
        try picker.execFocusPicker(
            from: windows,
            json: json,
            binaryPath: Bundle.main.executablePath ?? "winpick"
        )
    }

    private func writeJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private func writeErrorJSON(_ message: String, code: String) {
        do {
            try writeJSON(ErrorResponse(ok: false, code: code, error: message))
        } catch {
            FileHandle.standardError.write(Data("winpick: \(message)\n".utf8))
        }
    }

    private struct ErrorResponse: Encodable {
        let ok: Bool
        let code: String
        let error: String
    }

    public static let help = """
    winpick - macOS window picker and focuser

    Usage:
      winpick                 Pick a window with fzf and focus it
      winpick pick [--json]   Pick a window with fzf and focus it
      winpick list [--json]   List visible windows
      winpick focus <id>      Focus a visible window by id
      winpick current [--json]
      winpick help
      winpick version

    Notes:
      - Listing uses native macOS window metadata.
      - Focusing requires Accessibility permission for your terminal.
      - No screenshots are captured by this tool.
    """
}

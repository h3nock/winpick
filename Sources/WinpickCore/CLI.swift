import Foundation

public struct CLI {
    private let lister: WindowListing
    private let focuser: WindowFocusing
    private let picker: FzfWindowPicker
    private let frontmostResolver: FrontmostWindowResolver
    private let history: WindowHistoryStore

    public init(
        lister: WindowListing,
        focuser: WindowFocusing,
        picker: FzfWindowPicker,
        history: WindowHistoryStore = WindowHistoryStore()
    ) {
        self.lister = lister
        self.focuser = focuser
        self.picker = picker
        self.frontmostResolver = FrontmostWindowResolver()
        self.history = history
    }

    public func run(_ arguments: [String]) -> Int32 {
        let wantsJSON = Self.hasJSONFlag(arguments)

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
        let command = Self.canonicalCommand(args.first ?? "pick")
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
        case "focus-record":
            try focusRecord(args)
        case "current":
            try current(args)
        case "doctor":
            try doctor(args)
        case "permissions":
            try permissions(args)
        case "help", "-h", "--help":
            print(Self.help)
        case "version", "--version":
            print("winpick 0.1.0")
        default:
            throw WinpickError.invalidArguments("Unknown command: \(command)")
        }
    }

    private func list(_ args: [String]) throws {
        let json = Self.hasJSONFlag(args)
        let windows: [WindowRecord]
        if Self.hasAllFlag(args) {
            windows = try lister.listAllWindows()
        } else {
            windows = try lister.listWindows()
        }

        if json {
            try writeJSON(windows)
            return
        }

        for window in windows {
            print("\(window.spaceLabel)\t\(window.id)\t\(window.app)\t\(window.title)")
        }
    }

    private func current(_ args: [String]) throws {
        let json = Self.hasJSONFlag(args)
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
            if let rawWindow = try lister.listAllWindows().first(where: { $0.id == id }) {
                throw WinpickError.notFocusableWindow(
                    id: id,
                    app: rawWindow.app,
                    title: rawWindow.title
                )
            }
            throw WinpickError.missingWindow(id)
        }

        try focuser.focus(window, promptForPermission: true)
        recordFocusInHistory(window)
        if Self.hasJSONFlag(args) {
            try writeJSON(FocusResult(ok: true, window: window))
        } else {
            print("Focused: \(window.displayTitle)")
        }
    }

    private func focusRecord(_ args: [String]) throws {
        guard let payload = args.first,
              let data = Data(base64Encoded: payload)
        else {
            throw WinpickError.invalidArguments("Usage: winpick focus-record <encoded-window-record>")
        }

        let window = try JSONDecoder().decode(WindowRecord.self, from: data)
        try focuser.focus(window, promptForPermission: true)
        recordFocusInHistory(window)
        if Self.hasJSONFlag(args) {
            try writeJSON(FocusResult(ok: true, window: window))
        } else {
            print("Focused: \(window.displayTitle)")
        }
    }

    private func pick(_ args: [String]) throws {
        let json = Self.hasJSONFlag(args)
        let windows = try lister.listWindows()
        let pickerOrder = pickerOrder(for: windows)
        try picker.execFocusPicker(
            from: pickerOrder.windows,
            recentWindowIDs: pickerOrder.recentWindowIDs,
            json: json,
            binaryPath: Bundle.main.executablePath ?? "winpick"
        )
    }

    private func pickerOrder(for windows: [WindowRecord]) -> WindowPickerOrder {
        do {
            return try history.pickerOrder(for: windows)
        } catch {
            warn("could not read recent-window history: \(error.localizedDescription)")
            return WindowPickerOrder(windows: windows, recentWindowIDs: [])
        }
    }

    private func recordFocusInHistory(_ window: WindowRecord) {
        do {
            try history.recordFocus(window)
        } catch {
            warn("could not update recent-window history: \(error.localizedDescription)")
        }
    }

    private func permissions(_ args: [String]) throws {
        let json = Self.hasJSONFlag(args)
        let shouldOpenSettings = Self.hasOpenSettingsFlag(args)
        let shouldPrompt = args.contains("--prompt") || shouldOpenSettings

        let report = AccessibilityPermission.report(prompt: shouldPrompt)
        if shouldOpenSettings && !report.trusted {
            AccessibilityPermission.openSettings()
        }

        if json {
            try writeJSON(report)
            return
        }

        if report.trusted {
            print("Accessibility: granted")
            print("winpick can focus and raise windows.")
            return
        }

        print("Accessibility: missing")
        print("Enable: \(report.appToEnable)")
        print("Location: \(report.settingsPath)")
        print("")
        print("Command to open settings:")
        print("  winpick permissions --open-settings")
        print("")
        print("After enabling it, rerun:")
        print("  winpick doctor")
    }

    private func doctor(_ args: [String]) throws {
        let json = Self.hasJSONFlag(args)
        let permission = AccessibilityPermission.report(prompt: false)
        let windows = permission.trusted ? try lister.listWindows() : []
        let allWindows = try lister.listAllWindows()
        let report = DoctorReport(
            accessibility: permission,
            fzfFound: FzfWindowPicker.commandExists("fzf"),
            spaceMetadataProvider: SystemWindowLister.optionalSpaceMetadataProviderName(),
            windowCount: windows.count,
            rawWindowCount: allWindows.count
        )

        if json {
            try writeJSON(report)
            return
        }

        print("winpick doctor")
        print("Accessibility: \(permission.trusted ? "granted" : "missing")")
        if !permission.trusted {
            print("  Enable: \(permission.appToEnable)")
            print("  Location: \(permission.settingsPath)")
            print("  Open: winpick permissions --open-settings")
        }
        print("fzf: \(report.fzfFound ? "found" : "missing")")
        if !report.fzfFound {
            print("  Install: brew install fzf")
            print("  Then make sure `fzf` is on PATH.")
        }
        if let provider = report.spaceMetadataProvider {
            print("Space metadata: \(provider) (optional)")
        } else {
            print("Space metadata: unavailable (Space labels use -)")
        }
        print("Focus candidates: \(report.windowCount)")
        print("Raw windows: \(report.rawWindowCount)")
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

    private func warn(_ message: String) {
        FileHandle.standardError.write(Data("winpick: warning: \(message)\n".utf8))
    }

    private struct ErrorResponse: Encodable {
        let ok: Bool
        let code: String
        let error: String
    }

    private struct DoctorReport: Encodable {
        let accessibility: AccessibilityPermissionReport
        let fzfFound: Bool
        let spaceMetadataProvider: String?
        let windowCount: Int
        let rawWindowCount: Int
    }

    static func canonicalCommand(_ command: String) -> String {
        switch command {
        case "p", "pick":
            return "pick"
        case "l", "ls", "list":
            return "list"
        case "f", "focus":
            return "focus"
        case "focus-record":
            return "focus-record"
        case "c", "cur", "current":
            return "current"
        case "d", "doc", "doctor":
            return "doctor"
        case "perm", "perms", "permission", "permissions":
            return "permissions"
        case "h", "help", "-h", "--help":
            return "help"
        case "ver", "version", "--version":
            return "version"
        default:
            return command
        }
    }

    static func hasJSONFlag(_ args: [String]) -> Bool {
        args.contains("--json") || args.contains("-j")
    }

    static func hasAllFlag(_ args: [String]) -> Bool {
        args.contains("--all") || args.contains("-a")
    }

    static func hasOpenSettingsFlag(_ args: [String]) -> Bool {
        args.contains("--open-settings") || args.contains("-o")
    }

    public static let help = """
    winpick - macOS window picker and focuser

    Usage:
      winpick                 Pick a window with fzf and focus it
      winpick p [-j]          Pick a window with fzf and focus it
      winpick l [-j]          List focus candidates
      winpick l -a            List raw macOS window records
      winpick f <id> [-j]     Focus a window by id
      winpick c [-j]          Print the current focused window
      winpick perms [-j] [--prompt] [-o]
      winpick d [-j]          Check setup
      winpick help
      winpick version

    Aliases:
      p=pick, l/ls=list, f=focus, c/cur=current, d/doc=doctor, perm/perms=permissions
      -j=--json, -a=--all, -o=--open-settings

    Notes:
      - The interactive picker shows recent winpick-focused windows first, then the Space-sorted list.
      - Default listing shows window records from apps that expose focusable Accessibility windows.
      - Space labels use yabai when available.
      - Recent history is local state and does not require a daemon.
      - `list --all` shows raw CoreGraphics records, including non-focusable surfaces.
      - Focusing requires Accessibility permission for the terminal app running winpick.
      - Run `winpick permissions --open-settings` for guided setup.
      - No screenshots are captured by this tool.
    """
}

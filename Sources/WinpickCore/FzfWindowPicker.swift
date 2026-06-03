import Darwin
import Foundation

public struct FzfWindowPicker {
    private let encoder = JSONEncoder()

    public init() {}

    public func execFocusPicker(
        from windows: [WindowRecord],
        recentWindowIDs: Set<Int> = [],
        json: Bool,
        binaryPath: String
    ) throws -> Never {
        guard isatty(STDOUT_FILENO) == 1 else {
            throw WinpickError.pickerRequiresTerminal
        }

        guard !windows.isEmpty else {
            throw WinpickError.noWindows
        }

        guard Self.commandExists("fzf") else {
            throw WinpickError.fzfUnavailable
        }

        let inputURL = try writeRowsToTemporaryFile(
            windows,
            recentWindowIDs: recentWindowIDs
        )
        let script = """
        trap 'rm -f "$WINPICK_PICKER_FILE"' EXIT
        selected="$(\(Self.shellFzfCommand) < "$WINPICK_PICKER_FILE")" || exit 130
        payload="${selected%%$'\\t'*}"
        rm -f "$WINPICK_PICKER_FILE"
        trap - EXIT
        if [[ "$WINPICK_JSON" == "1" ]]; then
          exec "$WINPICK_BIN" focus-record "$payload" --json
        else
          exec "$WINPICK_BIN" focus-record "$payload"
        fi
        """

        var environment = ProcessInfo.processInfo.environment
        environment["WINPICK_PICKER_FILE"] = inputURL.path
        environment["WINPICK_BIN"] = binaryPath
        environment["WINPICK_JSON"] = json ? "1" : "0"

        let argvStrings: [String] = ["zsh", "-fc", script]
        var argv: [UnsafeMutablePointer<CChar>?] = argvStrings.map { strdup($0) }
        argv.append(nil)
        var envp: [UnsafeMutablePointer<CChar>?] = environment.map { key, value in
            strdup("\(key)=\(value)")
        }
        envp.append(nil)

        _ = argv.withUnsafeMutableBufferPointer { argvBuffer in
            envp.withUnsafeMutableBufferPointer { envBuffer in
                execve("/bin/zsh", argvBuffer.baseAddress, envBuffer.baseAddress)
            }
        }
        throw WinpickError.invalidArguments("Could not start fzf picker.")
    }

    private func writeRowsToTemporaryFile(
        _ windows: [WindowRecord],
        recentWindowIDs: Set<Int>
    ) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("winpick-\(UUID().uuidString).tsv")
        try Data(
            try pickerRows(from: windows, recentWindowIDs: recentWindowIDs).utf8
        ).write(to: url, options: [.atomic])
        return url
    }

    private func pickerRows(
        from windows: [WindowRecord],
        recentWindowIDs: Set<Int> = []
    ) throws -> String {
        let appWidth = Self.appColumnWidth(for: windows)
        return try windows.map { window in
            try pickerLine(
                for: window,
                appWidth: appWidth,
                isRecent: recentWindowIDs.contains(window.id)
            )
        }.joined(separator: "\n") + "\n"
    }

    func pickerLine(
        for window: WindowRecord,
        appWidth: Int,
        isRecent: Bool = false
    ) throws -> String {
        let payload = try encoder.encode(window).base64EncodedString()
        return [
            payload,
            Self.displayLine(for: window, appWidth: appWidth, isRecent: isRecent),
            window.spaceLabel,
            Self.sanitized(window.app),
            Self.sanitized(window.title),
            String(window.id),
            window.frame.pickerText,
        ].joined(separator: "\t")
    }

    static let shellFzfCommand = """
    fzf --delimiter=$'\\t' --with-nth=2 --nth='1..' --prompt='winpick> ' --header='R  Space  App  Window' --layout=reverse --bind='ctrl-j:down,ctrl-k:up'
    """

    static func displayLine(
        for window: WindowRecord,
        appWidth: Int,
        isRecent: Bool = false
    ) -> String {
        let recencyMarker = isRecent ? "R" : " "
        let app = paddedAppName(Self.sanitized(window.app), width: appWidth)
        let title = Self.sanitized(window.title)
        if title.isEmpty {
            return "\(recencyMarker)  \(window.spaceLabel)  \(app)"
        }
        return "\(recencyMarker)  \(window.spaceLabel)  \(app)  \(title)"
    }

    static func appColumnWidth(for windows: [WindowRecord]) -> Int {
        let longestApp = windows
            .map { sanitized($0.app).count }
            .max() ?? 3
        return min(max(longestApp, 3), 24)
    }

    private static func paddedAppName(_ app: String, width: Int) -> String {
        let clipped = clippedText(app, width: width)
        if clipped.count >= width {
            return clipped
        }
        return clipped + String(repeating: " ", count: width - clipped.count)
    }

    private static func clippedText(_ text: String, width: Int) -> String {
        guard width > 3, text.count > width else {
            return text
        }
        return String(text.prefix(width - 3)) + "..."
    }

    private static func sanitized(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    public static func commandExists(_ name: String) -> Bool {
        commandPath(name) != nil
    }

    static func commandPath(_ name: String) -> String? {
        guard let path = ProcessInfo.processInfo.environment["PATH"] else {
            return nil
        }

        return path
            .split(separator: ":")
            .compactMap { directory -> String? in
                let candidate = "\(directory)/\(name)"
                return access(candidate, X_OK) == 0 ? candidate : nil
            }
            .first
    }
}

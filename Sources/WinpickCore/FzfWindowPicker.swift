import Darwin
import Foundation

public protocol WindowPicking {
    func pick(from windows: [WindowRecord]) throws -> WindowRecord
}

public struct FzfWindowPicker: WindowPicking {
    public init() {}

    public func execFocusPicker(from windows: [WindowRecord], json: Bool, binaryPath: String) throws -> Never {
        guard isatty(STDOUT_FILENO) == 1 else {
            throw WinpickError.pickerRequiresTerminal
        }

        guard !windows.isEmpty else {
            throw WinpickError.noWindows
        }

        guard Self.commandExists("fzf") else {
            throw WinpickError.fzfUnavailable
        }

        let inputURL = try writeRowsToTemporaryFile(windows)
        let script = """
        trap 'rm -f "$WINPICK_PICKER_FILE"' EXIT
        selected="$(fzf --delimiter=$'\\t' --with-nth=2.. --prompt='window> ' < "$WINPICK_PICKER_FILE")" || exit 130
        id="${selected%%$'\\t'*}"
        rm -f "$WINPICK_PICKER_FILE"
        trap - EXIT
        if [[ "$WINPICK_JSON" == "1" ]]; then
          exec "$WINPICK_BIN" focus "$id" --json
        else
          exec "$WINPICK_BIN" focus "$id"
        fi
        """

        var environment = ProcessInfo.processInfo.environment
        environment["WINPICK_PICKER_FILE"] = inputURL.path
        environment["WINPICK_BIN"] = binaryPath
        environment["WINPICK_JSON"] = json ? "1" : "0"

        let argvStrings: [String] = ["zsh", "-lc", script]
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

    public func pick(from windows: [WindowRecord]) throws -> WindowRecord {
        guard isatty(STDOUT_FILENO) == 1 else {
            throw WinpickError.pickerRequiresTerminal
        }

        guard !windows.isEmpty else {
            throw WinpickError.noWindows
        }

        guard Self.commandExists("fzf") else {
            throw WinpickError.fzfUnavailable
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "fzf",
            "--delimiter=\t",
            "--with-nth=2..",
            "--prompt=window> ",
        ]

        let inputURL = try writeRowsToTemporaryFile(windows)
        let output = Pipe()
        let inputHandle = try FileHandle(forReadingFrom: inputURL)
        defer {
            try? inputHandle.close()
            try? FileManager.default.removeItem(at: inputURL)
        }

        process.standardInput = inputHandle
        process.standardOutput = output

        do {
            try process.run()
        } catch {
            throw WinpickError.fzfUnavailable
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw WinpickError.pickerCancelled
        }

        let selectedData = output.fileHandleForReading.readDataToEndOfFile()
        guard let selected = String(data: selectedData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            let idText = selected.split(separator: "\t", maxSplits: 1).first,
            let id = Int(idText),
            let window = windows.first(where: { $0.id == id })
        else {
            throw WinpickError.pickerCancelled
        }

        return window
    }

    private func writeRowsToTemporaryFile(_ windows: [WindowRecord]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("winpick-\(UUID().uuidString).tsv")
        let rows = windows.map(\.pickerLine).joined(separator: "\n") + "\n"
        try Data(rows.utf8).write(to: url, options: [.atomic])
        return url
    }

    public static func commandExists(_ name: String) -> Bool {
        guard let path = ProcessInfo.processInfo.environment["PATH"] else {
            return false
        }

        return path
            .split(separator: ":")
            .contains { directory in
                let candidate = "\(directory)/\(name)"
                return access(candidate, X_OK) == 0
            }
    }
}

import Darwin
import Foundation

public protocol WindowPicking {
    func pick(from windows: [WindowRecord]) throws -> WindowRecord
}

public struct FzfWindowPicker: WindowPicking {
    public init() {}

    public func pick(from windows: [WindowRecord]) throws -> WindowRecord {
        guard isatty(STDOUT_FILENO) == 1 else {
            throw WinpickError.pickerRequiresTerminal
        }

        guard !windows.isEmpty else {
            throw WinpickError.noWindows
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "fzf",
            "--delimiter=\t",
            "--with-nth=2..",
            "--prompt=window> ",
        ]

        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.standardError

        do {
            try process.run()
        } catch {
            throw WinpickError.fzfUnavailable
        }

        let rows = windows.map(\.pickerLine).joined(separator: "\n") + "\n"
        input.fileHandleForWriting.write(Data(rows.utf8))
        input.fileHandleForWriting.closeFile()

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
}

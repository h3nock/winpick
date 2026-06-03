import Foundation

struct WindowPickerOrder {
    let windows: [WindowRecord]
    let recentWindowIDs: Set<Int>
}

public struct WindowHistoryStore {
    private static let historyVersion = 1
    private static let maxStoredEntries = 100

    private let fileURL: URL
    private let currentDate: () -> Date

    public init(
        fileURL: URL = WindowHistoryStore.defaultHistoryURL(),
        currentDate: @escaping () -> Date = Date.init
    ) {
        self.fileURL = fileURL
        self.currentDate = currentDate
    }

    public static func defaultHistoryURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        if let xdgStateHome = environment["XDG_STATE_HOME"], !xdgStateHome.isEmpty {
            return URL(fileURLWithPath: xdgStateHome, isDirectory: true)
                .appendingPathComponent("winpick", isDirectory: true)
                .appendingPathComponent("history.json")
        }

        return homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("winpick", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    func pickerOrder(
        for windows: [WindowRecord],
        recentLimit: Int = 5
    ) throws -> WindowPickerOrder {
        let recentWindows = try recentWindows(from: windows, limit: recentLimit)
        let recentIDs = Set(recentWindows.map(\.id))
        let remainingWindows = windows.filter { !recentIDs.contains($0.id) }

        return WindowPickerOrder(
            windows: recentWindows + remainingWindows,
            recentWindowIDs: recentIDs
        )
    }

    func recordFocus(_ window: WindowRecord) throws {
        var entries = try readEntries()
        let entry = WindowHistoryEntry(window: window, focusedAt: currentDate())

        entries.removeAll { existing in
            existing.matches(window) || existing.id == window.id
        }
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(Self.maxStoredEntries))

        try writeEntries(entries)
    }

    private func recentWindows(from windows: [WindowRecord], limit: Int) throws -> [WindowRecord] {
        guard limit > 0 else { return [] }

        let entries = try readEntries()
            .sorted { $0.focusedAt > $1.focusedAt }
        var usedIDs = Set<Int>()
        var recents: [WindowRecord] = []

        for entry in entries {
            guard recents.count < limit else { break }
            guard let window = matchingWindow(for: entry, in: windows, excluding: usedIDs) else {
                continue
            }

            recents.append(window)
            usedIDs.insert(window.id)
        }

        return recents
    }

    private func matchingWindow(
        for entry: WindowHistoryEntry,
        in windows: [WindowRecord],
        excluding usedIDs: Set<Int>
    ) -> WindowRecord? {
        if let exactIDMatch = windows.first(where: { $0.id == entry.id && !usedIDs.contains($0.id) }) {
            return exactIDMatch
        }

        return windows.first { window in
            !usedIDs.contains(window.id) && entry.matches(window)
        }
    }

    private func readEntries() throws -> [WindowHistoryEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let history = try JSONDecoder().decode(WindowHistoryFile.self, from: data)
        guard history.version == Self.historyVersion else {
            return []
        }

        return history.entries
    }

    private func writeEntries(_ entries: [WindowHistoryEntry]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let history = WindowHistoryFile(
            version: Self.historyVersion,
            entries: entries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(history)
        try data.write(to: fileURL, options: [.atomic])
    }
}

private struct WindowHistoryFile: Codable {
    let version: Int
    let entries: [WindowHistoryEntry]
}

private struct WindowHistoryEntry: Codable {
    let id: Int
    let app: String
    let title: String
    let pid: Int32
    let frame: WindowFrame
    let space: Int?
    let focusedAt: TimeInterval

    init(window: WindowRecord, focusedAt: Date) {
        self.id = window.id
        self.app = window.app
        self.title = window.title
        self.pid = window.pid
        self.frame = window.frame
        self.space = window.space
        self.focusedAt = focusedAt.timeIntervalSince1970
    }

    func matches(_ window: WindowRecord) -> Bool {
        guard app == window.app else {
            return false
        }

        if !title.isEmpty || !window.title.isEmpty {
            return title == window.title
        }

        if pid == window.pid {
            return frame.distance(to: window.frame) < 16
        }

        return false
    }
}

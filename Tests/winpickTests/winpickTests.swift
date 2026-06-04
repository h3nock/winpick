import Foundation
import Testing
@testable import WinpickCore

@Test func commandAliasesResolveToCanonicalCommands() {
    let aliases = [
        ("p", "pick"),
        ("l", "list"),
        ("ls", "list"),
        ("f", "focus"),
        ("c", "current"),
        ("cur", "current"),
        ("d", "doctor"),
        ("doc", "doctor"),
        ("perm", "permissions"),
        ("perms", "permissions"),
        ("h", "help"),
        ("ver", "version"),
    ]

    for (alias, command) in aliases {
        #expect(CLI.canonicalCommand(alias) == command)
    }
}

@Test func shortFlagsMatchLongFlags() {
    for flag in ["-j", "--json"] {
        #expect(CLI.hasJSONFlag([flag]))
    }
    for flag in ["-a", "--all"] {
        #expect(CLI.hasAllFlag([flag]))
    }
    for flag in ["-o", "--open-settings"] {
        #expect(CLI.hasOpenSettingsFlag([flag]))
    }
}

@Test func windowDisplayTitleUsesAppWhenTitleIsEmpty() {
    let window = testWindow(id: 1, title: "")

    #expect(window.displayTitle == "Ghostty")
}

@Test func windowDisplayTitleIncludesTitleWhenPresent() {
    let window = testWindow(id: 1, title: "kbolt")

    #expect(window.displayTitle == "Ghostty - kbolt")
}

@Test func pickerLineFormatsSpaceAppAndTitle() {
    let cases = [
        (
            testWindow(id: 42, app: "Brave Browser", title: "ChatGPT", space: 3),
            "S3\tBrave Browser\tChatGPT"
        ),
        (
            testWindow(id: 42, app: "Brave Browser", title: ""),
            "-\tBrave Browser"
        ),
    ]

    for (window, expected) in cases {
        #expect(window.pickerLine == expected)
    }
}

@Test func fzfDisplayLineShowsVisibleFieldsAndRecentMarker() {
    let window = testWindow(
        id: 42,
        title: "ta kbolt",
        space: 2,
        frame: WindowFrame(x: 12, y: 34, width: 900, height: 700)
    )

    let line = FzfWindowPicker.displayLine(for: window, appWidth: 7)

    #expect(line == "   S2  Ghostty  ta kbolt")
    #expect(!line.contains("42"))
    #expect(!line.contains("900x700"))

    let recentLine = FzfWindowPicker.displayLine(
        for: window,
        appWidth: 7,
        isRecent: true
    )

    #expect(recentLine == "R  S2  Ghostty  ta kbolt")
}

@Test func fzfArgumentsHideMetadataAndPreview() {
    #expect(FzfWindowPicker.shellFzfCommand.contains("--with-nth=2"))
    #expect(FzfWindowPicker.shellFzfCommand.contains("--nth='1..'"))
    #expect(FzfWindowPicker.shellFzfCommand.contains("ctrl-j:down,ctrl-k:up"))
    #expect(!FzfWindowPicker.shellFzfCommand.contains("--preview"))
}

@Test func windowSortingGroupsBySpaceWithUnknownSpaceLast() {
    let windows = [
        testWindow(
            id: 30,
            title: "unknown"
        ),
        testWindow(
            id: 20,
            title: "space two",
            space: 2
        ),
        testWindow(
            id: 10,
            title: "space one",
            space: 1
        ),
        testWindow(
            id: 11,
            app: "Brave Browser",
            title: "space one",
            space: 1
        ),
    ]

    let sorted = SystemWindowLister.sort(windows)

    #expect(sorted.map(\.id) == [11, 10, 20, 30])
}

@Test func historyStorePlacesRecentWindowsBeforeRemainingSpaceOrder() throws {
    var now: TimeInterval = 100
    let store = WindowHistoryStore(
        fileURL: temporaryHistoryURL(),
        currentDate: { Date(timeIntervalSince1970: now) }
    )
    let windows = [
        testWindow(id: 20, title: "space one", space: 1),
        testWindow(id: 30, title: "space two", space: 2),
        testWindow(id: 10, title: "most recent", space: 1),
    ]

    try store.recordFocus(windows[0])
    now = 200
    try store.recordFocus(windows[2])

    let order = try store.pickerOrder(for: windows, recentLimit: 2)

    #expect(order.windows.map(\.id) == [10, 20, 30])
    #expect(order.recentWindowIDs == Set([10, 20]))
}

@Test func historyStoreMatchesStaleIDsByWindowIdentity() throws {
    let historyURL = temporaryHistoryURL()
    let store = WindowHistoryStore(
        fileURL: historyURL,
        currentDate: { Date(timeIntervalSince1970: 100) }
    )
    let previousWindow = testWindow(id: 10, title: "ta kbolt", space: 1)
    let currentWindow = testWindow(id: 99, title: "ta kbolt", space: 2)

    try store.recordFocus(previousWindow)
    let order = try WindowHistoryStore(fileURL: historyURL)
        .pickerOrder(for: [currentWindow], recentLimit: 5)

    #expect(order.windows.map(\.id) == [99])
    #expect(order.recentWindowIDs == Set([99]))
}

@Test func historyStoreDefaultURLUsesXDGStateHomeWhenAvailable() {
    let url = WindowHistoryStore.defaultHistoryURL(
        environment: ["XDG_STATE_HOME": "/tmp/state"],
        homeDirectory: URL(fileURLWithPath: "/Users/example", isDirectory: true)
    )

    #expect(url.path == "/tmp/state/winpick/history.json")
}

@Test func historyStoreDefaultURLUsesApplicationSupportByDefault() {
    let url = WindowHistoryStore.defaultHistoryURL(
        environment: [:],
        homeDirectory: URL(fileURLWithPath: "/Users/example", isDirectory: true)
    )

    #expect(url.path == "/Users/example/Library/Application Support/winpick/history.json")
}

@Test func yabaiFocusableValueParsesWindowMetadata() {
    let cases: [(row: [String: Any], expected: Bool?)] = [
        (
            [
                "role": "AXWindow",
                "has-ax-reference": true,
                "is-minimized": false,
                "is-hidden": false,
            ],
            true
        ),
        (
            [
                "role": "AXMenu",
                "has-ax-reference": true,
            ],
            false
        ),
        (
            [
                "role": "AXWindow",
                "has-ax-reference": false,
            ],
            false
        ),
        ([:], nil),
    ]

    for testCase in cases {
        #expect(SystemWindowLister.yabaiFocusableValue(testCase.row) == testCase.expected)
    }
}

@Test func windowFrameDistanceComparesPositionAndSize() {
    let lhs = WindowFrame(x: 10, y: 20, width: 300, height: 200)
    let rhs = WindowFrame(x: 14, y: 18, width: 310, height: 190)

    #expect(lhs.distance(to: rhs) == 26)
}

@Test func permissionInstructionsIncludeAppName() {
    let message = AccessibilityPermission.instructions(appName: "Ghostty")

    #expect(message.contains("Ghostty"))
    #expect(message.contains("winpick permissions --open-settings"))
}

@Test func notFocusableWindowErrorDescribesRawWindow() {
    let message = WinpickError.notFocusableWindow(
        id: 28,
        app: "Tailscale",
        title: ""
    ).description

    #expect(message.contains("Tailscale"))
    #expect(message.contains("raw macOS window records"))
    #expect(message.contains("focusable Accessibility window"))
}

@Test func fzfUnavailableErrorIncludesInstallHint() {
    let message = WinpickError.fzfUnavailable.description

    #expect(message.contains("fzf is required"))
    #expect(message.contains("brew install fzf"))
    #expect(message.contains("PATH"))
}

private func testWindow(
    id: Int,
    app: String = "Ghostty",
    title: String,
    pid: Int32 = 10,
    space: Int? = nil,
    frame: WindowFrame = WindowFrame(x: 0, y: 0, width: 100, height: 100)
) -> WindowRecord {
    WindowRecord(
        id: id,
        app: app,
        title: title,
        pid: pid,
        layer: 0,
        visible: true,
        frame: frame,
        space: space
    )
}

private func temporaryHistoryURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("winpick-history-\(UUID().uuidString)")
        .appendingPathComponent("history.json")
}

import Foundation
import Testing
@testable import WinpickCore

@Test func commandAliasesResolveToCanonicalCommands() {
    #expect(CLI.canonicalCommand("p") == "pick")
    #expect(CLI.canonicalCommand("l") == "list")
    #expect(CLI.canonicalCommand("ls") == "list")
    #expect(CLI.canonicalCommand("f") == "focus")
    #expect(CLI.canonicalCommand("c") == "current")
    #expect(CLI.canonicalCommand("cur") == "current")
    #expect(CLI.canonicalCommand("d") == "doctor")
    #expect(CLI.canonicalCommand("doc") == "doctor")
    #expect(CLI.canonicalCommand("perm") == "permissions")
    #expect(CLI.canonicalCommand("perms") == "permissions")
    #expect(CLI.canonicalCommand("h") == "help")
    #expect(CLI.canonicalCommand("ver") == "version")
}

@Test func shortFlagsMatchLongFlags() {
    #expect(CLI.hasJSONFlag(["-j"]))
    #expect(CLI.hasJSONFlag(["--json"]))
    #expect(CLI.hasAllFlag(["-a"]))
    #expect(CLI.hasAllFlag(["--all"]))
    #expect(CLI.hasOpenSettingsFlag(["-o"]))
    #expect(CLI.hasOpenSettingsFlag(["--open-settings"]))
}

@Test func windowDisplayTitleUsesAppWhenTitleIsEmpty() {
    let window = WindowRecord(
        id: 1,
        app: "Ghostty",
        title: "",
        pid: 10,
        layer: 0,
        visible: true,
        frame: WindowFrame(x: 0, y: 0, width: 100, height: 100)
    )

    #expect(window.displayTitle == "Ghostty")
}

@Test func windowDisplayTitleIncludesTitleWhenPresent() {
    let window = WindowRecord(
        id: 1,
        app: "Ghostty",
        title: "kbolt",
        pid: 10,
        layer: 0,
        visible: true,
        frame: WindowFrame(x: 0, y: 0, width: 100, height: 100)
    )

    #expect(window.displayTitle == "Ghostty - kbolt")
}

@Test func pickerLineShowsSpaceAppAndTitle() {
    let window = WindowRecord(
        id: 42,
        app: "Brave Browser",
        title: "ChatGPT",
        pid: 10,
        layer: 0,
        visible: true,
        frame: WindowFrame(x: 0, y: 0, width: 100, height: 100),
        space: 3
    )

    #expect(window.pickerLine == "S3\tBrave Browser\tChatGPT")
}

@Test func pickerLineUsesDashWhenSpaceIsUnknown() {
    let window = WindowRecord(
        id: 42,
        app: "Brave Browser",
        title: "",
        pid: 10,
        layer: 0,
        visible: true,
        frame: WindowFrame(x: 0, y: 0, width: 100, height: 100)
    )

    #expect(window.pickerLine == "-\tBrave Browser")
}

@Test func fzfDisplayLineShowsOnlySpaceAppAndTitle() {
    let window = WindowRecord(
        id: 42,
        app: "Ghostty",
        title: "ta kbolt",
        pid: 10,
        layer: 0,
        visible: true,
        frame: WindowFrame(x: 12, y: 34, width: 900, height: 700),
        space: 2
    )

    let line = FzfWindowPicker.displayLine(for: window, appWidth: 7)

    #expect(line == "   S2  Ghostty  ta kbolt")
    #expect(!line.contains("42"))
    #expect(!line.contains("900x700"))
}

@Test func fzfDisplayLineMarksRecentRows() {
    let window = WindowRecord(
        id: 42,
        app: "Ghostty",
        title: "ta kbolt",
        pid: 10,
        layer: 0,
        visible: true,
        frame: WindowFrame(x: 12, y: 34, width: 900, height: 700),
        space: 2
    )

    let line = FzfWindowPicker.displayLine(
        for: window,
        appWidth: 7,
        isRecent: true
    )

    #expect(line == "R  S2  Ghostty  ta kbolt")
}

@Test func fzfArgumentsHideMetadataAndPreview() {
    #expect(FzfWindowPicker.shellFzfCommand.contains("--with-nth=2"))
    #expect(FzfWindowPicker.shellFzfCommand.contains("--nth='1..'"))
    #expect(FzfWindowPicker.shellFzfCommand.contains("ctrl-j:down,ctrl-k:up"))
    #expect(!FzfWindowPicker.shellFzfCommand.contains("--preview"))
}

@Test func windowSortingGroupsBySpaceWithUnknownSpaceLast() {
    let windows = [
        WindowRecord(
            id: 30,
            app: "Ghostty",
            title: "unknown",
            pid: 10,
            layer: 0,
            visible: true,
            frame: WindowFrame(x: 0, y: 0, width: 100, height: 100)
        ),
        WindowRecord(
            id: 20,
            app: "Ghostty",
            title: "space two",
            pid: 10,
            layer: 0,
            visible: true,
            frame: WindowFrame(x: 0, y: 0, width: 100, height: 100),
            space: 2
        ),
        WindowRecord(
            id: 10,
            app: "Ghostty",
            title: "space one",
            pid: 10,
            layer: 0,
            visible: true,
            frame: WindowFrame(x: 0, y: 0, width: 100, height: 100),
            space: 1
        ),
        WindowRecord(
            id: 11,
            app: "Brave Browser",
            title: "space one",
            pid: 10,
            layer: 0,
            visible: true,
            frame: WindowFrame(x: 0, y: 0, width: 100, height: 100),
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

@Test func yabaiFocusableValueAcceptsStandardAXWindow() {
    let row: [String: Any] = [
        "role": "AXWindow",
        "has-ax-reference": true,
        "is-minimized": false,
        "is-hidden": false,
    ]

    #expect(SystemWindowLister.yabaiFocusableValue(row) == true)
}

@Test func yabaiFocusableValueRejectsNonWindowRows() {
    let row: [String: Any] = [
        "role": "AXMenu",
        "has-ax-reference": true,
    ]

    #expect(SystemWindowLister.yabaiFocusableValue(row) == false)
}

@Test func yabaiFocusableValueRejectsRowsWithoutAXReference() {
    let row: [String: Any] = [
        "role": "AXWindow",
        "has-ax-reference": false,
    ]

    #expect(SystemWindowLister.yabaiFocusableValue(row) == false)
}

@Test func yabaiFocusableValueFallsBackWhenMetadataIsMissing() {
    #expect(SystemWindowLister.yabaiFocusableValue([:]) == nil)
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

import Testing
@testable import WinpickCore

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

@Test func pickerLineStartsWithWindowID() {
    let window = WindowRecord(
        id: 42,
        app: "Brave Browser",
        title: "ChatGPT",
        pid: 10,
        layer: 0,
        visible: true,
        frame: WindowFrame(x: 0, y: 0, width: 100, height: 100)
    )

    #expect(window.pickerLine.hasPrefix("42\t"))
}

@Test func permissionInstructionsIncludeAppName() {
    let message = AccessibilityPermission.instructions(appName: "Ghostty")

    #expect(message.contains("Ghostty"))
    #expect(message.contains("winpick permissions --open-settings"))
}

import Foundation
import WinpickCore

let cli = CLI(
    lister: SystemWindowLister(),
    focuser: AccessibilityWindowFocuser(),
    picker: FzfWindowPicker()
)

exit(cli.run(Array(CommandLine.arguments.dropFirst())))

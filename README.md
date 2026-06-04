# winpick

A macOS CLI for selecting and focusing windows.

`winpick` exposes focusable macOS windows to the terminal. Use it to list
windows, focus a window by ID, inspect the current focused window, or pick a
window interactively.

## Capabilities

- List focusable windows
- Focus windows by macOS window ID
- Show the current focused window
- Pick a window interactively with `fzf`
- Emit JSON for scripts and agents
- Show Space labels when `yabai` is available

## Install

Homebrew:

```sh
brew install h3nock/tap/winpick
```

From source:

```sh
swift build -c release
install -m 0755 .build/release/winpick ~/.local/bin/winpick
```

## Usage

```sh
winpick                         # pick and focus a window
winpick pick                    # pick and focus a window
winpick list                    # list focusable windows
winpick focus <id>              # focus a window by ID
winpick current                 # print the current focused window
winpick doctor                  # check setup
winpick permissions -o          # open Accessibility settings
```

Aliases:

```text
pick: p
list: l, ls
focus: f
current: c, cur
doctor: d, doc
permissions: perm, perms
```

Use `--json` for machine-readable output:

```sh
winpick list --json
winpick current --json
winpick focus <id> --json
```

## Requirements

- macOS 14+
- Accessibility permission for the terminal app running `winpick`
- `fzf` for interactive picking
- `yabai` optional, used only for Space labels

Install picker dependency:

```sh
brew install fzf
```

## Permissions

Open Accessibility settings:

```sh
winpick permissions --open-settings
# Enable the terminal app running winpick, for example Ghostty.
```

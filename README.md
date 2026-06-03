# winpick

Keyboard and agent-friendly macOS window selection and focus.

`winpick` does not take screenshots. It finds focusable macOS windows, lets a
human pick one with `fzf`, and focuses/raises the selected window. The default
list keeps raw window surfaces that belong to apps with focusable Accessibility
windows, so menu-bar-only surfaces stay out of the picker. Agents can use the
same window metadata through JSON commands.

The baseline implementation uses macOS CoreGraphics and Accessibility APIs.
When `yabai` is available, `winpick` uses it as an optional metadata provider
for Space labels such as `S1`, `S2`, and `S3`. Without `yabai`, window picking
and focusing still work, but Space labels are shown as `-`.

The interactive picker uses a hybrid order: windows recently focused through
`winpick` appear first with an `R` marker, followed by the normal Space-sorted
list with duplicates removed. Recency is local state; there is no background
daemon.

## Requirements

Required:

```sh
brew install fzf
```

`fzf` is required for the interactive picker. Non-interactive commands such as
`winpick l`, `winpick f <id>`, `winpick c`, and `winpick d` still run without
`fzf`.

Optional:

```sh
brew install koekeishiya/formulae/yabai
```

`yabai` is only used for Space labels and faster metadata. `winpick` does not
require it.

## Usage

Pick a window interactively and focus it:

```sh
winpick
# or
winpick p
```

List focus candidates:

```sh
winpick l
```

List focus candidates for agents:

```sh
winpick l -j
```

List raw macOS window records, including non-focusable surfaces:

```sh
winpick l -a
```

Focus a window by id:

```sh
winpick f 12345
```

Check setup:

```sh
winpick d
```

Open the right macOS permission pane:

```sh
winpick perms -o
```

Pick and return JSON for automation:

```sh
winpick p -j
```

Recent history is stored at:

```text
$XDG_STATE_HOME/winpick/history.json
```

If `XDG_STATE_HOME` is not set, `winpick` uses:

```text
~/Library/Application Support/winpick/history.json
```

Command aliases:

```text
p=pick, l/ls=list, f=focus, c/cur=current, d/doc=doctor, perm/perms=permissions
-j=--json, -a=--all, -o=--open-settings
```

## tmux

Example popup binding:

```tmux
bind W display-popup -w 80% -h 70% -E 'winpick'
```

## Permissions

Default window listing and focusing require Accessibility permission for the
terminal app running `winpick`.

Use:

```sh
winpick permissions --open-settings
```

Then enable the app printed by `winpick`, usually `Ghostty`, in:

```text
System Settings -> Privacy & Security -> Accessibility
```

# winpick

Keyboard and agent-friendly macOS window selection and focus.

`winpick` does not take screenshots. It finds visible windows, lets a human pick
one with `fzf`, and focuses/raises the selected window. Agents can use the same
window metadata through JSON commands.

## Usage

Pick a window interactively and focus it:

```sh
winpick
```

List windows across Spaces:

```sh
winpick list
```

List windows across Spaces for agents:

```sh
winpick list --json
```

Focus a window by id:

```sh
winpick focus 12345
```

Check setup:

```sh
winpick doctor
```

Open the right macOS permission pane:

```sh
winpick permissions --open-settings
```

Pick and return JSON for automation:

```sh
winpick pick --json
```

## tmux

Example popup binding:

```tmux
bind W display-popup -w 80% -h 70% -E 'winpick'
```

## Permissions

Window listing uses native macOS window metadata. Focusing a selected window
requires Accessibility permission for the terminal app running `winpick`.

Use:

```sh
winpick permissions --open-settings
```

Then enable the app printed by `winpick`, usually `Ghostty`, in:

```text
System Settings -> Privacy & Security -> Accessibility
```

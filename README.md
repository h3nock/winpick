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

List visible windows:

```sh
winpick list
```

List visible windows for agents:

```sh
winpick list --json
```

Focus a window by id:

```sh
winpick focus 12345
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
requires Accessibility permission for the terminal running `winpick`.


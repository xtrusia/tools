# Monitor-Aware Alt+Tab

Windows Alt+Tab replacement that only shows windows on the monitor where your mouse cursor is.

Built with AutoHotkey v2.

## Features

- **Monitor-aware switching** — Only shows windows on the current monitor (based on mouse cursor position)
- **Minimized window support** — Detects minimized windows using their original position
- **App icons** — Extracts and displays 48x48 application icons via WM_GETICON / GetClassLongPtr
- **Dark theme UI** — Dark background with rounded corners (Windows 11) and semi-transparency
- **Keyboard navigation** — Alt+Tab to cycle, Shift+Alt+Tab to reverse, Enter to select, Escape to cancel

## Requirements

- Windows 10/11
- [AutoHotkey v2](https://www.autohotkey.com/)

## Usage

1. Run `MonitorAltTab.ahk` with AutoHotkey v2
2. Press **Alt+Tab** — window list appears for the current monitor
3. Keep holding **Alt**, press **Tab** to cycle through windows
4. Release **Alt** to activate the selected window

### Keybindings

| Key | Action |
|-----|--------|
| `Alt+Tab` | Open switcher / next window |
| `Alt+Shift+Tab` | Previous window |
| `Enter` | Activate selected window |
| `Escape` | Close switcher |
| Double-click | Activate window |

## Auto-start

To run on startup, create a shortcut to `MonitorAltTab.ahk` in:

```
shell:startup
```

## How it works

1. Intercepts `Alt+Tab` hotkey
2. Gets the monitor index from the current mouse cursor position
3. Enumerates all visible windows, filtering by:
   - `WS_VISIBLE` flag
   - Excludes `WS_EX_TOOLWINDOW` (tool windows)
   - Excludes owned windows (popups)
   - Excludes cloaked windows (virtual desktops)
4. For minimized windows, uses `GetWindowPlacement` to get the original position
5. Checks if each window's center point falls within the target monitor bounds
6. Displays a ListView with app icons in a dark-themed GUI

## License

MIT

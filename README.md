# Tools

A collection of Windows automation scripts built with AutoHotkey v2.

## Requirements

- Windows 10/11
- [AutoHotkey v2](https://www.autohotkey.com/)

## Scripts

### MonitorAltTab.ahk — Monitor-Aware Alt+Tab

Alt+Tab replacement that only shows windows on the monitor where your mouse cursor is.

**Features:**
- Only shows windows on the current monitor (based on mouse cursor position)
- Detects minimized windows using their original position (`GetWindowPlacement`)
- Displays 48x48 application icons extracted via `WM_GETICON` / `GetClassLongPtr`
- Dark theme UI with rounded corners (Windows 11) and semi-transparency
- Keyboard navigation: Tab to cycle, Shift+Tab to reverse, Enter/Alt release to select

**Keybindings:**

| Key | Action |
|-----|--------|
| `Alt+Tab` | Open switcher / next window |
| `Alt+Shift+Tab` | Previous window |
| `Enter` or release `Alt` | Activate selected window |
| `Escape` | Close switcher |
| Double-click | Activate window |

---

### focus_fullscreen.ahk — Auto-Fullscreen on Focus

Automatically maximizes the active window to fill the entire work area of a specific monitor, then restores it when focus moves away.

**Features:**
- Targets a specific monitor (default: monitor 3, configurable via `TargetMonitor`)
- Saves window position before maximizing, restores on defocus
- If the window is dragged to a different monitor, it restores to original size
- Exclude list for apps that shouldn't be affected (e.g., KakaoTalk)
- Configurable polling interval (`PollMs`, default 80ms)

**Configuration (edit the script):**

```ahk
global TargetMonitor := 3           ; Monitor number to apply auto-fullscreen
global PollMs := 80                 ; Polling interval in ms
global ExcludeList := ["KakaoTalk"] ; Excluded process names
```

**How it works:**
1. Polls the active window every `PollMs` milliseconds
2. If the active window is on the target monitor, saves its position and resizes it to fill the monitor's work area
3. When focus leaves the window (or window moves to another monitor), restores the original position and size

---

## Auto-start

To run any script on startup, create a shortcut in:

```
shell:startup
```

## License

MIT

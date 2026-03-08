#Requires AutoHotkey v2.0

global PrevHwnd := 0
global WindowRects := Map()
global TargetMonitor := 3    ; Only apply on monitor 3
global PollMs := 80          ; Poll interval (increase to 120-200 if flickering)
global ExcludeList := ["KakaoTalk"]  ; Excluded process names (without extension)

SetTimer(CheckActiveWindow, PollMs)

CheckActiveWindow() {
    global PrevHwnd, WindowRects, TargetMonitor

    try
        hwnd := WinGetID("A")
    catch
        return
    if (!hwnd)
        return

    ; Same window still focused: only check if it moved off the target monitor
    if (hwnd = PrevHwnd) {
        if (WindowRects.Has(hwnd)) {
            mon := GetMonitorIndexFromWindow(hwnd)
            if (mon != TargetMonitor) {
                r := WindowRects[hwnd]
                try WinMove(r.x, r.y, r.w, r.h, "ahk_id " hwnd)
                WindowRects.Delete(hwnd)
                PrevHwnd := 0
            }
        }
        return
    }

    ; 1) Restore previously active window to its saved position
    if (PrevHwnd && WindowRects.Has(PrevHwnd)) {
        r := WindowRects[PrevHwnd]
        try {
            if (WinGetMinMax("ahk_id " PrevHwnd) = 1)
                WinRestore("ahk_id " PrevHwnd)
            WinMove(r.x, r.y, r.w, r.h, "ahk_id " PrevHwnd)
        }
        WindowRects.Delete(PrevHwnd)
    }

    ; 2) Check exclude list
    try procName := WinGetProcessName("ahk_id " hwnd)
    catch
        return
    for name in ExcludeList {
        if InStr(procName, name) {
            PrevHwnd := hwnd
            return
        }
    }

    ; 3) Skip if window is not on the target monitor
    mon := GetMonitorIndexFromWindow(hwnd)
    PrevHwnd := hwnd
    if (mon != TargetMonitor)
        return

    ; 4) Restore from maximized state first
    try {
        if (WinGetMinMax("ahk_id " hwnd) = 1)
            WinRestore("ahk_id " hwnd)
    }

    ; 5) Save current window position
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        WindowRects[hwnd] := { x:x, y:y, w:w, h:h }
    }

    ; 6) Resize to fill monitor work area (preserves scroll position)
    try {
        MonitorGetWorkArea(TargetMonitor, &ml, &mt, &mr, &mb)
        WinMove(ml, mt, mr - ml, mb - mt, "ahk_id " hwnd)
    }
}

; Get monitor index from window center point
GetMonitorIndexFromWindow(hwnd) {
    count := MonitorGetCount()
    WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
    cx := wx + ww/2
    cy := wy + wh/2

    Loop count {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (cx >= l && cx <= r && cy >= t && cy <= b)
            return A_Index
    }
    return 0
}

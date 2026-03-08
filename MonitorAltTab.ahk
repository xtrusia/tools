#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; Monitor-Aware Alt+Tab — Switch only windows on the current monitor
; ListView + Icons + Dark theme + Rounded corners + Translucency
; ============================================================

; Intercept Alt+Tab
!Tab:: {
    ShowMonitorSwitcher()
}

; Global variables for GUI state
global g_Gui := ""
global g_LV := ""
global g_Windows := []
global g_Selected := 1
global g_ImageList := 0

ShowMonitorSwitcher() {
    global g_Gui, g_LV, g_Windows, g_Selected, g_ImageList

    ; Close existing GUI
    if g_Gui {
        g_Gui.Destroy()
        g_Gui := ""
    }

    ; Get monitor index from mouse position
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    monIdx := GetMonitorFromPoint(mx, my)

    if !monIdx
        return

    ; Get work area bounds for the target monitor
    MonitorGetWorkArea(monIdx, &mLeft, &mTop, &mRight, &mBottom)

    ; Collect visible windows on the target monitor
    g_Windows := []
    for hwnd in WinGetList() {
        try title := WinGetTitle(hwnd)
        catch
            continue
        if !title
            continue

        try style := WinGetStyle(hwnd)
        catch
            continue
        if !(style & 0x10000000)  ; WS_VISIBLE
            continue

        try exStyle := WinGetExStyle(hwnd)
        catch
            continue
        if (exStyle & 0x00000080)  ; WS_EX_TOOLWINDOW
            continue

        ; Skip owned windows (popups, dialogs)
        try {
            if DllCall("GetWindow", "Ptr", hwnd, "UInt", 4, "Ptr")  ; GW_OWNER
                continue
        }

        ; Skip cloaked windows (hidden on other virtual desktops)
        cloaked := 0
        DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd
            , "UInt", 14, "UInt*", &cloaked, "UInt", 4)  ; DWMWA_CLOAKED
        if cloaked
            continue

        ; For minimized windows, use WINDOWPLACEMENT to get original position
        try WinGetPos(&wx, &wy, &ww, &wh, hwnd)
        catch
            continue

        isMinimized := (style & 0x20000000)  ; WS_MINIMIZE
        if isMinimized {
            ; Get original position from WINDOWPLACEMENT struct
            wp := Buffer(44, 0)
            NumPut("UInt", 44, wp, 0)  ; length
            DllCall("GetWindowPlacement", "Ptr", hwnd, "Ptr", wp)
            wx := NumGet(wp, 28, "Int")  ; rcNormalPosition.left
            wy := NumGet(wp, 32, "Int")  ; rcNormalPosition.top
            ww := NumGet(wp, 36, "Int") - wx  ; right - left
            wh := NumGet(wp, 40, "Int") - wy  ; bottom - top
        }

        cx := wx + ww // 2
        cy := wy + wh // 2

        if (cx >= mLeft && cx < mRight && cy >= mTop && cy < mBottom) {
            try procName := WinGetProcessName(hwnd)
            catch
                procName := ""
            g_Windows.Push({hwnd: hwnd, title: title, proc: procName})
        }
    }

    if g_Windows.Length = 0
        return

    ; Start from second window (mimics Alt+Tab behavior)
    g_Selected := g_Windows.Length > 1 ? 2 : 1

    ; === Build GUI ===
    g_Gui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g_Gui.BackColor := "1a1a1a"
    g_Gui.MarginX := 20
    g_Gui.MarginY := 16

    ; Header text
    g_Gui.SetFont("s18 c666666", "Segoe UI Semibold")
    g_Gui.Add("Text", "w800 Center", "Monitor " monIdx "  ·  " g_Windows.Length " windows")
    g_Gui.Add("Text", "w800 h2 Background333333")  ; separator line

    ; Create 48x48 ImageList
    g_ImageList := DllCall("ImageList_Create", "Int", 48, "Int", 48, "UInt", 0x00020021, "Int", g_Windows.Length, "Int", 5, "Ptr")

    ; Create ListView (no header, full-row select)
    g_Gui.SetFont("s32 cE8E8E8", "Segoe UI")
    rowCount := Min(g_Windows.Length, 8)
    g_LV := g_Gui.Add("ListView"
        , "w800 r" rowCount
        . " -Hdr +LV0x20 Background1a1a1a cE8E8E8 -Multi"
        , ["Title"])

    ; Set small icon list for Report view
    SendMessage(0x1003, 1, g_ImageList,, g_LV.Hwnd)  ; LVM_SETIMAGELIST, LVSIL_SMALL=1

    ; Add icons and window entries
    for win in g_Windows {
        hIcon := GetWindowIcon(win.hwnd, true)  ; request large icon
        iconIdx := -1
        if hIcon {
            ; Create a resized 48x48 copy
            hResized := DllCall("CopyImage", "Ptr", hIcon, "UInt", 1, "Int", 48, "Int", 48, "UInt", 0x4, "Ptr")
            if hResized
                iconIdx := DllCall("ImageList_ReplaceIcon", "Ptr", g_ImageList, "Int", -1, "Ptr", hResized)
            if !hResized || iconIdx < 0
                iconIdx := DllCall("ImageList_ReplaceIcon", "Ptr", g_ImageList, "Int", -1, "Ptr", hIcon)
        }
        g_LV.Add((iconIdx >= 0 ? "Icon" (iconIdx + 1) : ""), "   " TruncateTitle(win.title, 40))
    }

    g_LV.ModifyCol(1, 780)

    ; Set initial selection
    g_LV.Modify(g_Selected, "Select Focus Vis")

    ; Events
    g_LV.OnEvent("DoubleClick", OnLVDoubleClick)
    g_Gui.OnEvent("Escape", OnGuiClose)

    ; Center GUI on the target monitor
    mw := mRight - mLeft
    mh := mBottom - mTop
    g_Gui.Show("Hide")
    g_Gui.GetPos(,, &gw, &gh)
    gx := mLeft + (mw - gw) // 2
    gy := mTop + (mh - gh) // 2
    g_Gui.Show("x" gx " y" gy " NoActivate")

    ; Apply rounded corners (Windows 11)
    DllCall("dwmapi\DwmSetWindowAttribute"
        , "Ptr", g_Gui.Hwnd
        , "UInt", 33     ; DWMWA_WINDOW_CORNER_PREFERENCE
        , "UInt*", 2     ; DWMWCP_ROUND
        , "UInt", 4)

    ; Semi-transparent effect
    WinSetTransparent(235, g_Gui)

    ; Wait for keyboard input
    WaitForSelection()
}

WaitForSelection() {
    global g_Gui, g_LV, g_Windows, g_Selected

    loop {
        ; Activate selected when Alt is released
        if !GetKeyState("Alt", "P") {
            ActivateSelected()
            return
        }

        ; Tab = cycle next/previous
        if GetKeyState("Tab", "P") {
            if GetKeyState("Shift", "P")
                g_Selected := g_Selected > 1 ? g_Selected - 1 : g_Windows.Length
            else
                g_Selected := g_Selected < g_Windows.Length ? g_Selected + 1 : 1
            g_LV.Modify(0, "-Select -Focus")
            g_LV.Modify(g_Selected, "Select Focus Vis")
            KeyWait("Tab")
        }

        ; Escape = cancel
        if GetKeyState("Escape", "P") {
            OnGuiClose(g_Gui)
            return
        }

        ; Enter = confirm selection
        if GetKeyState("Enter", "P") {
            ActivateSelected()
            return
        }

        Sleep(30)
    }
}

ActivateSelected() {
    global g_Gui, g_Windows, g_Selected

    if g_Selected >= 1 && g_Selected <= g_Windows.Length {
        hwnd := g_Windows[g_Selected].hwnd
        try {
            WinActivate(hwnd)
            WinMoveTop(hwnd)
        }
    }

    if g_Gui {
        g_Gui.Destroy()
        g_Gui := ""
    }
}

OnLVDoubleClick(ctrl, row) {
    global g_Selected
    if row > 0 {
        g_Selected := row
        ActivateSelected()
    }
}

OnGuiClose(gui, *) {
    global g_Gui
    if g_Gui {
        g_Gui.Destroy()
        g_Gui := ""
    }
}

; Get monitor index from screen coordinates
GetMonitorFromPoint(x, y) {
    count := MonitorGetCount()
    loop count {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (x >= l && x < r && y >= t && y < b)
            return A_Index
    }
    return MonitorGetPrimary()
}

; Extract window icon (HICON) with fallback chain
GetWindowIcon(hwnd, useBig := false) {
    static WM_GETICON := 0x007F
    hIcon := 0

    if useBig {
        ; Big icon first: ICON_BIG(1) -> ICON_SMALL(0)
        try hIcon := SendMessage(WM_GETICON, 1, 0,, "ahk_id " hwnd)
        if !hIcon
            try hIcon := SendMessage(WM_GETICON, 0, 0,, "ahk_id " hwnd)
        ; GetClassLongPtr fallback: GCL_HICON -> GCL_HICONSM
        if !hIcon
            hIcon := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", -14, "Ptr")
        if !hIcon
            hIcon := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", -34, "Ptr")
    } else {
        ; Small icon first: ICON_SMALL2(2) -> ICON_SMALL(0) -> ICON_BIG(1)
        try hIcon := SendMessage(WM_GETICON, 2, 0,, "ahk_id " hwnd)
        if !hIcon
            try hIcon := SendMessage(WM_GETICON, 0, 0,, "ahk_id " hwnd)
        if !hIcon
            try hIcon := SendMessage(WM_GETICON, 1, 0,, "ahk_id " hwnd)
        if !hIcon
            hIcon := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", -34, "Ptr")
        if !hIcon
            hIcon := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", -14, "Ptr")
    }

    return hIcon
}

; Truncate title to max length with ellipsis
TruncateTitle(title, maxLen) {
    if StrLen(title) > maxLen
        return SubStr(title, 1, maxLen - 3) "..."
    return title
}

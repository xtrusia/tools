#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; Monitor-Aware Alt+Tab — 마우스 커서가 있는 모니터의 창만 전환
; ListView + 아이콘 + 다크테마 + 둥근 모서리 + 반투명
; ============================================================

; Alt+Tab 가로채기
!Tab:: {
    ShowMonitorSwitcher()
}

; GUI 관련 전역 변수
global g_Gui := ""
global g_LV := ""
global g_Windows := []
global g_Selected := 1
global g_ImageList := 0

ShowMonitorSwitcher() {
    global g_Gui, g_LV, g_Windows, g_Selected, g_ImageList

    ; 기존 GUI 닫기
    if g_Gui {
        g_Gui.Destroy()
        g_Gui := ""
    }

    ; 마우스 위치 → 모니터 번호
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    monIdx := GetMonitorFromPoint(mx, my)

    if !monIdx
        return

    ; 해당 모니터의 경계 가져오기
    MonitorGetWorkArea(monIdx, &mLeft, &mTop, &mRight, &mBottom)

    ; visible 창 수집 (해당 모니터에 있는 것만)
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

        ; 소유자 있는 창 제외
        try {
            if DllCall("GetWindow", "Ptr", hwnd, "UInt", 4, "Ptr")
                continue
        }

        ; Cloaked 창 제외 (가상 데스크톱)
        cloaked := 0
        DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd
            , "UInt", 14, "UInt*", &cloaked, "UInt", 4)
        if cloaked
            continue

        ; 최소화된 창은 WINDOWPLACEMENT의 rcNormalPosition으로 원래 위치 확인
        try WinGetPos(&wx, &wy, &ww, &wh, hwnd)
        catch
            continue

        isMinimized := (style & 0x20000000)  ; WS_MINIMIZE
        if isMinimized {
            ; WINDOWPLACEMENT 구조체로 원래 위치 가져오기
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

    ; 선택 인덱스 초기화 (두 번째 창 = Alt+Tab 느낌)
    g_Selected := g_Windows.Length > 1 ? 2 : 1

    ; === GUI 생성 ===
    g_Gui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g_Gui.BackColor := "1a1a1a"
    g_Gui.MarginX := 20
    g_Gui.MarginY := 16

    ; 헤더 텍스트
    g_Gui.SetFont("s18 c666666", "Segoe UI Semibold")
    g_Gui.Add("Text", "w800 Center", "Monitor " monIdx "  ·  " g_Windows.Length " windows")
    g_Gui.Add("Text", "w800 h2 Background333333")  ; 구분선

    ; ImageList 생성 (48x48 커스텀 크기)
    g_ImageList := DllCall("ImageList_Create", "Int", 48, "Int", 48, "UInt", 0x00020021, "Int", g_Windows.Length, "Int", 5, "Ptr")

    ; ListView 생성 (헤더 숨김, 풀 행 선택)
    g_Gui.SetFont("s32 cE8E8E8", "Segoe UI")
    rowCount := Min(g_Windows.Length, 8)
    g_LV := g_Gui.Add("ListView"
        , "w800 r" rowCount
        . " -Hdr +LV0x20 Background1a1a1a cE8E8E8 -Multi"
        , ["Title"])

    ; small icon list로 설정 (Report 뷰에서 사용)
    SendMessage(0x1003, 1, g_ImageList,, g_LV.Hwnd)  ; LVM_SETIMAGELIST, LVSIL_SMALL=1

    ; 아이콘 + 창 목록 추가
    for win in g_Windows {
        hIcon := GetWindowIcon(win.hwnd, true)  ; 큰 아이콘 요청
        iconIdx := -1
        if hIcon {
            ; 48x48로 리사이즈된 복사본 생성
            hResized := DllCall("CopyImage", "Ptr", hIcon, "UInt", 1, "Int", 48, "Int", 48, "UInt", 0x4, "Ptr")
            if hResized
                iconIdx := DllCall("ImageList_ReplaceIcon", "Ptr", g_ImageList, "Int", -1, "Ptr", hResized)
            if !hResized || iconIdx < 0
                iconIdx := DllCall("ImageList_ReplaceIcon", "Ptr", g_ImageList, "Int", -1, "Ptr", hIcon)
        }
        g_LV.Add((iconIdx >= 0 ? "Icon" (iconIdx + 1) : ""), "   " TruncateTitle(win.title, 40))
    }

    g_LV.ModifyCol(1, 780)

    ; 초기 선택 표시
    g_LV.Modify(g_Selected, "Select Focus Vis")

    ; 이벤트
    g_LV.OnEvent("DoubleClick", OnLVDoubleClick)
    g_Gui.OnEvent("Escape", OnGuiClose)

    ; 모니터 중앙에 표시
    mw := mRight - mLeft
    mh := mBottom - mTop
    g_Gui.Show("Hide")
    g_Gui.GetPos(,, &gw, &gh)
    gx := mLeft + (mw - gw) // 2
    gy := mTop + (mh - gh) // 2
    g_Gui.Show("x" gx " y" gy " NoActivate")

    ; Windows 11 둥근 모서리
    DllCall("dwmapi\DwmSetWindowAttribute"
        , "Ptr", g_Gui.Hwnd
        , "UInt", 33     ; DWMWA_WINDOW_CORNER_PREFERENCE
        , "UInt*", 2     ; DWMWCP_ROUND
        , "UInt", 4)

    ; 반투명 효과
    WinSetTransparent(235, g_Gui)

    ; 키 입력 대기
    WaitForSelection()
}

WaitForSelection() {
    global g_Gui, g_LV, g_Windows, g_Selected

    loop {
        ; Alt 떼면 현재 선택 활성화
        if !GetKeyState("Alt", "P") {
            ActivateSelected()
            return
        }

        ; Tab → 다음/이전 순환
        if GetKeyState("Tab", "P") {
            if GetKeyState("Shift", "P")
                g_Selected := g_Selected > 1 ? g_Selected - 1 : g_Windows.Length
            else
                g_Selected := g_Selected < g_Windows.Length ? g_Selected + 1 : 1
            g_LV.Modify(0, "-Select -Focus")
            g_LV.Modify(g_Selected, "Select Focus Vis")
            KeyWait("Tab")
        }

        ; Escape
        if GetKeyState("Escape", "P") {
            OnGuiClose(g_Gui)
            return
        }

        ; Enter
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

; 마우스 좌표 → 모니터 번호
GetMonitorFromPoint(x, y) {
    count := MonitorGetCount()
    loop count {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (x >= l && x < r && y >= t && y < b)
            return A_Index
    }
    return MonitorGetPrimary()
}

; 윈도우 아이콘 추출
GetWindowIcon(hwnd, useBig := false) {
    static WM_GETICON := 0x007F
    hIcon := 0

    if useBig {
        ; 큰 아이콘 우선: ICON_BIG(1) → ICON_SMALL(0)
        try hIcon := SendMessage(WM_GETICON, 1, 0,, "ahk_id " hwnd)
        if !hIcon
            try hIcon := SendMessage(WM_GETICON, 0, 0,, "ahk_id " hwnd)
        ; GetClassLongPtr 폴백: GCL_HICON → GCL_HICONSM
        if !hIcon
            hIcon := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", -14, "Ptr")
        if !hIcon
            hIcon := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", -34, "Ptr")
    } else {
        ; 작은 아이콘 우선
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

; 타이틀 자르기
TruncateTitle(title, maxLen) {
    if StrLen(title) > maxLen
        return SubStr(title, 1, maxLen - 3) "..."
    return title
}

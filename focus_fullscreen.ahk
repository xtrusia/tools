#Requires AutoHotkey v2.0

global PrevHwnd := 0
global WindowRects := Map()
global TargetMonitor := 3    ; 3번 모니터에서만 적용
global PollMs := 80          ; 감지 주기(깜빡이면 120~200으로 올리기)
global ExcludeList := ["KakaoTalk"]  ; 제외할 프로세스 이름 (확장자 빼고)

SetTimer(CheckActiveWindow, PollMs)

CheckActiveWindow() {
    global PrevHwnd, WindowRects, TargetMonitor

    try
        hwnd := WinGetID("A")
    catch
        return
    if (!hwnd)
        return

    ; 같은 창이 계속 포커스인 경우: 모니터 이탈 여부만 확인
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

    ; 1) 이전 활성 창을 저장된 위치로 복구
    if (PrevHwnd && WindowRects.Has(PrevHwnd)) {
        r := WindowRects[PrevHwnd]
        try {
            if (WinGetMinMax("ahk_id " PrevHwnd) = 1)
                WinRestore("ahk_id " PrevHwnd)
            WinMove(r.x, r.y, r.w, r.h, "ahk_id " PrevHwnd)
        }
        WindowRects.Delete(PrevHwnd)
    }

    ; 2) 제외 목록 체크
    try procName := WinGetProcessName("ahk_id " hwnd)
    catch
        return
    for name in ExcludeList {
        if InStr(procName, name) {
            PrevHwnd := hwnd
            return
        }
    }

    ; 3) 현재 창이 지정 모니터가 아니면 아무것도 안 함
    mon := GetMonitorIndexFromWindow(hwnd)
    PrevHwnd := hwnd
    if (mon != TargetMonitor)
        return

    ; 4) 최대화 상태면 먼저 복원
    try {
        if (WinGetMinMax("ahk_id " hwnd) = 1)
            WinRestore("ahk_id " hwnd)
    }

    ; 5) 현재 활성 창의 위치 저장
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        WindowRects[hwnd] := { x:x, y:y, w:w, h:h }
    }

    ; 6) 모니터 작업영역 크기로 이동 (스크롤 유지)
    try {
        MonitorGetWorkArea(TargetMonitor, &ml, &mt, &mr, &mb)
        WinMove(ml, mt, mr - ml, mb - mt, "ahk_id " hwnd)
    }
}

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

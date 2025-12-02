
; === AutoHotkey v2 – Set brightness on ALL monitors (including laptop built-in) ===
; Works on Windows 10/11

NewBrightness := 70   ; ←←← Change this value (0–100)

; ------------------------------------------------------------
; 1. Try DXVA2 method (works perfectly on external monitors + many laptops)
; ------------------------------------------------------------
TrySetViaDXVA2(NewBrightness)

; ------------------------------------------------------------
; 2. Try WMI method (works on almost all laptops where DXVA2 is blocked)
; ------------------------------------------------------------
TrySetViaWMI(NewBrightness)


; ================================================================
TrySetViaDXVA2(target) {
    if !dxva2 := DllCall("LoadLibrary", "Str", "dxva2.dll", "Ptr")
        return

    handles := []

    EnumProc(hMon, hdc, lprc, dwData) {
        handles.Push(hMon)
        return true
    }

    DllCall("user32\EnumDisplayMonitors"
        , "Ptr", 0, "Ptr", 0
        , "Ptr", CallbackCreate(EnumProc, "F")
        , "Ptr", 0)

    for hMon in handles {
        if !DllCall("dxva2\GetNumberOfPhysicalMonitorsFromHMONITOR", "Ptr", hMon, "UInt*", &cnt := 0)
            continue

        buf := Buffer(cnt * (A_PtrSize + 256), 0)
        if !DllCall("dxva2\GetPhysicalMonitorsFromHMONITOR", "Ptr", hMon, "UInt", cnt, "Ptr", buf)
            continue

        loop cnt {
            hPhys := NumGet(buf, (A_Index-1)*(A_PtrSize + 256), "Ptr")
            ; Get current range
            DllCall("dxva2\GetMonitorBrightness", "Ptr", hPhys
                , "UInt*", &min:=0, "UInt*", &cur:=0, "UInt*", &max:=0)
            newVal := target < min ? min : target > max ? max : target
            DllCall("dxva2\SetMonitorBrightness", "Ptr", hPhys, "UInt", newVal)
        }
        DllCall("dxva2\DestroyPhysicalMonitors", "UInt", cnt, "Ptr", buf)
    }
    DllCall("FreeLibrary", "Ptr", dxva2)
}

TrySetViaWMI(target) {
    try {
        wmi := ComObjGet("winmgmts:\\.\root\wmi")
        for obj in wmi.ExecQuery("SELECT * FROM WmiMonitorBrightnessMethods") {
            obj.WmiSetBrightness(1, target)  ; 1 = timeout in seconds
        }
    }
}

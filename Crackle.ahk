#Requires AutoHotkey v2.0
#SingleInstance Force

; ===== Global Variables =====
global showing := false
global pressCount := 0
global lastPressTime := 0
global flyoutWidth := 200
global flyoutHeight := A_ScreenHeight
global flyout

; ===== Triple Ctrl Detection to Toggle Flyout =====
~Ctrl up::
{
    global pressCount, lastPressTime
    now := A_TickCount
    if (now - lastPressTime < 400)
        pressCount += 1
    else
        pressCount := 1
    lastPressTime := now

    if (pressCount >= 3) {
        ToggleFlyout()
        pressCount := 0
    }
    SetTimer(ResetPressCount, -500)
}

ResetPressCount() {
    global pressCount
    pressCount := 0
}

; ===== Flyout Toggle / Focus & Position Logic =====
ToggleFlyout() {
    global flyout, showing, flyoutWidth, flyoutHeight

    if !IsSet(flyout)
        LoadShortcuts()

    monitor := MonitorGetPrimary()
    MonitorGetWorkArea(monitor, &left, &top, &right, &bottom)
    primaryX := left
    primaryY := top
    screenH := bottom - top
    flyoutHeight := screenH

    if showing {
        HideFlyout()
        return
    }

    showing := true
    flyout.Move(primaryX, primaryY, 0, flyoutHeight)
    flyout.Show()

    steps := 20
    loop steps {
        curWidth := Round(flyoutWidth * A_Index / steps)
        flyout.Move(primaryX, primaryY, curWidth, flyoutHeight)
        Sleep(10)
    }

    flyout.Move(primaryX, primaryY, flyoutWidth, flyoutHeight)
}

; ===== Instant Flyout Hide =====
HideFlyout() {
    global flyout, showing
    flyout.Hide()
    showing := false
}

; ===== Shortcut Loader from File =====
LoadShortcuts() {
    global flyout

    flyout := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "Web Shortcuts")
    flyout.MarginX := 10
    flyout.MarginY := 10

    refreshBtn := flyout.AddButton("w180", "🔄 Refresh Shortcuts")
    refreshBtn.OnEvent("Click", (*) => Reload())

    shortcutsFile := A_ScriptDir "\shortcuts.txt"
    if FileExist(shortcutsFile) {
        fileContent := FileRead(shortcutsFile, "UTF-8")
        yOffset := 50  ; Offset below refresh button

        for line in StrSplit(Trim(fileContent), "`n") {
            line := Trim(line)
            if line = ""
                continue

            ; Category header line: starts with #
            if SubStr(line, 1, 1) = "#" {
                flyout.AddText("x10 y" yOffset " w180 +0x200", SubStr(line, 2)) ; Bold label
                yOffset += 25
                continue
            }

            ; Must contain label|url
            if !InStr(line, "|")
                continue

            parts := StrSplit(line, "|")
            label := parts[1]
            url := parts[2]
            profile := parts.Length >= 3 && parts[3] != "" ? parts[3] : "Default"

            if !RegExMatch(url, "^(https?|edge)://")
                continue

            AddShortcutButton(label, url, profile, yOffset)
            yOffset += 35
        }
    }
}

; ===== Creates a Shortcut Button with Window Detection =====
AddShortcutButton(label, url, profile, y) {
    global flyout
    btn := flyout.AddButton("x10 y" y " w180", label)
    btn.OnEvent("Click", (*) => TryActivateApp(label, url, profile))
}

; ===== Check if app window is open and activate or launch =====
TryActivateApp(label, url, profile) {
    global flyout, showing
    SetTitleMatchMode(2)

    hwnd := WinExist(label)
    if hwnd {
        WinTitle := "ahk_id " hwnd
        if WinGetMinMax(WinTitle) = 1
            WinRestore(WinTitle)
        WinActivate(WinTitle)
        WinMaximize(WinTitle)
    } else {
        Run('msedge.exe --app="' url '" --profile-directory="' profile '"')
        ; Wait up to 5 seconds for the window to appear
        if WinWait(label, , 5) {
            hwnd := WinExist(label)
            if hwnd {
                WinTitle := "ahk_id " hwnd
                WinActivate(WinTitle)
                WinMaximize(WinTitle)
            }
        }
    }

    if showing {
        HideFlyout()
    }
}

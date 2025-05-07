#Requires AutoHotkey v2.0
#SingleInstance Force

; ===== Global Variables =====
global showing := false
global pressCount := 0
global lastPressTime := 0
global flyoutWidth := 200
global flyoutHeight := A_ScreenHeight
global flyout

; ===== GUI Setup =====
flyout := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "Web Shortcuts")
flyout.MarginX := 10
flyout.MarginY := 10

; Add Refresh Button
refreshBtn := flyout.AddButton("w180", "🔄 Refresh Shortcuts")
refreshBtn.OnEvent("Click", (*) => Reload())

LoadShortcuts()
flyout.Show("x-" flyoutWidth " y0 w" flyoutWidth " h" flyoutHeight)

; ===== Triple Ctrl Detection to Toggle Flyout =====
~Ctrl::
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

    ; Move to primary screen, full height
    primaryX := SysGet(76) ; SM_XVIRTUALSCREEN
    primaryY := SysGet(77) ; SM_YVIRTUALSCREEN
    screenH := SysGet(1)   ; SM_CYSCREEN
    flyoutHeight := screenH

    ; If already showing, bring to front and reposition
    if showing {
        flyout.Move(primaryX, primaryY, flyoutWidth, flyoutHeight)
        flyout.Opt("+AlwaysOnTop")
        flyout.Show()
        return
    }

    showing := true
    x := -flyoutWidth
    targetX := primaryX

    ; Slide-in animation from left
    loop 20 {
        percent := A_Index / 20
        curX := Round(x + (targetX - x) * percent)
        flyout.Move(curX, primaryY, flyoutWidth, flyoutHeight)
        Sleep(10)
    }
    flyout.Move(targetX, primaryY, flyoutWidth, flyoutHeight)
}

; ===== Shortcut Loader from File =====
LoadShortcuts() {
    global flyout

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

; ===== Creates a Shortcut Button with Bound Data =====
AddShortcutButton(label, url, profile, y) {
    global flyout
    btn := flyout.AddButton("x10 y" y " w180", label)
    btn.OnEvent("Click", (*) => (
        InStr(url, "edge://")
            ? Run("msedge.exe --profile-directory=" profile " " url)
            : Run("msedge.exe --app=" url " --profile-directory=" profile)
    ))
}

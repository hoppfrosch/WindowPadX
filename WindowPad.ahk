; WindowPad v1.60
;   http://www.autohotkey.com/forum/topic21703.html
;   Requires AutoHotkey v1.0.48 or later.

#SingleInstance force

applicationname=WindowPad

if 0 > 0
{
    ; Command-line mode: interpret each arg as a pseudo-command.
    ; Suspend all hotkeys which may be created by WindowPadInit.
    Suspend On
    ; Load options and Gather exclusions.
    gosub WindowPadInit
    ; Execute command line(s).  Each args should be in one of these formats:
    ;   <command>
    ;   <command>,<args_no_spaces>
    ;   "<command>, <args>"    ; In this case the initial comma is optional.
    Loop %0%
        wp_ExecLine(%A_Index%)
    ExitApp
}

WindowPadInit:
    ; If this script is #included in another script, this section may not be
    ; auto-executed.  In that case, the following should be called manually:
    WindowPad_Init(WINDOWPAD_INI_PATH)
  return

WindowPad_Init(IniPath="")
{
    global WINDOWPAD_INI_PATH
    ;
    ; Init icons and tray menu.
    ;
    if A_IsCompiled  ; Load icons from my custom WindowPad.exe.
    {
        ; Default icon is 32x32, so doesn't look good in the tray.
        Menu, Tray, Icon, %A_ScriptFullPath%, 2
    }
    else if (A_LineFile = A_ScriptFullPath)
    {   ; Set the tray icon, but only if not included in some other script.
        wp_SetTrayIcon(true)
        ; Use OnMessage to catch "Suspend Hotkeys" or "Pause Script"
        ; so the "disabled" icon can be used.
        OnMessage(0x111, "WM_COMMAND")
    }
        
    Menu, Tray, NoStandard
    Menu, Tray, MainWindow
    Menu, Tray, Add, &Debug, TrayDebug
    ifExist, %A_ScriptDir%\WindowPad.html
    {
        Menu, Tray, Add, &Help, TrayHelp
        Menu, Tray, Add
    }
    Menu, Tray, Add, &Reload, TrayReload
    if !A_IsCompiled
    {
        Menu, Tray, Add, &Edit Source, TrayEdit
    }
    Menu, Tray, Add, Edit &Configuration, TrayEditConfig
    Menu, Tray, Add
    Menu, Tray, Add, &Suspend, TraySuspend
    Menu, Tray, Add, E&xit, TrayExit
    Menu, Tray, Default, &Debug    
    ;
    ; Load settings.
    ;
    if IniPath =
        Loop, %A_LineFile%\..\WindowPad.ini
            IniPath := A_LoopFileFullPath
    ifNotExist %IniPath%
    {
        IniPath = %A_ScriptDir%\WindowPad.ini
        FileInstall, WindowPad.Default.ini, %IniPath%
    }
    WINDOWPAD_INI_PATH := IniPath
    WindowPad_LoadSettings(IniPath)
}

WindowPad_LoadSettings(ininame)
{
    local v
    
    ; Misc Options
    IniRead, v, %ininame%, Options, TitleMatchMode, %A_TitleMatchMode%
    SetTitleMatchMode, %v%
    
    ; Hotkeys: Exclude Windows
    v := wp_INI_GetList(ininame, "Exclude Windows", "Window")
    Loop, Parse, v, `n
        GroupAdd, HotkeyExclude, %A_LoopField%
    
    ; Read the Hotkeys section in.
    v := wp_INI_ReadSection(ininame, "Hotkeys")
    ; Replace the first = with ::.
    ; ('=' is required for WritePrivateProfileSection to work properly.)
    v := RegExReplace(v, "m`a)^(.*?)=", "$1::")
    Hotkey, IfWinNotActive, ahk_group HotkeyExclude
    Hotkey_Params(v)
    
    ; Gather: Exclude Windows
    v := wp_INI_GetList(ininame, "Gather: Exclude Windows", "Window")
    Loop, Parse, v, `n
        GroupAdd, GatherExclude, %A_LoopField%

    ; Gather: Exclude Processes
    ProcessGatherExcludeList := wp_INI_GetList(ininame
        , "Gather: Exclude Processes", "Process", ",")
}

wp_INI_GetList(ininame, Section, Key, Delim="`n")
{
    v := wp_INI_ReadSection(ininame, Section)
    Loop, Parse, v, `n
    {
        pos := InStr(A_LoopField, "=")
        if (pos && SubStr(A_LoopField,1,pos-1) = Key)
            list .= (list ? Delim : "") . SubStr(A_LoopField, pos+1)
    }
    return list
}

wp_INI_ReadSection(Filename, Section)
{
    char_type := A_IsUnicode ? "UShort" : "UChar"
    char_size := A_IsUnicode ? 2 : 1
    
    ; Expand relative paths, since GetPrivateProfileSection only searches %A_WinDir%.
    Loop, %Filename%, 0
        Filename := A_LoopFileLongPath
    
    VarSetCapacity(buf, 0x7FFF*char_size, 0)

    len := DllCall("GetPrivateProfileSection"
        , "uint", &Section, "uint", &buf, "uint", 0x7FFF, "uint", &Filename)
    
    VarSetCapacity(text, len*char_size), p := &buf
    ; For each null-terminated substring,
    while (s := DllCall("MulDiv", "int", p, "int", 1, "int", 1, "str"))
        ; append it to the output and advance to the next substring.
        text .= s "`n",  p += (StrLen(s)+1)*char_size
    
    ; Strip the trailing newline
    text := SubStr(text, 1, -1)
    
    ; Windows Me/98/95:
    ;   The returned string includes comments.
    ;
    ; This removes comments. Also, I'm not sure if leading/trailing space is
    ; automatically removed on Win9x, so the regex removes that too.
    if A_OSVersion in WIN_ME,WIN_98,WIN_95
        text := RegExReplace(text, "m`n)^[ `t]*(?:;.*`n?|`n)|^[ `t]+|[ `t]+$")
    
    return text
}


; Tray menu subroutines. May also be assigned to hotkeys in WindowPad.ini.
TrayDebug:
    ListHotkeys
  return
TrayHelp:
    Run, %A_ScriptDir%\WindowPad.html
  return
TrayReload:
    Reload
  return
TrayEdit:
    Edit
  return
TrayEditConfig:
    Run, %A_ScriptDir%\..\..\SciTE_beta5\SciTE.exe %A_ScriptDir%\WindowPad.ini
    return
TraySuspend:
    WM_COMMAND(65305,0)
    Suspend
    Menu, Tray, % A_IsSuspended ? "Check" : "Uncheck", &Suspend
  return
TrayExit:
  ExitApp


;
; WindowPadMove: move and resize window based on a "pad" concept.
;
WPM(x, y, w, h, T) {
    WindowPadMove(x, y, w, h, T)
}
WindowPadMove(sideX, sideY, widthFactor, heightFactor, winTitle)
{
    if ! hwnd := wp_WinExist(winTitle)
        return

    if sideX =
        sideX = R
    if sideY =
        sideY = R
    if widthFactor is not number
        widthFactor := sideX ? 0.5 : 1.0
    if heightFactor is not number
        heightFactor := sideY ? 0.5 : 1.0
    
    WinGetPos, x, y, w, h
    
    if wp_IsWhereWePutIt(hwnd, x, y, w, h)
    {   ; Check if user wants to restore.
        if SubStr(sideX,1,1) = "R"
        {   ; Restore on X-axis.
            restore_x := wp_GetProp(hwnd,"wpRestoreX")
            restore_w := wp_GetProp(hwnd,"wpRestoreW")
            StringTrimLeft, sideX, sideX, 1
        }
        if SubStr(sideY,1,1) = "R"
        {   ; Restore on Y-axis.
            restore_y := wp_GetProp(hwnd,"wpRestoreY")
            restore_h := wp_GetProp(hwnd,"wpRestoreH")
            StringTrimLeft, sideY, sideY, 1
        }
        if (restore_x != "" || restore_y != "")
        {   ; If already at the "restored" size and position, do the normal thing instead.
            if ((restore_x = x || restore_x = "") && (restore_y = y || restore_y = "")
                && (restore_w = w || restore_w = "") && (restore_h = h || restore_h = ""))
            {
                restore_x =
                restore_y =
                restore_w =
                restore_h =
            }
        }
    }
    else
    {   ; WindowPad didn't put that window here, so save this position before moving.
        wp_SetRestorePos(hwnd, x, y, w, h)
        if SubStr(sideX,1,1) = "R"
            StringTrimLeft, sideX, sideX, 1
        if SubStr(sideY,1,1) = "R"
            StringTrimLeft, sideY, sideY, 1
    }
    
    ; If no direction specified, restore or only switch monitors.
    if (sideX+0 = "" && restore_x = "")
        restore_x := x, restore_w := w
    if (sideY+0 = "" && restore_y = "")
        restore_y := y, restore_h := h
    
    ; Determine which monitor contains the center of the window.
    m := wp_GetMonitorAt(x+w/2, y+h/2)
    
    ; Get work area of active monitor.
    gosub wp_CalcMonitorStats
    ; Calculate possible new position for window.
    gosub wp_CalcNewSizeAndPosition

    ; If the window is already there,
    if (newx "," newy "," neww "," newh) = (x "," y "," w "," h)
    {   ; ..move to the next monitor along instead.
    
        if (sideX or sideY)
        {   ; Move in the direction of sideX or sideY.
            SysGet, monB, Monitor, %m% ; get bounds of entire monitor (vs. work area)
            x := (sideX=0) ? (x+w/2) : (sideX>0 ? monBRight : monBLeft) + sideX
            y := (sideY=0) ? (y+h/2) : (sideY>0 ? monBBottom : monBTop) + sideY
            newm := wp_GetMonitorAt(x, y, m)
        }
        else
        {   ; Move to center (Numpad5)
            newm := m+1
            SysGet, mon, MonitorCount
            if (newm > mon)
                newm := 1
        }
    
        if (newm != m)
        {   m := newm
            ; Move to opposite side of monitor (left of a monitor is another monitor's right edge)
            sideX *= -1
            sideY *= -1
            ; Get new monitor's work area.
            gosub wp_CalcMonitorStats
        }
        else
        {   ; No monitor to move to, alternate size of window instead.
            if sideX
                widthFactor /= 2
            else if sideY
                heightFactor /= 2
            else
                widthFactor *= 1.5
        }
        
        ; Calculate new position for window.
        gosub wp_CalcNewSizeAndPosition
    }

    ; Restore before resizing...
    WinGet, state, MinMax
    if state
        WinRestore

    WinDelay := A_WinDelay
    SetWinDelay, 0
    
    if (is_resizable := wp_IsResizable())
    {
        ; Move and resize.
        WinMove,,, newx, newy, neww, newh
        
        ; Since some windows might be resizable but have restrictions,
        ; check that the window has sized correctly.  If not, adjust.
        WinGetPos, newx, newy, w, h
    }
    if (!is_resizable || (neww != w || newh != h))
    {
        ; If the window is smaller on a given axis, center it within
        ; the space.  Otherwise align to the appropriate side.
        newx := Round(newx + (neww-w)/2 * (1 + (w>neww)*sideX))
        newy := Round(newy + (newh-h)/2 * (1 + (h>newh)*sideY))
        ; Move but (usually) don't resize.
        WinMove,,, newx, newy, w, h
    }
    
    ; Explorer uses WM_EXITSIZEMOVE to detect when a user finishes moving a window
    ; in order to save the position for next time. May also be used by other apps.
    PostMessage, 0x232
    
    SetWinDelay, WinDelay
    
    wp_RememberPos(hwnd)
    return

wp_CalcNewSizeAndPosition:
    ; Calculate desired size.
    neww := restore_w != "" ? restore_w : Round(monWidth * widthFactor)
    newh := restore_h != "" ? restore_h : Round(monHeight * heightFactor)
    ; Fall through to below:
wp_CalcNewPosition:
    ; Calculate desired position.
    newx := restore_x != "" ? restore_x : Round(monLeft + (sideX+1) * (monWidth  - neww)/2) 
    newy := restore_y != "" ? restore_y : Round(monTop  + (sideY+1) * (monHeight - newh)/2)
    return

wp_CalcMonitorStats:
    ; Get work area (excludes taskbar-reserved space.)
    SysGet, mon, MonitorWorkArea, %m%
    monWidth  := monRight - monLeft
    monHeight := monBottom - monTop
    return
}


;
; WindowScreenMove: Move window between screens, preserving relative position and size.
;
WindowScreenMove(md, winTitle)
{
    if !wp_WinExist(winTitle)
        return
    
    SetWinDelay, 0

    WinGet, state, MinMax
    if state
        WinRestore

    WinGetPos, x, y, w, h
    
    ; Determine which monitor contains the center of the window.
    ms := wp_GetMonitorAt(x+w/2, y+h/2)
    
    SysGet, mc, MonitorCount

    ; Determine which monitor to move to.
    if md in ,N,Next
    {
        md := ms+1
        if (md > mc)
            md := 1
    }
    else if md in P,Prev,Previous
    {
        md := ms-1
        if (md < 1)
            md := mc
    }
    
    if (md=ms or (md+0)="" or md<1 or md>mc)
        return
    
    ; Get source and destination work areas (excludes taskbar-reserved space.)
    SysGet, ms, MonitorWorkArea, %ms%
    SysGet, md, MonitorWorkArea, %md%
    msw := msRight - msLeft, msh := msBottom - msTop
    mdw := mdRight - mdLeft, mdh := mdBottom - mdTop
    
    ; Calculate new size.
    if (wp_IsResizable()) {
        w := Round(w*(mdw/msw))
        h := Round(h*(mdh/msh))
    }
    
    ; Move window, using resolution difference to scale co-ordinates.
    WinMove,,, mdLeft + (x-msLeft)*(mdw/msw), mdTop + (y-msTop)*(mdh/msh), w, h

    if state = 1
        WinMaximize
}


;
; MaximizeToggle: Maximize or restore the window.
;
MaximizeToggle(winTitle)
{
    if wp_WinExist(winTitle)
    {
        WinGet, state, MinMax
        if state
            WinRestore
        else
            WinMaximize
    }
}


;
; GatherWindows: "Gather" windows on a specific screen.
;
GatherWindows(md)
{
    global ProcessGatherExcludeList
    
    SetWinDelay, 0
    
    ; List all visible windows.
    WinGet, win, List
    
    ; Copy bounds of all monitors to an array.
    SysGet, mc, MonitorCount
    Loop, %mc%
        SysGet, mon%A_Index%, MonitorWorkArea, %A_Index%
    
    if md = M
    {   ; Special exception for 'M', since the desktop window
        ; spreads across all screens.
        CoordMode, Mouse, Screen
        MouseGetPos, x, y
        md := wp_GetMonitorAt(x, y, 0)
    }
    else if md is not integer
    {   ; Support A, P and WinTitle.
        ; (Gather at screen containing specified window.)
        wp_WinExist(md)
        WinGetPos, x, y, w, h
        md := wp_GetMonitorAt(x+w/2, y+h/2, 0)
    }
    if (md<1 or md>mc)
        return
    
    ; Destination monitor
    mdx := mon%md%Left
    mdy := mon%md%Top
    mdw := mon%md%Right - mdx
    mdh := mon%md%Bottom - mdy
    
    Loop, %win%
    {
        ; If this window matches the GatherExclude group, don't touch it.
        if (WinExist("ahk_group GatherExclude ahk_id " . win%A_Index%))
            continue
        
        ; Set Last Found Window.
        if (!WinExist("ahk_id " . win%A_Index%))
            continue

        WinGet, procname, ProcessName
        ; Check process (program) exclusion list.
        if procname in %ProcessGatherExcludeList%
            continue
        
        WinGetPos, x, y, w, h
        
        ; Determine which monitor this window is on.
        xc := x+w/2, yc := y+h/2
        ms := 0
        Loop, %mc%
            if (xc >= mon%A_Index%Left && xc <= mon%A_Index%Right
                && yc >= mon%A_Index%Top && yc <= mon%A_Index%Bottom)
            {
                ms := A_Index
                break
            }
        ; If already on destination monitor, skip this window.
        if (ms = md)
            continue
        
        WinGet, state, MinMax
        if (state = 1) {
            WinRestore
            WinGetPos, x, y, w, h
        }
    
        if ms
        {
            ; Source monitor
            msx := mon%ms%Left
            msy := mon%ms%Top
            msw := mon%ms%Right - msx
            msh := mon%ms%Bottom - msy
            
            ; If the window is resizable, scale it by the monitors' resolution difference.
            if (wp_IsResizable()) {
                w *= (mdw/msw)
                h *= (mdh/msh)
            }
        
            ; Move window, using resolution difference to scale co-ordinates.
            WinMove,,, mdx + (x-msx)*(mdw/msw), mdy + (y-msy)*(mdh/msh), w, h
        }
        else
        {   ; Window not on any monitor, move it to center.
            WinMove,,, mdx + (mdw-w)/2, mdy + (mdh-h)/2
        }

        if state = 1
            WinMaximize
    }
}


;
; FillVirtualScreen: Expand the window to fill the virtual screen (all monitors).
;
FillVirtualScreen(winTitle)
{
    if hwnd := wp_WinExist(winTitle)
    {
        WinGetPos, x, y, w, h
        if !wp_IsWhereWePutIt(hwnd, x, y, w, h)
            wp_SetRestorePos(hwnd, x, y, w, h)
        ; Get position and size of virtual screen.
        SysGet, x, 76
        SysGet, y, 77
        SysGet, w, 78
        SysGet, h, 79
        ; Resize window to fill all...
        WinMove,,, x, y, w, h
        wp_RememberPos(hwnd)
    }
}

;
; Hotkeys: Activate hotkeys defined in INI section [Hotkeys: %section%].
;
Hotkeys(section, options)
{
    local this_hotkey, section_var, hotkeys, wait_for_keyup, m, m1, pos, k
    static key_regex = "^(?:.* & )?[#!^+&<>*~$]*(.+)"
    
    this_hotkey := A_ThisHotkey
    
    if !section
        goto HC_SendThisHotkeyAndReturn
    
    pos := RegExMatch(options, "i)(?<=\bD)\d*\.?\d*", m)
    if pos
    {
        options := SubStr(options, 1, pos-2) . SubStr(options, pos+StrLen(m))
        if (m+0 = "")
            m := 0.1
        Input, k, L1 T%m%
        if ErrorLevel != Timeout
        {
            gosub HC_SendThisHotkey
            Send %k%
            return
        }
    }
    
    section_var := RegExReplace(section, "[^\w#@$]", "_")
    hotkeys := Hotkeys_%section_var%
    
    if hotkeys =
    {
        ; Load each hotkeys section on first use. Since the ini file may be
        ; edited between enabling and disabling the hotkeys, loading them
        ; each and every time would be hazardous.
        hotkeys := wp_INI_ReadSection(WINDOWPAD_INI_PATH, "Hotkeys: " section)
        if hotkeys =
            goto HC_SendThisHotkeyAndReturn
        
        ; key=command  ->  key::command
        hotkeys := RegExReplace(hotkeys, "m`a)^(.*?)=", "$1::")
        
        Hotkeys_%section_var% := hotkeys
    }
        
    ; If Options were omitted and this is a key-down hotkey,
    ; automatically disable the hotkeys when the key is released.
    if (wait_for_keyup := (options="" && SubStr(this_hotkey,-2) != " up"))
        options = On ; Explicit "on" in case hotkey exists but is disabled.
    
    Hotkey, IfWinNotActive, ahk_group HotkeyExclude
    Hotkey_Params(hotkeys, options)
    
    if (wait_for_keyup)
    {
        if (!RegExMatch(this_hotkey, key_regex, m) || GetKeyState(m1)="") {
            MsgBox, % "Error retrieving primary key of hotkey in Hotkeys().`n"
                    . "`tHotkey: " this_hotkey "`n"
                    . "`tResult: " m1
                    . "`nPlease inform Lexikos. Tip: Press Ctrl+C to copy this message."
            return
        }
        
        KeyWait, %m1%
        
        Hotkey_Params(hotkeys, "Off")

        ; A_ThisHotkey: "The key name of the *most recently executed* hotkey"
        ;if(some other hotkey was executed during KeyWait)
        if (this_hotkey = A_ThisHotkey)
            goto HC_SendThisHotkeyAndReturn
    }
    return

HC_SendThisHotkey:
HC_SendThisHotkeyAndReturn:
    if ! InStr(this_hotkey, "~")
        if (RegExMatch(this_hotkey, key_regex, m) && GetKeyState(m1)!="") {
            Hotkey, %this_hotkey%, Off
            Send {Blind}{%m1%}
            Hotkey, %this_hotkey%, On
        }
    return
}


;
; Commands implemented as labels for simplicity.
;
Send:
    Send, %Params%
    return
Minimize:
    if wp_WinExist(Params)
        PostMessage, 0x112, 0xF020  ; WM_SYSCOMMAND, SC_MINIMIZE
    return
Unminimize:
    if wp_WinLastMinimized()
        WinRestore
    return
Restore:
    if wp_WinExist(Params)
        WinRestore
    return


;
; Internal Functions
;

wp_IsWhereWePutIt(hwnd, x, y, w, h)
{
    if wp_GetProp(hwnd,"wpHasRestorePos")
    {   ; Window has restore info. Check if it is where we last put it.
        last_x := wp_GetProp(hwnd,"wpLastX")
        last_y := wp_GetProp(hwnd,"wpLastY")
        last_w := wp_GetProp(hwnd,"wpLastW")
        last_h := wp_GetProp(hwnd,"wpLastH")
        return (last_x = x && last_y = y && last_w = w && last_h = h)
    }
    return false
}

wp_RememberPos(hwnd)
{
    WinGetPos, x, y, w, h, ahk_id %hwnd%
    ; Remember where we put it, to detect if the user moves it.
    wp_SetProp(hwnd,"wpLastX",x)
    wp_SetProp(hwnd,"wpLastY",y)
    wp_SetProp(hwnd,"wpLastW",w)
    wp_SetProp(hwnd,"wpLastH",h)
}

wp_SetRestorePos(hwnd, x, y, w, h)
{
    ; Next time user requests the window be "restored" use this position and size.
    wp_SetProp(hwnd,"wpHasRestorePos",true)
    wp_SetProp(hwnd,"wpRestoreX",x)
    wp_SetProp(hwnd,"wpRestoreY",y)
    wp_SetProp(hwnd,"wpRestoreW",w)
    wp_SetProp(hwnd,"wpRestoreH",h)
}

; Execute a pseudo-command with params.
wp_ExecLine(cmdline)
{
    if RegExMatch(cmdline, "^\s*(?<Name>\S+?)(?:[, `t]\s*(?<Params>.*?))?\s*$", a)
    {
        global Params := aParams  ; Global for use by label-based pseudo-commands.
        if (n := IsFunc(aName)) && n <= 6
        {   ; %aName% is a function with up to 5 params.
            if n > 2
            {   ; Two or more required parameters.
                if RegExMatch(aParams, "^(?:[^,]*,){1," n-2 "}\s*", aParams)
                    StringSplit, p, aParams, `,, %A_Space%%A_Tab%
                else ; no comma
                    p0 := 1
                p%p0% := SubStr(Params, StrLen(aParams) + 1)
            }
            else
                ; At most one required parameter.
                p1 := Params
            ; Call function with values supplied for only the required params.
            ; This allows commas to be treated literally in the last param.
            return %aName%(p1, p2, p3, p4, p5)
        }
        else
            ; aName is a label or invalid.
            gosub %aName%
    }
}

; Get the index of the monitor containing the specified x and y co-ordinates.
wp_GetMonitorAt(x, y, default=1)
{
    SysGet, m, MonitorCount
    ; Iterate through all monitors.
    Loop, %m%
    {   ; Check if the window is on this monitor.
        SysGet, Mon, Monitor, %A_Index%
        if (x >= MonLeft && x <= MonRight && y >= MonTop && y <= MonBottom)
            return A_Index
    }

    return default
}

; Get/set window property. type should be int, uint or float.
wp_GetProp(hwnd, property_name, type="int") {
    return DllCall("GetProp", "uint", hwnd, "str", property_name, type)
}
wp_SetProp(hwnd, property_name, data, type="int") {
    return DllCall("SetProp", "uint", hwnd, "str", property_name, type, data)
}

; Determine if we should attempt to resize the last found window.
wp_IsResizable()
{
    WinGetClass, Class
    if Class in Chrome_XPFrame,MozillaUIWindowClass
        return true
    WinGet, Style, Style
    return (Style & 0x40000) ; WS_SIZEBOX
}

; Custom WinExist() for implementing a couple extra "special" values.
wp_WinExist(WinTitle)
{
    if WinTitle = P
        return wp_WinPreviouslyActive()
    if WinTitle = M
    {
        MouseGetPos,,, win
        return WinExist("ahk_id " win)
    }
    if WinTitle = _
        return wp_WinLastMinimized()
    return WinExist(WinTitle!="" ? WinTitle : "A")
}

; Get next window beneath the active one in the z-order.
wp_WinPreviouslyActive()
{
    active := WinActive("A")
    WinGet, win, List

    ; Find the active window.
    ; (Might not be win1 if there are always-on-top windows?)
    Loop, %win%
        if (win%A_Index% = active)
        {
            if (A_Index < win)
                N := A_Index+1
            
            ; hack for PSPad: +1 seems to get the document (child!) window, so do +2
            ifWinActive, ahk_class TfPSPad
                N += 1
            
            break
        }

    ; Use WinExist to set Last Found Window (for consistency with WinActive())
    return WinExist("ahk_id " . win%N%)
}

; Get most recently minimized window.
wp_WinLastMinimized()
{
    WinGet, w, List

    Loop %w%
    {
        wi := w%A_Index%
        WinGet, m, MinMax, ahk_id %wi%
        if m = -1 ; minimized
        {
            lastFound := wi
            break
        }
    }

    return WinExist("ahk_id " . (lastFound ? lastFound : 0))
}


; Hotkey_Params( line [, Options ] )
;   Associates a hotkey with a parameter string.
;
; Expects a newline(`n)-delimited list of hotkeys in the form:
;   Hotkey:: LabelName, Params
;
; Note:
;   - Spaces are optional.
;   - As with hotkey labels, there should be no space between 'Hotkey' and '::'.
;   - Unlike the Hotkey command, LabelName MUST NOT be omitted.
;   - Params MUST NOT contain a newline character (`n).
;   - Params may contain zero or more commas.
;   - , (comma) is supported as a hotkey.
;   - Unlike the Hotkey command, 'Toggle' should be specified in the Options, not as a label.
;
; Returns the number of hotkeys successfully enabled/disabled.
;
Hotkey_Params(line, Options="")
{
    static List ; List of hotkeys and associated labels + parameters.
        , sCmdLine ; temp var used by hotkey subroutine.
    
    count = 0
    
    ; Note: The parsing loop operates on a temporary copy of 'line',
    ;       so 'line' can be (and is) reused within the loop.
    
    Loop, Parse, line, `n, %A_Space%%A_Tab%
    {
        ; Clear ErrorLevel in case UseErrorLevel is (not) specified.
        ErrorLevel =

        if ! RegExMatch(A_LoopField, "^\s*(?<Hotkey>.+?)::\s*(?<Name>.+?)(?:[, `t]\s*(?<Params>.*?))?\s*$", line)
            continue
        
        if !(IsLabel(lineName) || IsFunc(lineName))
            continue
        
        if Options = Toggle ; Not supported as an option (must be Label.)
        {
            ; Toggle hotkey.  If it doesn't exist, the next line will enable it.
            Hotkey, %lineHotkey%, Toggle, UseErrorLevel
            ; Ensure the hotkey will execute the correct label.
            Hotkey, %lineHotkey%, hp_ExecuteHotkeyWithParams, UseErrorLevel
        } else
            Hotkey, %lineHotkey%, hp_ExecuteHotkeyWithParams, %Options%
        
        ; Check ErrorLevel in case UseErrorLevel was specified.
        if ErrorLevel
            continue
        
        ; Rebuild line to remove whitespace.
        line := lineHotkey "::" lineName "," lineParams
        
        ; Update an existing hotkey's label + params,
        temp := RegExReplace(List, "m`n)^\Q" lineHotkey "\E::.*$", line, repl, 1)
        if (repl > 0)
            List := temp
        else    ; or add a new hotkey to the list.
            List .= (List ? "`n" : "") . line

        count += 1
    }
    return count

hp_ExecuteHotkeyWithParams:
    if RegExMatch(List, "m`n)^\Q" A_ThisHotkey "\E::\K.*", sCmdLine)
        wp_ExecLine(sCmdLine)
return
}


;
; Tray Icon Override:
;   Provides a way to customize the icons without compiling the script.
;

WM_COMMAND(wParam, lParam)
{
    static IsPaused, IsSuspended
    Critical
    id := wParam & 0xFFFF
    if id in 65305,65404,65306,65403
    {  ; "Suspend Hotkeys" or "Pause Script"
        if id in 65306,65403  ; pause
            IsPaused := ! IsPaused
        else  ; at this point, A_IsSuspended has not yet been toggled.
            IsSuspended := ! A_IsSuspended
        wp_SetTrayIcon(!(IsPaused or IsSuspended))
    }
}

wp_SetTrayIcon(is_enabled)
{
    icon := is_enabled ? "tray.ico" : "disabled.ico"
    icon = %A_ScriptDir%\icons\%icon%

    ; avoid an error message if the icon doesn't exist
    IfExist, %icon%
        Menu, TRAY, Icon, %icon%,, 1
}

; --------------------------------------------------------------------------------------------------------------------------
; Minimizes all Windows on the given Screen
;
; Author: hoppfrosch, 20110126
MinimizeWindowsOnMonitor(md)
{
    SysGet, mc, MonitorCount
    if (md<1 or md>mc)
        return

    ; List all visible windows.
    WinGet, win, List
    Loop, %win%
    {
        this_id := win%A_Index%
        WinGetTitle, this_title, ahk_id %this_id%
        WinGetPos, x, y, w, h, %this_title%
        ; Determine which monitor this window is on.
        xc := x+w/2, yc := y+h/2
        mcurr := wp_GetMonitorAt(xc, yc, 0)
        
        if (mcurr=md) 
        {
            WinMinimize, %this_title%
        }
    }
}

; --------------------------------------------------------------------------------------------------------------------------
; Toogles Always on top for given window
;
; Author: hoppfrosch, 20110125
TopToggle(winTitle) {
    if hwnd := wp_WinExist(winTitle)
    {
        WinSet, AlwaysOnTop, toggle
    }
}


; --------------------------------------------------------------------------------------------------------------------------
; Moves mouse to center of given monitor
;
; Author: hoppfrosch, 20110125
MoveMouseToMonitor(md)
{
    SysGet, mc, MonitorCount
    if (md<1 or md>mc)
        return
    
    Loop, %mc%
        SysGet, mon%A_Index%, MonitorWorkArea, %A_Index%
    
    ; Destination monitor
    mdx := mon%md%Left
    mdy := mon%md%Top
    mdw := mon%md%Right - mdx
    mdh := mon%md%Bottom - mdy
    
    mdxc := mdx+mdw/2, mdyc := mdy+mdh/2
    
    CoordMode, Mouse, Screen
    MouseMove, mdxc, mdyc, 0
    MouseLocator()
}


; --------------------------------------------------------------------------------------------------------------------------
; Clips the mouse to a given area
;
; Author: x79animal (http://www.autohotkey.com/forum/viewtopic.php?p=409537#409537)
wp_ClipCursor( Confine=True, x1=0 , y1=0, x2=1, y2=1 ) 
{
    VarSetCapacity(R,16,0),  NumPut(x1,&R+0),NumPut(y1,&R+4),NumPut(x2,&R+8),NumPut(y2,&R+12)
    Return Confine ? DllCall( "ClipCursor", UInt,&R ) : DllCall( "ClipCursor" )
}

; --------------------------------------------------------------------------------------------------------------------------
; Toogles clipping mouse to current monitor
;
; Author: hoppfrosch, 20110126
ClipCursorToggle()
{
    Static IsLocked
    
    if (IsLocked=True)
    {
        wp_ClipCursor( False )      ; Turn clipping off
        IsLocked:=False
    }
    else 
    {
        CoordMode, Mouse, Screen
        MouseGetPos, xpos, ypos
        md := wp_GetMonitorAt(xpos, ypos, 0)

        SysGet, mc, MonitorCount
        Loop, %mc%
            SysGet, mon%A_Index%, MonitorWorkArea, %A_Index%
    
        ; Destination monitor
        mdx1 := mon%md%Left
        mdy1 := mon%md%Top
        mdx2 := mon%md%Right
        mdy2 := mon%md%Bottom
        
        OutputDebug %xpos% * %ypos% * MD: %md% * %mdx1% * %mdy1% * %mdx2% * %mdy2%
        
        wp_ClipCursor(True,mdx1,mdy1,mdx2,mdy2)
        IsLocked := True
    }
}
        
; --------------------------------------------------------------------------------------------------------------------------
; Restricts mouse to given monitor
;
; Author: hoppfrosch, 20110125
RestrictMouseToMonitor(md)
{
    SysGet, mc, MonitorCount
    if (md<0 or md>mc)
        return
    
    if (md=0) 
    {
        wp_ClipCursor( False,0,0,1,1)      ; Turn clipping off
        return
    }
    
    Loop, %mc%
        SysGet, mon%A_Index%, MonitorWorkArea, %A_Index%
    
    ; Destination monitor
    mdx1 := mon%md%Left
    mdy1 := mon%md%Top
    mdx2 := mon%md%Right
    mdy2 := mon%md%Bottom
    
    wp_ClipCursor(True,mdx1,mdy1,mdx2,mdy2)
}

; --------------------------------------------------------------------------------------------------------------------------
; easy find the mouse
;
; Author: Skrommel (http://www.donationcoder.com/Software/Skrommel/MouseMark/MouseMark.ahk)
; Modified by: hoppfrosch, 20110127
;
MouseLocator()
{
    Global applicationname
    
    SetWinDelay,0 
    DetectHiddenWindows,On
    CoordMode,Mouse,Screen
    
    delay := 100
    size1 := 250
    size2 := 200
    size3 := 150
    size4 := 100
    size5 := 50
    col1 := "Red"
    col2 := "Blue"
    col3 := "Yellow"
    col4 := "Lime"
    col5 := "Green"
    boldness1 := 700
    boldness2 := 600
    boldness3 := 500
    boldness4 := 400
    boldness5 := 300
    
    Transform, OutputVar, Chr, 177
    
    Loop,5
    { 
      MouseGetPos,x,y 
      size:=size%A_Index%
      width:=size%A_Index%*1.4
      height:=size%A_Index%*1.4
      colX:=col%A_Index%
      boldness:=boldness%A_Index%
      Gui,%A_Index%:Destroy
      Gui,%A_Index%:+Owner +AlwaysOnTop -Resize -SysMenu -MinimizeBox -MaximizeBox -Disabled -Caption -Border -ToolWindow 
      Gui,%A_Index%:Margin,0,0 
      Gui,%A_Index%:Color,123456
      
      ;Gui,%A_Index%:Font,C%color% S%size% W%boldness%,Times
      ;Gui,%A_Index%:Add,Text,,*
      Gui,%A_Index%:Font,c%colX% S%size% W%boldness%,Wingdings
      ;Gui,%A_Index%:Font,cBlue S%size% W%boldness%,Wingdings
      Gui,%A_Index%:Add,Text,,%OutputVar%
      ; Gui,%A_Index%:Add,Text,,±
      
      Gui,%A_Index%:Show,X-%width% Y-%height% W%width% H%height% NoActivate,%applicationname%%A_Index%
      WinSet,TransColor,123456,%applicationname%%A_Index%
    }
    Loop,5
    {
        MouseGetPos,x,y 
        WinMove,%applicationname%%A_Index%,,% x-size%A_Index%/1.7,% y-size%A_Index%/1.4
        WinShow,%applicationname%%A_Index%
        Sleep,%delay%
        WinHide,%applicationname%%A_Index%
        ;Sleep,%delay% 
    }

    Loop,5
    { 
        Gui,%A_Index%:Destroy
    }
}
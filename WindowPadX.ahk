/*
Title: _WindowPadX

*Handling windows in general and within a multi-monitor setup in special*
    
derived from *WindowPad* by *Lexikos* (http://www.autohotkey.com/forum/topic21703.html)

See also the documentation of original *WindowPad* by *Lexikos* (http://www.autohotkey.com/forum/topic21703.html), as *WindowPadX* is just a simple clone of *WindowPad* with reengineering and a few enhancements ....

Documentation:
- <Command-line Usage> - Using *WindowPadX* from the commandline
- <Adding Commands> - Implement your own commands
    
Requires:
    AutoHotkey v1.1.0 or later.

Author: 
    hoppfrosch
 
Version History:
    1.2.2 - 22.Mar.2012 Hoppfrosch
        [+] WPXA.ahk v0.2.0: <wp_RollWindowToggle>: Bugfix for rolling up windows to its titlebar
    1.2.1 - 22.Mar.2012 Hoppfrosch
        [+] WPXA.ahk v0.1.10: <wp_GetMonitorFromMouse>: Determine monitor where mouse is
        [*] WPXA.ahk v0.1.10: <WPXA_MinimizeWindowsOnMonitor>: Minimize windows on screen where mouse is
    1.2.0 - 19.Mar.2012 Hoppfrosch
        [+] WPXA.ahk v0.1.9: <WPXA_TileLast2Windows>: Tile active and last window (Credits: ipstone today (http://www.autohotkey.com/forum/viewtopic.php?p=521482#521482))
    1.1.1 - 26.Jan.2012 Hoppfrosch
        [*] WPXA.ahk v0.1.8: <WPXA_MaximizeToggle>: Bugfix to actually toggle Maximization
    1.1.0 - 13.Jan.2012 Hoppfrosch
        [*] WPXA.ahk v0.1.6: <WPXA_TopToggle()>: Reanimated Notifications
        [+] WPXA.ahk v0.1.7: <WPXA_RollToggle>: New action for toggling rolling a window to its captionbar
    1.0.1 - 13.Jan.2012 Hoppfrosch
        [*] WPXA.ahk v0.1.5: <WPXA_MouseLocator>: Using integer coordinates for Gui Show
    1.0.0 - 12.Jan.2012 Hoppfrosch: Initial release of WindowPadX
*/

/*

--------------------------------------------------------------------------------------
Ideensammlung:
* Transparenz für Fenster
* Overlay-Icon in Taskbar, um anzuzeigen auf welchem Screen sich das Fenster befindet ... (Funktion aus ITaskBar von maul.esel). Dies sollte bei verlassen des Programmes auch wieder entfernt werden.
  Hinweise:
  * http://www.autohotkey.com/forum/viewtopic.php?t=74314
  * http://www.autohotkey.com/forum/viewtopic.php?t=70978
* "TaskSwitcher" fuer jeden Monitor
  Hinweise:
  * http://www.autohotkey.com/forum/viewtopic.php?t=71912
-------------------------------------------------------------------------------------- 
*/

#include %A_ScriptDir%/WPXA.ahk

#SingleInstance force

Version := "1.2.2"

; Custom .ini Path
Param1 = %1%
If (InStr(Param1, ".ini")) 
{
    WINDOWPADX_INI_PATH := Param1
    gosub WindowPadXInit
    return
}

if 0 > 0
{
    ; Command-line mode: interpret each arg as a pseudo-command.
    ; Suspend all hotkeys which may be created by WindowPadXInit.
    Suspend On
    ; Load options and Gather exclusions.
    gosub WindowPadXInit
    ; Execute command line(s).  Each args should be in one of these formats:
    ;   <command>
    ;   <command>,<args_no_spaces>
    ;   "<command>, <args>"    ; In this case the initial comma is optional.
    Loop %0%
        wp_ExecLine(%A_Index%)
    ExitApp
}

OnExit, TrayExit

; Load options and Gather exclusions.
WindowPadXInit:
    ; If this script is #included in another script, this section may not be
    ; auto-executed.  In that case, the following should be called manually:
    WindowPadX_Init(WINDOWPADX_INI_PATH)
  return

WindowPadX_Init(IniPath="")
{
    global WINDOWPADX_INI_PATH
    ;
    ; Init icons and tray menu.
    ;
    wp_SetupTray()
   
    ;
    ; Load settings.
    ;
    if IniPath =
        Loop, %A_LineFile%\..\WindowPadX.ini
            IniPath := A_LoopFileFullPath
    ifNotExist %IniPath%
    {
        IniPath = %A_ScriptDir%\WindowPadX.ini
        FileInstall, WindowPadX.Default.ini, %IniPath%
    }
    WINDOWPADX_INI_PATH := IniPath
    WindowPadX_LoadSettings(IniPath)
}

WindowPadX_LoadSettings(ininame)
{
    local v
    
    ; Misc Options
    IniRead, v, %ininame%, Options, TitleMatchMode, %A_TitleMatchMode%
    SetTitleMatchMode, %v%
    ; allow generic options
    IniRead, opts, %ininame%, Options
    Loop, Parse, opts, `n, `r
    {
        StringSplit v, A_LoopField, =
        %v1% := v2
    }
    
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


; Tray menu subroutines. May also be assigned to hotkeys in WindowPadX.ini.
TrayDebug:
    ListHotkeys
  return
TrayHelp:
    Run, %A_ScriptDir%\WindowPadX.html
  return
TrayReload:
    Reload
  return
TrayEdit:
    Edit
  return
TrayEditConfig:
    RegRead, Editor, HKCR, AutoHotkeyScript\Shell\Edit\Command
    StringReplace, Editor, Editor, "`%1",
    Editor := RegExReplace(Editor, "(^\s*|\s*$)")
    if (Editor = )
        Editor = notepad
    Run, %Editor% "%A_ScriptDir%\WindowPadX.ini"
    return
TraySuspend:
    WM_COMMAND(65305,0)
    Suspend
    Menu, Tray, % A_IsSuspended ? "Check" : "Uncheck", &Suspend
  return
TrayExit:


    wp_Restore()
    ExitApp



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
        hotkeys := wp_INI_ReadSection(WINDOWPADX_INI_PATH, "Hotkeys: " section)
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
; Tray Menu
;
;

wp_SetupTray() 
{
    if A_IsCompiled  ; Load icons from my custom WindowPadX.exe.
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
    ifExist, %A_ScriptDir%\WindowPadX.html
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

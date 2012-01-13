/*!
	Library: WindowPadX-Actions library, version 0.1.5
		Implementation of different useful actions for handling windows in general and within a multi-monitor setup in special. Functions starting with the prefix ***wp*** are internal helper functions: Functions starting with the prefix ***WPXA*** are designed to be used as actions within WindowPadX.
        
	Author: Hoppfrosch
	License: WTFPL (http://sam.zoy.org/wtfpl/)
	Extra:
		### Credits
		Lexikos - for his great work and his Original "WindowPad - multi-monitor window-moving tool" (http://www.autohotkey.com/forum/topic21703.html)
		ShinyWong - for his "GetMonitorIndexFromWindow" function (http://www.autohotkey.com/forum/viewtopic.php?p=462080#462080)
		Skrommel - for his "MouseMark" function (http://www.donationcoder.com/Software/Skrommel/MouseMark/MouseMark.ahk)
		x97animal - for his "clipCursor" Function (http://www.autohotkey.com/forum/viewtopic.php?p=409537#409537)
		
		### Changes
		0.1.5 - [-] WPAX_MouseLocator(): Using integer coordinates for Gui Show
*/

; ****** HINT: Documentation can be extracted to HTML using GenDocs 3.0 (http://http://www.autohotkey.com/forum/viewtopic.php?t=76949) ************** */

/*!
===============================================================================
    Function:   WPXA_version()
        Returns the current version of WPXA

    Returns:
        current version number of the module

	Extra:
		### Author
		20110713 - hoppfrosch - Original
===============================================================================
*/
WPXA_version()
{
    return "0.1.5"
}

/*!
===============================================================================
    Function:   wp_ClipCursor([Confine, x1, y1, x2, y2])
        Clips (restricts/confines) the mouse to a given area

    Parameters:
        Confine - (***Optional***) Toogle for Clipping (Default: true)
        x1,y1,x2,y2 - (***Optional***) Bounding coordinates (upper left, lower right) of confined area (Default: 0,0,1,1)
  
    Returns:
        If the function succeeds, the return value is nonzero.
        If the function fails, the return value is zero. To get extended error information, call GetLastError. 
    
    Extra:
		### Author
        Original - [x79animal](http://www.autohotkey.com/forum/viewtopic.php?p=409537#409537)
        20110127 - hoppfrosch - Modifications
===============================================================================
*/
wp_ClipCursor( Confine=True, x1=0 , y1=0, x2=1, y2=1 ) 
{
    VarSetCapacity(R,16,0),  NumPut(x1,&R+0),NumPut(y1,&R+4),NumPut(x2,&R+8),NumPut(y2,&R+12)
    Return Confine ? DllCall( "ClipCursor", UInt,&R ) : DllCall( "ClipCursor" )
}

/*!
===============================================================================
    Function:   wp_GetMonitorAt(x, y, [default])
        Get the index of the monitor containing the specified x and y coordinates.

    Parameters:
        x,y - Coordinates
        default - (***Optional***) Default monitor (Default: 1)
  
    Returns:
        Index of the monitor at specified coordinates

    Extra:
		### Author
        Original - [Lexikos](http://www.autohotkey.com/forum/topic21703.html)
===============================================================================
*/
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

/*!
===============================================================================
    Function:   wp_GetMonitorFromWindow(windowHandle)
        Get the index of the monitor containing the specified window.

    Parameters:
        windowHandle - Window handle
  
    Returns:
        Index of the monitor of specified window


    Extra:
		### Author
        Original - [ShinyWong](http://www.autohotkey.com/forum/viewtopic.php?p=462080#462080)
===============================================================================
*/
wp_GetMonitorFromWindow(windowHandle)
{
   ; Starts with 1.
   monitorIndex := 1

   VarSetCapacity(monitorInfo, 40)
   NumPut(40, monitorInfo)
   
   if (monitorHandle := DllCall("MonitorFromWindow", "uint", windowHandle, "uint", 0x2))
      && DllCall("GetMonitorInfo", "uint", monitorHandle, "uint", &monitorInfo)
   {
      monitorLeft   := NumGet(monitorInfo,  4, "Int")
      monitorTop    := NumGet(monitorInfo,  8, "Int")
      monitorRight  := NumGet(monitorInfo, 12, "Int")
      monitorBottom := NumGet(monitorInfo, 16, "Int")
      workLeft      := NumGet(monitorInfo, 20, "Int")
      workTop       := NumGet(monitorInfo, 24, "Int")
      workRight     := NumGet(monitorInfo, 28, "Int")
      workBottom    := NumGet(monitorInfo, 32, "Int")
      isPrimary     := NumGet(monitorInfo, 36, "Int") & 1

      SysGet, monitorCount, MonitorCount

      Loop, %monitorCount%
      {
         SysGet, tempMon, Monitor, %A_Index%

         ; Compare location to determine the monitor index.
         if ((monitorLeft = tempMonLeft) and (monitorTop = tempMonTop)
            and (monitorRight = tempMonRight) and (monitorBottom = tempMonBottom))
         {
            monitorIndex := A_Index
            break
         }
      }
   }
   
   return %monitorIndex%
}


/*!
===============================================================================
    Function:   wp_GetProp(hwnd, property_name [,type])
        Get window property.
  
    Parameters:
        hwnd - Window handle
        property_name - Name of the property
        type - (***Optional***) Type of the  property - should be int, uint or float. (Default: int)

    Returns:
        Value of the property, otherwise NULL if property does not exist
  
    Remarks: 
    See also:  <wp_SetProp>, <wp_RemoveProp>

    Extra:
		### Author
        Original - [Lexikos](http://www.autohotkey.com/forum/topic21703.html)
        [Reference](http://msdn.microsoft.com/en-us/library/ms633564%28v=vs.85%29.aspx)
===============================================================================
*/
wp_GetProp(hwnd, property_name, type="int") {
    return DllCall("GetProp", "uint", hwnd, "str", property_name, type)
}

/*!
===============================================================================
    Function:   wp_IsAlwaysOnTop(WinTitle [,IsSetByWP])
        Determine whether fiven window is set to always on top

    Parameters:
        WinTitle - Title of the window
        IsSetByWP - (***Optional***) Checks whether "AlwaysOnTop" was set with WindowPad (needed to restore state ...) (Default: 0)
  
    Returns:
        True or False

    Extra:
		### Author
        20110811 - hoppfrosch - Initial
===============================================================================
*/
wp_IsAlwaysOnTop(WinTitle,IsSetByWP=0)
{
    WinGet, CurrExStyle, ExStyle, %WinTitle%
    
    if hwnd := wp_WinExist(WinTitle) {
        if (IsSetByWP=1) 
        {
            if wp_GetProp(hwnd,"wpAlwaysOnTop") 
            {
                return (CurrExStyle & 0x08) ; WS_EX_TOPMOST
            }
            else
            {
                return 0
            }
        }
        return (CurrExStyle & 0x08) ; WS_EX_TOPMOST
    }
    
    return
}

/*!
===============================================================================
    Function:   wp_IsResizable()
        Determine if we should attempt to resize the last found window.

    Returns:
        True or False
     
    Extra:
		### Author
        Original - [Lexikos](http://www.autohotkey.com/forum/topic21703.html)
===============================================================================
*/
wp_IsResizable()
{
    WinGetClass, Class
    if Class in Chrome_XPFrame,MozillaUIWindowClass
        return true
    WinGet, CurrStyle, Style
    return (CurrStyle & 0x40000) ; WS_SIZEBOX
}

/*!
===============================================================================
    Function:   wp_IsWhereWePutIt(hwnd, x, y, w, h)
        Restores windows position and size previously stored with <wp_RememberPos>
  
    Parameters:
        hwnd - Window handle
        
    Returns:
        x,y,w,h -  last position and size. - or false
   
    Extra:
        ### Author
        Original - Lexikos - http://www.autohotkey.com/forum/topic21703.html
===============================================================================
*/
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

/*
===============================================================================
Function:   wp_RememberPos
  Helper function for detection of window movement by user. Stores the current position. The stored position can be recovered by <wp_IsWhereWePutIt>
  
Parameters:
  hwnd - Window handle
  
See also:
  <wp_SetProp>, <wp_IsWhereWePutIt>
  
Classification: 
  Helper function

Author(s):
  Original - Lexikos - http://www.autohotkey.com/forum/topic21703.html
===============================================================================
*/
wp_RememberPos(hwnd)
{
    WinGetPos, x, y, w, h, ahk_id %hwnd%
    ; Remember where we put it, to detect if the user moves it.
    wp_SetProp(hwnd,"wpLastX",x)
    wp_SetProp(hwnd,"wpLastY",y)
    wp_SetProp(hwnd,"wpLastW",w)
    wp_SetProp(hwnd,"wpLastH",h)
}

/*
===============================================================================
Function:   wp_RemoveProp
  Remove window property.
  
Parameters:
  hwnd - Window handle
  property_name - Name of the property

Return Values:
  Handle - The return value identifies the specified data. If the data cannot be found in the specified property list, the return value is NULL.
  
See also:
  <wp_GetProp>, <wp_SetProp>
  
Classification: 
  Helper function

Author(s):
  Original - MSDN (http://msdn.microsoft.com/en-us/library/ms633567%28v=vs.85%29.aspx)
  20110713 - Hoppfrosch - AutoHotkey-Implementation
===============================================================================
*/
wp_RemoveProp(hwnd, property_name) {
    return DllCall("RemoveProp", "uint", hwnd, "str", property_name)
}

/*
===============================================================================
Function:   wp_Restore
  Restores windows to state according properties
  
  Following states are restored:
  * AlwaysOnTop
    
Classification: 
  Helper function

Author(s):
  20110713 - Hoppfrosch - AutoHotkey-Implementation
===============================================================================
*/
wp_Restore() {
    ;MsgBox % "wp_Restore(): Vollstaendige Implementierung"
    
    _DBG_FName = "[wp_Restore] - "
    WinGet, id, list, , , Program Manager
    Loop, %id%
    {
        ; Aktionen rückhängig ...
        hwnd := id%A_Index%
        ; WinActivate, ahk_id %hwnd%
        WinGetClass, WinClass, ahk_id %hwnd%
        WinGetTitle, WinTitle, ahk_id %hwnd%
        OutputDebug % _DBG_FName "Besuche Fenster <" a_index "/" id ">: ahk_id: " hwnd " - win_class: " WinClass " - win_title: " WinTitle
        
        if wp_GetProp(hwnd,"wpAlwaysOnTop") {
            OutputDebug % _DBG_FName "Window <" WinTitle "> has property always on top!"
            if wp_IsAlwaysOnTop(WinTitle,1) {
                OutputDebug % _DBG_FName "Disable AlwaysOnTop since it was set by WindowPad"
                WPXA_TopToggle(WinTitle)
                OutputDebug % _DBG_FName "Current State of AlwaysOnTop: " wp_IsAlwaysOnTop(WinTitle)
            }
        }
        
    }
}
/*
===============================================================================
Function:   wp_SetProp
  Set window property.
  
Parameters:
  hwnd - Window handle
  property_name - Name of the property
  data - Value of the property
  type - Type of the  property - should be int, uint or float.

Return Values:
  True or False
  
See also:
  <wp_GetProp>, <wp_RemoveProp>
  
Classification: 
  Helper function

Author(s):
  Original - Lexikos - http://www.autohotkey.com/forum/topic21703.html
===============================================================================
*/
wp_SetProp(hwnd, property_name, data, type="int") {
    return DllCall("SetProp", "uint", hwnd, "str", property_name, type, data)
}

/*
===============================================================================
Function:   wp_SetRestorePos
  Stores windows position for restoring it later
  
Parameters:
  hwnd - Window handle
  x,y,w,h -  Next time user requests the window be "restored" use this position and size.
  
See also:
  <wp_SetProp>
  
Classification: 
  Helper function

Author(s):
  Original - Lexikos - http://www.autohotkey.com/forum/topic21703.html
===============================================================================
*/
wp_SetRestorePos(hwnd, x, y, w, h)
{
    ; Next time user requests the window be "restored" use this position and size.
    wp_SetProp(hwnd,"wpHasRestorePos",true)
    wp_SetProp(hwnd,"wpRestoreX",x)
    wp_SetProp(hwnd,"wpRestoreY",y)
    wp_SetProp(hwnd,"wpRestoreW",w)
    wp_SetProp(hwnd,"wpRestoreH",h)
}

/*
===============================================================================
Function:   wp_WinExist
  Custom WinExist() for implementing a couple extra "special" values.
  
Parameters:
  WinTitle - Title of the window

Return Values:
  Windowshandle
   
Classification: 
  Helper function

Author(s):
  Original - Lexikos - http://www.autohotkey.com/forum/topic21703.html
===============================================================================
*/
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

/*
===============================================================================
Function:   wp_WinGetTitle
  Custom WinGetTitle() for getting either title of "last found" window or window given by title
  
Parameters:
  WinTitle - Title of the window

Return Values:
  WinTitle - Title of the window
   
Classification: 
  Helper function

Author(s):
  Original - hoppfrosch - 20110607
===============================================================================
*/
wp_WinGetTitle(WinTitle)
{
    if WinTitle = 
        WinGetTitle, CurrWinTitle,
    else
        WinGetTitle, CurrWinTitle,WinTitle
    
    return CurrWinTitle
}

/*
===============================================================================
Function:   wp_WinLastMinimized
  Get most recently minimized window.
  
Return Values:
  True or false

Classification: 
  Helper function

Author(s):
  Original - Lexikos - http://www.autohotkey.com/forum/topic21703.html
===============================================================================
*/
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

/*
===============================================================================
Function:   wp_WinPreviouslyActive
  Get next window beneath the active one in the z-order.
  
Return Values:
  Windowshandle
   
Classification: 
  Helper function

Author(s):
  Original - Lexikos - http://www.autohotkey.com/forum/topic21703.html
===============================================================================
*/
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

/*
===============================================================================
Function:   WPXA_ClipCursorToMonitor
  Clips (Restricts) mouse to given monitor

Parameters:
  md - monitor-id
  
Classification: 
  WindowPadX-Action

Author(s):
  20110126 - hoppfrosch - Initial
===============================================================================
*/
WPXA_ClipCursorToMonitor(md)
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

/*
===============================================================================
Function:   WPXA_ClipCursorToCurrentMonitorToggle
  Toogles clipping mouse to current monitor

Parameters:
  None 
  
Classification: 
  WindowPadX-Action

Author(s):
  20110126 - hoppfrosch - Initial
===============================================================================
*/
WPXA_ClipCursorToCurrentMonitorToggle()
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
        
        wp_ClipCursor(True,mdx1,mdy1,mdx2,mdy2)
        IsLocked := True
    }
}


/*
===============================================================================
Function:   WPXA_FillVirtualScreen
  Expand the window to fill the virtual screen (all monitors).

Parameters:
  winTitle - windows title
  
Classification: 
  WindowPadX-Action

Author(s):
  Original - Lexikos - http://www.autohotkey.com/forum/topic21703.html
===============================================================================
*/
WPXA_FillVirtualScreen(winTitle)
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

/*
===============================================================================
Function:   WPXA_GatherWindowsOnMonitor
  "Gather" windows on a specific screen.

Parameters:
  md - monitor id
  
Classification: 
  WindowPadX-Action

Author(s):
  Original - Lexikos - http://www.autohotkey.com/forum/topic21703.html
===============================================================================
*/
WPXA_GatherWindowsOnMonitor(md)
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

/*
===============================================================================
Function:   WPXA_MaximizeToggle
  Maximize or restore the window.

Parameters:
  winTitle - windows title
  
Classification: 
  WindowPadX-Action

Author(s):
  Original - Lexikos - http://www.autohotkey.com/forum/topic21703.html
===============================================================================
*/
WPXA_MaximizeToggle(winTitle)
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

/*
===============================================================================
Function:   WPXA_MinimizeWindowsOnMonitor
  Minimize all windows on the given Screen

Parameters:
  md - monitor-id
  
Classification: 
  WindowPadX-Action
  
Author(s):
  20110125 - hoppfrosch - Initial
===============================================================================
*/
WPXA_MinimizeWindowsOnMonitor(md)
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

/*
===============================================================================
Function:   WPXA_Move
  move and resize window based on a "pad" concept.

Parameters:
  sideX, sideY, widthFactor, heightFactor - **TODO**
  winTitle - windows title
  
Classification: 
  WindowPadX-Action

Author(s):
  Original - Lexikos - http://www.autohotkey.com/forum/topic21703.html
===============================================================================
*/
WPXA_Move(sideX, sideY, widthFactor, heightFactor, winTitle)
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

/*
===============================================================================
Function:   WPXA_MoveMouseToMonitor
  Moves mouse to center of given monitor

Parameters:
  md - monitor-id
  
Classification: 
  WindowPadX-Action

Author(s):
  20110125 - hoppfrosch - Initial
===============================================================================
*/
WPXA_MoveMouseToMonitor(md)
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
    WPXA_MouseLocator()
}


/*
===============================================================================
Function:   WPXA_MoveWindowToMonitor
  Move window between screens, preserving relative position and size.

Parameters:
  md - Monitor id
  winTitle - windows title
  
Classification: 
  WindowPadX-Action

Author(s):
  Original - Lexikos - http://www.autohotkey.com/forum/topic21703.html
===============================================================================
*/
WPXA_MoveWindowToMonitor(md, winTitle)
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

/*
===============================================================================
Function:   WPXA_MouseLocator
  Easy find the mouse

Requirements:
  Windings-Font 
  
Classification: 
  General Tool

Author(s):
 Original - Skrommel - http://www.donationcoder.com/Software/Skrommel/MouseMark/MouseMark.ahk
 20110127 - hoppfrosch - Modifications
===============================================================================
*/
WPXA_MouseLocator()
{
    applicationname := A_ScriptName
    
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
      width:=Round(size%A_Index%*1.4)
      height:=Round(size%A_Index%*1.4)
      colX:=col%A_Index%
      boldness:=boldness%A_Index%
      Gui,%A_Index%:Destroy
      Gui,%A_Index%:+Owner +AlwaysOnTop -Resize -SysMenu -MinimizeBox -MaximizeBox -Disabled -Caption -Border -ToolWindow 
      Gui,%A_Index%:Margin,0,0 
      Gui,%A_Index%:Color,123456
      
      Gui,%A_Index%:Font,c%colX% S%size% W%boldness%,Wingdings
      Gui,%A_Index%:Add,Text,,%OutputVar%
      
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

WPXA_ShadeToggle(WinTitle)
{
    applicationname := A_ScriptName
    
    if hwnd := wp_WinExist(WinTitle)
    {
    }
    
/*
    WinGet, ws_ID, ID, A
    Loop, Parse, ws_IDList, |
    {
       IfEqual, A_LoopField, %ws_ID%
       {
          ; Match found, so this window should be restored (unrolled):
          StringTrimRight, ws_Height, ws_Window%ws_ID%, 0
            if ws_Animate = 1
            {
                ws_RollHeight = %ws_MinHeight%
                Loop
                {
                    If ws_RollHeight >= %ws_Height%
                        Break
                    ws_RollHeight += %ws_RollUpSmoothness%
                    WinMove, ahk_id %ws_ID%,,,,, %ws_RollHeight%
                }
            }
           WinMove, ahk_id %ws_ID%,,,,, %ws_Height%
          StringReplace, ws_IDList, ws_IDList, |%ws_ID%
          return
       }
    }
    WinGetPos,,,, ws_Height, A
    ws_Window%ws_ID% = %ws_Height%
    ws_IDList = %ws_IDList%|%ws_ID%
    ws_RollHeight = %ws_Height%
    if ws_Animate = 1
    {
        Loop
        {
            If ws_RollHeight <= %ws_MinHeight%
                Break
            ws_RollHeight -= %ws_RollUpSmoothness%
            WinMove, ahk_id %ws_ID%,,,,, %ws_RollHeight%
        }
    }
    WinMove, ahk_id %ws_ID%,,,,, %ws_MinHeight%
    return
*/
    return
}

/*
===============================================================================
Function:   WPXA_TopToggle
  Toogles "Always On Top" for given window

Parameters:
  WinTitle - Title of the window
  ShowNotification - Flag to disable balloon-notification
  
Classification: 
  WindowPadX-Action

Author(s):
  20110811 - hoppfrosch - Initial
===============================================================================
*/
WPXA_TopToggle(WinTitle,ShowNotification=1) {
    
    applicationname := A_ScriptName
    
    if hwnd := wp_WinExist(WinTitle)
    {
        WinSet, AlwaysOnTop, toggle

        CurrWinTitle := wp_WinGetTitle(WinTitle)
        if (wp_IsAlwaysOnTop(WinTitle))
        {
            if ShowNotification=1 
            {
                Notify(applicationname,CurrWinTitle "`nAlways on top enabled - " hwnd,2,,"icons/plus.png")
            }
            wp_SetProp(hwnd,"wpAlwaysOnTop",1)
        }
        else
        {
            if ShowNotification=1 
            {
                Notify(applicationname,CurrWinTitle "`nAlways on top disabled - " hwnd,2,,"icons/minus.png")
            }
            wp_RemoveProp(hwnd,"wpAlwaysOnTop")
        }
    }
}



#include %A_ScriptDir%\_inc\Notify.ahk

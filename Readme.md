WindowPadX
==========

Detailed Documentation can be found here: http://hoppfrosch.github.com/WindowPadX/files/WindowPadX-ahk.html

Introduction
------------

***WindowPadX*** is an enhancement of ***WindowPad***, originally released by Lexikos (see: http://http://www.autohotkey.com/forum/viewtopic.php?t=21703)

***WindowPadX*** is a tool which provides some useful functionality within multi monitor environments.

Features
--------
- Possible actions to be configured on hotkeys
    - Window actions
      - Multi-Monitor
          - WPXA_MoveWindowToMonitor: Move window between screens, preserving relative position and size.
          - WPXA_MinimizeWindowsOnMonitor: Minimize all windows on the given Screen
          - WPXA_GatherWindowsOnMonitor: "Gather" windows on a specific screen.
          - WPXA_FillVirtualScreen: Expand the window to fill the virtual screen (all monitors).
      - General
          - WPXA_MaximizeToggle: Maximize or restore the window.
          - WPXA_TopToggle: Toogles "AlwaysOnTop" for given window
          - WPXA_RollToggle: Toggles "Roll/Unroll" for given window
          - WPXA_Move: move and resize window based on a "pad" concept.
          - WPXA_TileLast2Windows: Tile active and last window
    - Mouse actions
      - Multi-Monitor
          - WPXA_MoveMouseToMonitor: Moves mouse to center of given monitor
          - WPXA_ClipCursorToCurrentMonitorToggle: Toogles clipping mouse to current monitor
          - WPXA_ClipCursorToMonitor: Clips (Restricts) mouse to given monitor
      - General
          - WPXA_MouseLocator: Easy find the mouse 

For more details see http://hoppfrosch.github.com/WindowPadX/files/WindowPadX-ahk.html
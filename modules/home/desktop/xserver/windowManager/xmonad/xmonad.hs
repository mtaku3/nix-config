import Data.Bits ((.|.))
import Data.Default.Class
import qualified Data.Map as M
import Data.Monoid
import System.Exit (exitSuccess)
import XMonad
import XMonad.Actions.CopyWindow (kill1)
import qualified XMonad.Actions.FlexibleResize as Flex
import XMonad.Hooks.EwmhDesktops (ewmh)
import XMonad.Hooks.InsertPosition
import XMonad.Hooks.ManageDocks (avoidStruts, docks)
import XMonad.Hooks.StatusBar
import XMonad.Hooks.StatusBar.PP
import XMonad.Layout
import XMonad.Layout.LayoutModifier
import XMonad.Layout.LimitWindows (limitWindows)
import XMonad.Layout.NoBorders
import XMonad.Layout.Renamed (Rename (Replace), renamed)
import XMonad.Layout.ResizableTile (ResizableTall (..))
import XMonad.Layout.SimplestFloat (simplestFloat)
import XMonad.Layout.Spacing
import XMonad.Layout.ToggleLayouts (ToggleLayout (Toggle), toggleLayouts)
import XMonad.Layout.WindowArranger (WindowArrangerMsg (Arrange, DeArrange), windowArrange)
import XMonad.ManageHook
import XMonad.Operations
import qualified XMonad.StackSet as W
import XMonad.Util.SpawnOnce

-- Variables
myTerminal :: String
myTerminal = "kitty"

-- Logging
myLogHook :: X ()
myLogHook = return ()

-- Event handling
myStartupHook :: X ()
myStartupHook = do
  spawnOnce "feh --bg-scale @wallpaper@"
  spawnOnce "picom &"
  spawnOnce "trayer --edge top --align right --width 5 --padding 6 --SetDockType true --SetPartialStrut true --expand true --alpha 0 --tint 0x282727 --height 18 &"
  spawnOnce "nm-applet &"

myHandleEventHook :: Event -> X All
myHandleEventHook _ = return (All True)

-- Event masks
myClientMask :: EventMask
myClientMask = structureNotifyMask .|. enterWindowMask .|. propertyChangeMask

myRootMask :: EventMask
myRootMask =
  substructureRedirectMask
    .|. substructureNotifyMask
    .|. enterWindowMask
    .|. leaveWindowMask
    .|. structureNotifyMask
    .|. buttonPressMask

-- Window rules
myManageHook :: ManageHook
myManageHook =
  composeAll
    [insertPosition Below Older]

-- Layouts
myBorderWidth :: Dimension
myBorderWidth = 1

myNormalBorderColor :: String
myNormalBorderColor = "gray"

myFocusedBorderColor :: String
myFocusedBorderColor = "red"

tall =
  renamed [Replace "tall"] $
    limitWindows 2 $
      avoidStruts $
        withBorder 1 $
          spacingRaw False (Border 25 25 50 50) True (Border 10 10 29 29) True $
            ResizableTall 1 (1 / 176) (1 / 2) []

full =
  renamed [Replace "fullscreen"] $
    noBorders $
      Full

myLayoutHook =
  toggleLayouts full $
    tall

-- Key bindings
myWorkspaces :: [WorkspaceId]
myWorkspaces = map show [1 .. 10 :: Int]

myModMask :: KeyMask
myModMask = mod4Mask

myKeys :: XConfig Layout -> M.Map (KeyMask, KeySym) (X ())
myKeys conf@(XConfig {modMask = modMask}) =
  M.fromList $
    [ ((modMask .|. shiftMask, xK_e), io exitSuccess),
      ((modMask, xK_Return), spawn $ terminal conf),
      ((modMask .|. shiftMask, xK_q), kill1),
      ((modMask, xK_f), sendMessage $ Toggle "fullscreen"),
      ((modMask, xK_space), withFocused $ \w -> ifM (isFloat w) ((windows . W.sink) w) (float w)),
      ((modMask, xK_j), windows W.focusDown),
      ((modMask, xK_k), windows W.focusUp),
      ((modMask .|. shiftMask, xK_j), windows W.swapDown),
      ((modMask .|. shiftMask, xK_k), windows W.swapUp),
      ((modMask .|. shiftMask, xK_h), sendMessage Shrink),
      ((modMask .|. shiftMask, xK_l), sendMessage Expand)
    ]
      ++ [ ((m .|. modMask, k), windows $ f i)
           | (i, k) <- zip (workspaces conf) ([xK_1 .. xK_9] ++ [xK_0]),
             (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]
         ]

-- Mouse bindings
myFocusFollowsMouse :: Bool
myFocusFollowsMouse = True

myClickJustFocuses :: Bool
myClickJustFocuses = False

myMouseBindings :: XConfig Layout -> M.Map (KeyMask, Button) (Window -> X ())
myMouseBindings conf@(XConfig {modMask = modMask}) =
  M.fromList $
    [ ((modMask, button1), \w -> whenX (isFloat w) (focus w >> mouseMoveWindow w >> windows W.shiftMaster)),
      ((modMask, button2), (\w -> focus w >> Flex.mouseResizeWindow w))
    ]

-- Utils
isFloat :: Window -> X Bool
isFloat w = gets (M.member w . W.floating . windowset)

spawnSB :: ScreenId -> IO StatusBarConfig
spawnSB 0 =
  pure $
    statusBarProp
      "xmobar"
      ( pure
          def
            { ppCurrent = wrap "[" "]",
              ppVisible = id,
              ppHidden = id,
              ppSep = "",
              ppWsSep = " ",
              ppTitle = const "",
              ppTitleSanitize = const "",
              ppLayout = const ""
            }
      )

main = do
  xmonad . ewmh . dynamicSBs spawnSB . docks $
    XConfig
      { borderWidth = myBorderWidth,
        workspaces = myWorkspaces,
        normalBorderColor = myNormalBorderColor,
        focusedBorderColor = myFocusedBorderColor,
        logHook = myLogHook,
        startupHook = myStartupHook,
        manageHook = myManageHook,
        handleEventHook = myHandleEventHook,
        focusFollowsMouse = myFocusFollowsMouse,
        clickJustFocuses = myClickJustFocuses,
        clientMask = myClientMask,
        rootMask = myRootMask,
        handleExtraArgs = \xs conf -> case xs of
          [] -> return conf
          _ -> fail ("unrecognized flags:" ++ show xs),
        extensibleConf = M.empty,
        terminal = myTerminal,
        modMask = myModMask,
        layoutHook = myLayoutHook,
        keys = myKeys,
        mouseBindings = myMouseBindings
      }

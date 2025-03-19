import Data.Bits ((.|.))
import Data.Default.Class
import qualified Data.Map as M
import Data.Monoid
import Graphics.X11.ExtraTypes.XF86
import System.Exit (exitSuccess)
import XMonad
import XMonad.Actions.CopyWindow (kill1)
import qualified XMonad.Actions.FlexibleResize as Flex
import XMonad.Actions.UpdatePointer
import XMonad.Hooks.InsertPosition
import XMonad.Hooks.ManageDocks (avoidStruts, docks)
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.StatusBar
import XMonad.Hooks.StatusBar.PP
import XMonad.Layout
import XMonad.Layout.LayoutModifier
import XMonad.Layout.LimitWindows (limitWindows)
import XMonad.Layout.NoBorders
import XMonad.Layout.PerWorkspace
import XMonad.Layout.Renamed (Rename (Replace), renamed)
import XMonad.Layout.ResizableTile (ResizableTall (..))
import XMonad.Layout.SimplestFloat (simplestFloat)
import XMonad.Layout.Spacing
import qualified XMonad.Layout.Tabbed as Tabbed
import XMonad.Layout.ToggleLayouts (ToggleLayout (Toggle), toggleLayouts)
import XMonad.Layout.WindowArranger (WindowArrangerMsg (Arrange, DeArrange), windowArrange)
import XMonad.ManageHook
import XMonad.Operations
import qualified XMonad.StackSet as W
import XMonad.Util.SpawnOnce

-- Variables
myTerminal :: String
myTerminal = "kitty"

myLauncher :: String
myLauncher = "rofi -show drun"

myBrowser :: String
myBrowser = "vivaldi"

-- Logging
myLogHook :: X ()
myLogHook = updatePointer (0.5, 0.5) (0, 0)

-- Event handling
myStartupHook :: X ()
myStartupHook = do
  spawnOnce "feh --bg-scale @wallpaper@"
  spawnOnce "picom --backend xrender &"
  spawnOnce "trayer --edge top --align right --width 6 --padding 12 --SetDockType true --SetPartialStrut true --expand true --alpha 0 --tint 0x282727 --height 18 &"
  spawnOnce "nm-applet &"
  spawnOnce "flameshot &"
  spawnOnce "blueman-applet &"
  spawnOnce "slack -s &"
  spawnOnce "Discord &"

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
    [ -- Insert position and focus
      ask >>= \w -> doF (\ws -> if M.member w (W.floating ws) then (W.shiftMaster . W.focusWindow w) ws else ws),
      className ~? "Vivaldi" --> insertPosition Above Newer,
      return True --> insertPosition Below Older,
      -- Workspace
      className =? "Slack" --> doShift "10",
      className =? "discord" --> doShift "10",
      -- Float
      className ~? "blueman-manager" --> doCenterFloat,
      className ~? "Gimp" --> doCenterFloat
    ]

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

tabbed =
  renamed [Replace "tabbed"] $
    avoidStruts $
      withBorder 1 $
        spacingRaw False (Border 26 26 79 79) True (Border 0 0 0 0) False $
          Tabbed.tabbedAlways
            Tabbed.shrinkText
            def
              { Tabbed.activeColor = "#393836",
                Tabbed.inactiveColor = "#282727",
                Tabbed.activeBorderWidth = 0,
                Tabbed.inactiveBorderWidth = 0,
                Tabbed.activeTextColor = "#c5c9c5",
                Tabbed.inactiveTextColor = "#c5c9c5",
                Tabbed.fontName = "JetBrainsMono NF",
                Tabbed.decoHeight = 18
              }

myLayoutHook =
  toggleLayouts full $
    onWorkspace "10" tabbed $
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
      ((modMask .|. shiftMask, xK_l), sendMessage Expand),
      ((modMask, xK_d), spawn $ myLauncher),
      ((modMask, xK_b), spawn $ myBrowser),
      ((modMask .|. shiftMask, xK_s), spawn $ "flameshot gui"),
      ((0, xF86XK_AudioRaiseVolume), spawn $ "pactl set-sink-volume 0 +2%"),
      ((0, xF86XK_AudioLowerVolume), spawn $ "pactl set-sink-volume 0 -2%"),
      ((0, xF86XK_AudioMute), spawn $ "pactl set-sink-mute 0 toggle"),
      ((modMask, xK_l), spawn $ "i3lock -i @wallpaper@")
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
      ((modMask .|. shiftMask, button1), (\w -> focus w >> Flex.mouseResizeWindow w))
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
  xmonad . dynamicSBs spawnSB . docks $
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

-- Hyprland configuration -- ported from the i3 config in this repo (../i3/config).
-- Keybindings intentionally mirror the i3 setup 1:1 where Hyprland allows it.
-- Docs: https://wiki.hypr.land/Configuring/  API stubs: /usr/share/hypr/stubs/hl.meta.lua

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- Intel drives eDP-1 on this machine; the NVIDIA MX250 has no connectors (Optimus offload only),
-- so VA-API must point at the Intel driver, not nvidia.
hl.env("LIBVA_DRIVER_NAME", "iHD")

-- Matches Xcursor.size / Xcursor.theme from ~/.Xresources
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Adwaita")


------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})


----------------------
---- MY PROGRAMS ----
----------------------

local terminal    = "alacritty"
local fileManager = "alacritty -e ranger -r ~/dotfiles/ranger"
local dotfiles    = os.getenv("HOME") .. "/dotfiles"


-------------------
---- AUTOSTART ----
-------------------

-- Dropped from the i3 autostart list:
--   polybar   -> waybar (X11 only)
--   picom     -> Hyprland has built-in blur/rounding/opacity
--   flashfocus-> no Wayland equivalent; active border colour serves the same purpose
--   nitrogen  -> hyprpaper
--   conky x2  -> conky is not even installed; those execs already failed silently under i3
--   setxkbmap -> replaced by the input{} block below
--   redshift  -> X11 only; see wlsunset note below

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("mako")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    -- Night light (replaces `redshift -O 3000`). Requires: pacman -S wlsunset
    -- hl.exec_cmd("wlsunset -T 3001 -t 3000")
end)


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- i3 used: gaps inner 10 / gaps outer 0 / default_border pixel 1.
-- Hyprland applies gaps_in per window edge, so gaps_in = 5 gives the same 10px between windows.
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 0,

        border_size = 1,

        col = {
            -- Cyan = polybar's focused-workspace colour; grey = polybar's separator colour.
            active_border   = "rgba(4DD0E1ff)",
            inactive_border = "rgba(3C4449ff)",
        },

        resize_on_border = false,
        allow_tearing    = false,

        layout = "dwindle",
    },

    decoration = {
        -- Kept flat to match i3. Turn rounding/blur up once the port is settled.
        rounding = 0,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = false,
        },

        blur = {
            enabled = false,
        },
    },

    animations = {
        enabled = true,
    },

    -- i3's `workspace_layout stacking` has no dwindle equivalent; groups are the closest thing
    -- (see the SUPER+S bind). Style the groupbar to match the bar palette.
    group = {
        col = {
            border_active   = "rgba(4DD0E1ff)",
            border_inactive = "rgba(3C4449ff)",
        },
        groupbar = {
            font_family = "Iosevka Nerd Font",
            font_size   = 11,
            col = {
                active   = "rgba(4DD0E1ff)",
                inactive = "rgba(141C21ff)",
            },
        },
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})

-- Default curves and animations
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",     enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",     enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",    enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fade",       enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",     enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })


---------------
---- INPUT ----
---------------

-- Replaces `setxkbmap -layout us,ru -option grp:shifts_toggle` from the i3 autostart.
hl.config({
    input = {
        kb_layout  = "us,ru",
        kb_options = "grp:shifts_toggle",

        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

---- Launchers and terminal -------------------------------------------------
hl.bind(mainMod .. " + Return",  hl.dsp.exec_cmd(terminal),   { description = "Terminal" })
hl.bind(mainMod .. " + End",     hl.dsp.exec_cmd(terminal),   { description = "Terminal" })
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close(),     { description = "Close window" })
hl.bind(mainMod .. " + E",       hl.dsp.exec_cmd(fileManager), { description = "File manager" })

hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(dotfiles .. "/rofi/launcher.sh"),         { description = "App launcher" })
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd(dotfiles .. "/rofi/launcher_scripts.sh"), { description = "Run command" })
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("rofi-pass"),                             { description = "Passwords" })
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("networkmanager_dmenu"),                  { description = "Network menu" })
hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd(dotfiles .. "/rofi-bluetooth/rofi-bluetooth"), { description = "Bluetooth menu" })
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(dotfiles .. "/rofi/powermenu-hypr.sh"), { description = "Power menu" })

---- Focus and movement -----------------------------------------------------
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))

hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))

---- Layout -----------------------------------------------------------------
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen(),                { description = "Fullscreen" })
hl.bind(mainMod .. " + SHIFT + space", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
hl.bind(mainMod .. " + space", hl.dsp.window.cycle_next(),            { description = "Cycle windows" })

-- i3 had `split h` / `split v`; dwindle splits by aspect ratio, so both keys toggle the split
-- direction of the current container. SUPER+E was i3's `layout toggle split` but is now the file
-- manager (i3's SUPER+E was unbound for that) -- SUPER+J keeps togglesplit, per Hyprland default.
hl.bind(mainMod .. " + H", hl.dsp.layout("togglesplit"), { description = "Toggle split direction" })
hl.bind(mainMod .. " + V", hl.dsp.layout("togglesplit"), { description = "Toggle split direction" })
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), { description = "Toggle split direction" })

-- i3's stacking layout -> Hyprland groups (tabbed groupbar).
hl.bind(mainMod .. " + S", hl.dsp.group.toggle(),        { description = "Toggle group (was: stacking)" })
hl.bind(mainMod .. " + A", hl.dsp.group.prev(),          { description = "Previous in group" })
hl.bind(mainMod .. " + G", hl.dsp.group.next(),          { description = "Next in group" })

---- Workspaces -------------------------------------------------------------
local wsKeys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
for i, key in ipairs(wsKeys) do
    local ws = i  -- key "0" is workspace 10
    hl.bind(mainMod .. " + " .. key,            hl.dsp.focus({ workspace = ws }))
    hl.bind(mainMod .. " + CTRL + " .. key,     hl.dsp.window.move({ workspace = ws, silent = true }))
    hl.bind(mainMod .. " + SHIFT + " .. key,    hl.dsp.window.move({ workspace = ws }))
end

hl.bind(mainMod .. " + B",         hl.dsp.focus({ workspace = "previous" }), { description = "Back and forth" })
hl.bind(mainMod .. " + CTRL + B",  hl.dsp.window.move({ workspace = "previous", silent = true }))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.window.move({ workspace = "previous" }))

hl.bind(mainMod .. " + Tab",         hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- i3's floating_modifier
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

---- Session ----------------------------------------------------------------
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"), { description = "Reload config" })
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"), { description = "Reload config" })
-- i3 used i3-nagbar to confirm; rofi does the same job here.
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(dotfiles .. "/hypr/scripts/exit-confirm.sh"), { description = "Exit Hyprland" })

---- Resize submap (i3's `mode "resize"`) -----------------------------------
hl.define_submap("resize", function()
    hl.bind("left",  hl.dsp.window.resize({ x = -10, y = 0 }), { repeating = true })
    hl.bind("right", hl.dsp.window.resize({ x = 10, y = 0 }),  { repeating = true })
    hl.bind("up",    hl.dsp.window.resize({ x = 0, y = -10 }), { repeating = true })
    hl.bind("down",  hl.dsp.window.resize({ x = 0, y = 10 }),  { repeating = true })

    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("Escape", hl.dsp.submap("reset"))
    hl.bind(mainMod .. " + R", hl.dsp.submap("reset"))
end)
hl.bind(mainMod .. " + R", hl.dsp.submap("resize"), { description = "Resize mode" })

---- Media and hardware keys (unchanged commands from i3) -------------------
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +2%"),  { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -2%"),  { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"), { locked = true })

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"), { locked = true, repeating = true })

---- Screenshots ------------------------------------------------------------
-- i3: Print -> i3-scrot (fullscreen), Shift+Print -> scrot.sh (region select via `import`)
hl.bind("Print",         hl.dsp.exec_cmd(dotfiles .. "/hypr/scripts/screenshot.sh full"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(dotfiles .. "/hypr/scripts/screenshot.sh region"))


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Workspace -> monitor assignment, mirroring i3's `workspace N output`.
for i = 1, 5 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "eDP-1" })
end
for i = 6, 10 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-3" })
end

-- The only thing picom.conf actually did: Rofi at 90% opacity.
hl.window_rule({
    name    = "rofi-opacity",
    match   = { class = "(?i)^rofi$" },
    opacity = 0.9,
})

-- i3: no_focus [window_role="pop-up"]
hl.window_rule({
    name     = "no-focus-popups",
    match    = { title = "(?i)pop-up" },
    no_focus = true,
})

-- Ignore maximize requests from all apps.
hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix dragging issues with XWayland windows.
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

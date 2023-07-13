os.setlocale("zh_TW.UTF-8")

local awful = require("awful")
local wibox = require("wibox")
local naughty = require("naughty")
local beautiful = require("beautiful")
local gears = require("gears")
require("awful.autofocus")

local wm = require("wm")
beautiful.init(gears.filesystem.get_configuration_dir() .. "/theme.lua")
beautiful.theme_assets.recolor_layout(beautiful, beautiful.fg_dark)

-- Custom widgets and other stuff
local menubox = require("menubox")
local cheatsheet = require("cheatsheet")
local sys_menu = require("sys_menu")
local translate = require("translate")
local sys_widget = require("sys_widget")
local net_widget = require("net_widget")
local wifi_widget = require("wifi_widget")
local pwr_widget = require("pwr_widget")
--local pac_widget = require("pac_widget")
local disk_widget = require("disk_widget")
local sound_widget = require("sound_widget")
local array_search = require("array_search")
local backlight = require("backlight")
local pie_layout = require("pie_layout")
local screenshot = require("screenshot")

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end

-- Variables
terminal = os.getenv("TERMINAL") or "xterm"
modkey = "Mod4"

-- Layouts
awful.layout.layouts = {
    awful.layout.suit.floating,
    awful.layout.suit.tile,
    awful.layout.suit.max,
    awful.layout.suit.tile.top,
    awful.layout.suit.magnifier,
}

-- wm configs
awful.mouse.snap.edge_enabled = false
awful.mouse.drag_to_tag.enabled = true

-- Menubar configuration
menubox.utils.terminal = terminal -- Set the terminal for applications that require it
menubox.refresh()

-- Create wibars
local function client_menu_toggle_fn()
    local instance = nil

    return function ()
        if instance and instance.wibox.visible then
            instance:hide()
            instance = nil
        else
            instance = awful.menu.clients({ theme = { width = 250 } })
        end
    end
end

local taglist_buttons = awful.util.table.join(
    awful.button({ }, 1, function(t) t:view_only() end),
    awful.button({ modkey }, 1, function(t)
        if client.focus then
            client.focus:move_to_tag(t)
        end
    end),
    awful.button({ }, 3, awful.tag.viewtoggle),
    awful.button({ modkey }, 3, function(t)
        if client.focus then
            client.focus:toggle_tag(t)
        end
    end),
    awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
    awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
)

local tasklist_buttons = awful.util.table.join(
    awful.button({ }, 1, function (c)
        if c == client.focus then
            c.minimized = true
        else
            -- Without this, the following
            -- :isvisible() makes no sense
            c.minimized = false
            if not c:isvisible() and c.first_tag then
                c.first_tag:view_only()
            end
            -- This will also un-minimize
            -- the client, if needed
            client.focus = c
            c:raise()
        end
    end),
    awful.button({ }, 3, client_menu_toggle_fn()),
    awful.button({ }, 4, function ()
        awful.client.focus.byidx(1)
    end),
    awful.button({ }, 5, function ()
        awful.client.focus.byidx(-1)
    end)
)

local textclock = wibox.widget {
    widget = wibox.widget.textclock('<span color="' .. beautiful.fg_dark .. '"> %w|%m%d|%H%M%S </span>', 1),
    align = "right",
    font = beautiful.font_large,
}
local calendar = awful.widget.calendar_popup.month {
    position = "tr",
    font = beautiful.font_calendar,
    long_weekdays = true,
    start_sunday = true,
    spacing = 10,
    style_month = { padding = 10 },
    style_focus = {
        bg_color = beautiful.bg_normal,
        fg_color = beautiful.fg_colored,
        border_width = 0,
    },
    style_header = { border_width = 0 },
    style_weekday = { border_width = 0 },
    style_normal = { border_width = 0 },
}
calendar:attach(textclock)

local systray = wibox.widget {
    widget = wibox.widget.systray,
    visible = false,
}

local function set_wallpaper(s)
    -- Wallpaper
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        -- If wallpaper is a function, call it with the screen
        if type(wallpaper) == "function" then
            wallpaper = wallpaper(s)
        end
        gears.wallpaper.maximized(wallpaper, s, false)
    end
end

screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)
    -- Wallpaper
    set_wallpaper(s)

    -- Tags
    awful.tag({ "!", "@", "#", "$", "%", "^", "&", "*", "(", ")" }, s, awful.layout.layouts[2])

    -- Prompt box
    s.promptbox = awful.widget.prompt {
        prompt = " Run: "
    }

    -- Tag list
    s.taglist = awful.widget.taglist {
        screen = s,
        filter = awful.widget.taglist.filter.all,
        buttons = taglist_buttons,
        style = {
            shape = gears.shape.circle,
        },
        layout = {
            spacing = 5,
            layout = wibox.layout.fixed.horizontal,
        },
        widget_template = {
            id = "background_role",
            widget = wibox.container.background,
            forced_width = 10,
            wibox.widget.textbox(" "),
        }
    }

    -- Layout box
    s.layoutbox = awful.widget.layoutbox(s)
    s.layoutbox:buttons(awful.util.table.join(
        awful.button({ }, 1, function () awful.layout.inc( 1) end),
        awful.button({ }, 3, function () awful.layout.inc(-1) end),
        awful.button({ }, 4, function () awful.layout.inc( 1) end),
        awful.button({ }, 5, function () awful.layout.inc(-1) end)
    ))

    -- Task list
    s.tasklist = awful.widget.tasklist {
        screen = s,
        filter = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons,
        style = {
            shape = function(cr, w, h)
                gears.shape.transform(gears.shape.rectangle):translate(w*0.025, 0)(cr, w*0.95, 2)
            end,
        },
        widget_template = {
            id = "background_role",
            widget = wibox.container.background,
            create_callback = function(self, c, index, objects)
                -- high res icon
                self:get_children_by_id('client_icon')[1].client = c
            end,
            {
                layout = wibox.layout.align.horizontal,
                expand = "outside",
                nil,
                {
                    layout = wibox.layout.fixed.horizontal,
                    {
                        widget = wibox.container.margin,
                        right = 5,
                        {
                            id = "client_icon",
                            widget = awful.widget.clienticon,
                        },
                    },
                    {
                        id = "text_role",
                        widget = wibox.widget.textbox,
                    }
                }
            }
        }
    }

    -- Create the wibox
    s.wibox = awful.wibar({ position = "top", screen = s, height = beautiful.bar_height })
    s.btmwibox = awful.wibar({ position = "bottom", screen = s, height = beautiful.bar_height })

    -- Add widgets to the wibox
    s.wibox:setup {
        layout = wibox.layout.align.horizontal,
        {
            layout = wibox.layout.fixed.horizontal,
            --xdg_launcher,
            {
                layout = wibox.container.background,
                shape = function(cr, w, h)
                    gears.shape.transform(gears.shape.parallelogram):translate(-20, 0)(cr, w+20, h, w+10)
                end,
                forced_width = 40,
                bg = beautiful.bg_colored,
                s.layoutbox,
            },
            s.taglist,
        },
        s.tasklist,
        {
            layout = wibox.layout.fixed.horizontal,
            systray,
            --awful.widget.keyboardlayout(),
            wibox.widget.textbox(" "),
            --pac_widget,
            wibox.widget.textbox(" "),
            pwr_widget("BAT0"),
            wibox.widget.textbox(" "),
            wifi_widget("wlan0"),
            wibox.widget.textbox(" "),
            sound_widget,
            wibox.widget.textbox(" "),
            {
                widget = wibox.container.background,
                shape = function(cr, w, h)
                    gears.shape.parallelogram(cr, w+20, h, w+10)
                end,
                forced_width = 140,
                bg = beautiful.bg_colored,
                textclock,
            },
        },
    }

    s.btmwibox:setup {
        layout = wibox.layout.align.horizontal,
        {
            widget = wibox.container.background,
            shape = function(cr, w, h)
                gears.shape.transform(gears.shape.parallelogram):translate(-20, 25):scale(1, -1)(cr, w+20, h+5, w+10)
            end,
            bg = beautiful.bg_minimize,
            {
                layout = wibox.layout.fixed.horizontal,
                {
                    widget = wibox.widget.textbox,
                    text = "  ",
                    font = beautiful.font_large,
                },
                disk_widget({"/", "/home/rio/tmp"})
            }
        },
        {
            layout = wibox.layout.fixed.horizontal,
            {
                widget = wibox.container.constraint,
                strategy = "min",
                width = 200,
                s.promptbox,
            },
        },
        {
            layout = wibox.layout.flex.horizontal,
            max_widget_size = 80,
            net_widget({"eth0", "wlan0"}, "rx"),
            net_widget({"eth0", "wlan0"}, "tx"),
            sys_widget("temp"),
            sys_widget("cpu"),
            sys_widget("memory"),
            --sys_widget("swap"),
        },
    }
end)
--[[
local r, o = pcall(function()
    local pie = wibox.widget {
        widget = pie_layout,
        force_radius = 250,
    }

    for i = 2, 3 do
        for j = 1, 3 do
            pie:add_widget_at(wibox.widget {
                widget = wibox.widget.textbox,
                text = "hello",
                align = "center",
            }, i, j)
        end
    end

    local tw = awful.popup {
        screen = screen[1],
        shape = pie:shape(),
        widget = pie,
    }
end)
if not r then print(o) end
--]]

local function toggle_touchpad()
    awful.spawn.easy_async("xinput", function(devices)
        local id = devices:match("MSFT0001:01 06CB:CD64 Touchpad.-id=(%d+)")
        if id == nil then return end
        awful.spawn.easy_async("xinput list-props " .. id, function(props)
            local enabled = props:match("Device Enabled %(%d+%):%s+(%d)") == "1"
            if enabled then
                awful.spawn("xinput --disable " .. id, false)
            else
                awful.spawn("xinput --enable " .. id, false)
            end
        end)
    end)
end

-- Key bindings
globalkeys = awful.util.table.join(
    awful.key({ modkey, }, "Left", awful.tag.viewprev),
    awful.key({ modkey, }, "Right", awful.tag.viewnext),
    awful.key({ modkey, }, "[", awful.tag.viewprev),
    awful.key({ modkey, }, "]", awful.tag.viewnext),
    awful.key({ modkey, }, "\\", awful.tag.history.restore),
    awful.key({ modkey, }, "j",
        function ()
            awful.client.focus.byidx( 1)
        end
    ),
    awful.key({ modkey, }, "k",
        function ()
            awful.client.focus.byidx(-1)
        end
    ),

    -- Layout manipulation
    awful.key({ modkey, "Shift" }, "j", function () awful.client.swap.byidx( 1) end),
    awful.key({ modkey, "Shift" }, "k", function () awful.client.swap.byidx( -1) end),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end),
    awful.key({ modkey }, "Down", function () awful.screen.focus_relative( 1) end),
    awful.key({ modkey }, "Up", function () awful.screen.focus_relative(-1) end),
    awful.key({ modkey, }, "u", awful.client.urgent.jumpto),
    awful.key({ modkey, }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end
    ),

    -- Standard program
    awful.key({ modkey, }, "Return", function () awful.spawn(terminal) end),
    awful.key({ modkey, "Control" }, "r", awesome.restart),
    awful.key({ modkey, "Shift" }, "q", awesome.quit),
    awful.key({ modkey, "Shift" }, "o", function() awful.spawn.with_shell("display-layout.sh") end),
    awful.key({ modkey, }, "l", function () awful.tag.incmwfact( 0.05) end),
    awful.key({ modkey, }, "h", function () awful.tag.incmwfact(-0.05) end),
    awful.key({ modkey, "Shift" }, "h", function () awful.tag.incnmaster( 1, nil, true) end),
    awful.key({ modkey, "Shift" }, "l", function () awful.tag.incnmaster(-1, nil, true) end),
    awful.key({ modkey, "Mod1" }, "h", function () awful.tag.incncol( 1, nil, true) end),
    awful.key({ modkey, "Mod1" }, "l", function () awful.tag.incncol(-1, nil, true) end),
    awful.key({ modkey, }, "space", function () awful.layout.inc( 1) end),
    awful.key({ modkey, "Shift" }, "space", function () awful.layout.inc(-1) end),
    awful.key({ modkey, "Control" }, "n",
        function ()
            local c = awful.client.restore()
            -- Focus restored client
            if c then
                client.focus = c
                c:raise()
            end
        end
    ),

    -- Prompt
    awful.key({ modkey }, "d", function() sys_menu:show() end),
    awful.key({ modkey }, ";", function() awful.screen.focused().promptbox:run() end),

    -- Menubar
    awful.key({ modkey }, "p", menubox.show),
    awful.key({ modkey, "Shift" }, "p", function() menubox.refresh(); menubox.show() end),

    -- Systray
    awful.key({ modkey }, "s", function()
        systray:set_screen(awful.screen.focused())
        systray.visible = not systray.visible
    end),

    -- Cheatsheet
    awful.key({ modkey }, "a", function() cheatsheet.show("/array30.jpg", 1139, 550) end),
    awful.key({ modkey }, "q", function() cheatsheet.show("/schedule.png", 576, 729) end),
    awful.key({ modkey }, ",", array_search.show_prompt),

    -- Screen shot
    awful.key({ modkey, "Shift" }, "s", screenshot.select),
    awful.key({ }, "Print", screenshot.all),
    awful.key({ "Shift" }, "Print", screenshot.select),
    awful.key({ "Control" }, "Print", screenshot.screen),

    -- Others
    awful.key({ modkey }, "=", function() sound_widget:volume("1%+") end),
    awful.key({ modkey }, "-", function() sound_widget:volume("1%-") end),
    awful.key({ modkey, "Shift" }, "=", function() sound_widget:volume("toggle") end),
    awful.key({ modkey, "Shift" }, "-", function() sound_widget:volume("toggle") end),
    awful.key({ }, "XF86AudioRaiseVolume", function() sound_widget:volume("1%+") end),
    awful.key({ }, "XF86AudioLowerVolume", function() sound_widget:volume("1%-") end),
    awful.key({ }, "XF86AudioMute", function() sound_widget:volume("toggle") end),
    awful.key({ }, "XF86AudioPlay", function() awful.spawn("playerctl play-pause", false) end),
    awful.key({ }, "XF86AudioPrev", function() awful.spawn("playerctl previous", false) end),
    awful.key({ }, "XF86AudioNext", function() awful.spawn("playerctl next", false) end),
    awful.key({ modkey }, "#63", function() awful.spawn("playerctl play-pause", false) end), -- KP multiply
    awful.key({ modkey }, "#106", function() awful.spawn("playerctl previou", false) end),   -- KP slash
    awful.key({ modkey }, "#82", function() awful.spawn("playerctl next", false) end),       -- KP minus
    awful.key({ modkey }, "#86", function() awful.spawn("playerctl stop", false) end),       -- KP plus
    awful.key({ }, "XF86MonBrightnessUp", function() backlight.inc(0.05) end),
    awful.key({ }, "XF86MonBrightnessDown", function() backlight.inc(-0.05) end),
    awful.key({ modkey, "Control", "Mod1" }, "k", function () awful.spawn.with_shell("xkill") end),
    awful.key({ modkey }, "/", translate.toggle),
    awful.key({ modkey, "Control" }, "#93", toggle_touchpad)
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.

local np_map = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }
for i = 1, 10 do
    local function view_tag()
        local screen = awful.screen.focused()
        local tag = screen.tags[i]
        if tag then
            tag:view_only()
        end
    end

    local function toggle_tag()
        local screen = awful.screen.focused()
        local tag = screen.tags[i]
        if tag then
            awful.tag.viewtoggle(tag)
        end
    end

    local function move_to_tag()
        if client.focus then
            local tag = client.focus.screen.tags[i]
            if tag then
                client.focus:move_to_tag(tag)
            end
        end
    end

    local function relative_tag(amount)
        if client.focus then
            local tags = client.focus.screen.tags
            local tag = nil
            for i,v in ipairs(tags) do
                if client.focus.first_tag == v then
                    tag = tags[(i+amount-1) % 10 + 1]
                    break
                end
            end
            if tag then
                client.focus:move_to_tag(tag)
            end
        end
    end

    local function toggle_client_tag()
        if client.focus then
            local tag = client.focus.screen.tags[i]
            if tag then
                client.focus:toggle_tag(tag)
            end
        end
    end

    globalkeys = awful.util.table.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9, view_tag),
        awful.key({ modkey }, "#" .. np_map[i], view_tag),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9, toggle_tag),
        awful.key({ modkey, "Control" }, "#" .. np_map[i], toggle_tag),
        -- Move client to tag.
        awful.key({ modkey, "Shift" }, "#" .. i + 9, move_to_tag),
        awful.key({ modkey, "Shift" }, "#" .. np_map[i], move_to_tag),
        -- Toggle tag on focused client.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9, toggle_client_tag),
        awful.key({ modkey, "Control", "Shift" }, "#" .. np_map[i], toggle_client_tag),
        -- Relative move to tag
        awful.key({ modkey, "Shift" }, "[", function() relative_tag(9) end),
        awful.key({ modkey, "Shift" }, "]", function() relative_tag(1) end)
    )
end

root.keys(globalkeys)

-- Client keys
clientkeys = awful.util.table.join(
    awful.key({ modkey, }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end),
    awful.key({ modkey, }, "c", function (c) c:kill() end),
    awful.key({ modkey, "Control" }, "space", awful.client.floating.toggle),
    awful.key({ modkey, "Control" }, "Return", function (c)
        local master = awful.client.getmaster()
        if master ~= nil then
            c:swap(awful.client.getmaster())
        end
    end),
    awful.key({ modkey, }, "o", function (c) c:move_to_screen() end),
    awful.key({ modkey, }, "t", function (c) c.ontop = not c.ontop end),
    awful.key({ modkey, }, "n", function (c) c.minimized = true end),

    awful.key({ modkey, }, "m", function (c)
        c.maximized = not c.maximized
        c:raise()
    end),

    awful.key({ modkey, "Control" }, "l", function (c)
        local idx = awful.client.idx(c)
        if idx == idx then -- not NaN
            awful.client.incwfact(0.05, c)
        end
    end),

    awful.key({ modkey, "Control" }, "h", function(c)
        local idx = awful.client.idx(c)
        if idx == idx then -- not NaN
            awful.client.incwfact(-0.05, c)
        end
    end),

    awful.key({ modkey }, "w", function(c)
        wm.unswallow(c, true)
    end)
)

-- Buttons
clientbuttons = awful.util.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize)
)

-- Rules
awful.rules.rules = {
    -- All clients will match this rule.
    {
        rule = { },
        properties = {
            border_width = beautiful.border_width,
            border_color = beautiful.border_normal,
            focus = awful.client.focus.filter,
            raise = true,
            keys = clientkeys,
            buttons = clientbuttons,
            screen = awful.screen.preferred,
            placement = awful.placement.no_overlap+awful.placement.no_offscreen,
            size_hints_honor = false,
        }
    },

    -- Floating clients.
    {
        rule_any = {
            instance = {
                "gcin",
            },
            name = {
                "Event Tester",  -- xev.
            },
            class = {
                "scrcpy"
            }
        },
        properties = { floating = true }
    },
}

-- Autostarts
---[[
awful.spawn("dex -a -e awesome", false)
awful.spawn("display-layout.sh", false)
--]]

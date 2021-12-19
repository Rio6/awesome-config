-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
local wibox = require("wibox")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local naughty = require("naughty")

beautiful.init(gears.filesystem.get_configuration_dir() .. "/theme.lua")
beautiful.theme_assets.recolor_layout(beautiful, beautiful.fg_dark)

local menubox = require("menubox")
local pwr_widget = require("pwr_widget")
local wifi_widget = require("wifi_widget")
local keyutil = require("keyutil")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function(err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end
-- }}}

-- This is used later as the default terminal and editor to run.
terminal = "xterm"
editor = os.getenv("EDITOR") or "vim"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
   awful.layout.suit.tile.bottom,
   awful.layout.suit.max,

}
-- }}}

-- {{{ Menu
mainmenu = awful.menu({ items = {{ "restart", awesome.restart, beautiful.awesome_icon }}})

-- Menubar configuration
menubox.utils.terminal = terminal -- Set the terminal for applications that require it
menubox.geometry = { width = screen[1].geometry.width * 0.8, height = screen[1].geometry.height * 0.3 }
menubox.item_height = 40
-- }}}

-- {{{ Wibar
-- Create a textclock widget
local textclock = wibox.widget {
    widget = wibox.widget.textclock('<span color="' .. beautiful.fg_dark .. '"> %w|%m%d|%H%M%S </span>', 1),
    align = "right",
    font = beautiful.font_large,
    buttons = awful.button({ }, 1, function(w) mainmenu:toggle { coords = w.geometry } end)
}

-- Create a wibox for each screen and add it
local taglist_buttons = gears.table.join(
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
    end)
)

local function set_wallpaper(s)
    -- Wallpaper
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        -- If wallpaper is a function, call it with the screen
        if type(wallpaper) == "function" then
            wallpaper = wallpaper(s)
        end
        gears.wallpaper.maximized(wallpaper, s, false, { x = -55, y = 0 })
    end
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)
    -- Wallpaper
    set_wallpaper(s)

    -- Each screen has its own tag table.
    for i = 1, 4 do
       awful.tag.add(tostring(i), {
          screen = s,
          layout = awful.layout.layouts[2],
          column_count = 4,
       })
    end

    s.tags[1]:view_only()

    -- Create a promptbox for each screen
    s.promptbox = awful.widget.prompt()
    -- Create an imagebox widget which will contain an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    s.layoutbox = awful.widget.layoutbox(s)
    s.layoutbox._layoutbox_tooltip:remove_from_object(s.layoutbox)
    s.layoutbox:buttons(gears.table.join(
       awful.button({ }, 1, function() awful.layout.inc( 1) end),
       awful.button({ }, 3, function() awful.layout.inc(-1) end)
    ))

    -- Create a taglist widget
    s.taglist = awful.widget.taglist {
        screen = s,
        filter = awful.widget.taglist.filter.all,
        buttons = taglist_buttons,
        style = {
            shape = gears.shape.circle,
        },
        layout = {
            spacing = dpi(5),
            layout = wibox.layout.fixed.horizontal,
        },
        widget_template = {
            id = "background_role",
            widget = wibox.container.background,
            forced_width = dpi(10),
            wibox.widget.textbox(" "),
        }
    }

    -- Create a tasklist widget
    s.tasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons
    }

    -- Create the wibox
    s.wibox = awful.wibar({ position = "top", screen = s, height = beautiful.bar_height })

    -- Add widgets to the wibox
    s.wibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            {
                layout = wibox.container.background,
                shape = function(cr, w, h)
                    gears.shape.transform(gears.shape.parallelogram):translate(dpi(-20), 0)(cr, w+dpi(20), h, w+dpi(10))
                end,
                forced_width = dpi(40),
                bg = beautiful.bg_colored,
                s.layoutbox,
            },
            s.taglist,
        },
        {
            widget = wibox.container.margin,
            left = dpi(20),
            right = dpi(20),
            {
                layout = wibox.layout.flex.horizontal,
                pwr_widget("axp20x-battery"),
                wifi_widget("wlan0"),
            }
        },
        { -- Right widgets
            widget = wibox.container.background,
            shape = function(cr, w, h)
                gears.shape.parallelogram(cr, w+20, h, w+10)
            end,
            forced_width = 270,
            bg = beautiful.bg_colored,
            textclock,
        },
    }
end)
-- }}}

-- {{{ Mouse bindings
root.buttons(gears.table.join(
    awful.button({ }, 3, function() mainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = gears.table.join(
    keyutil.register("XF86AudioRaiseVolume", function(key, count)
        if count == 1 then
            awful.spawn(os.getenv("HOME") .. "/.local/bin/keyboard toggle")
        elseif count == 2 then
            menubox.show()
        end
    end),
    keyutil.register("XF86AudioLowerVolume", function(key, count)
        if count == 2 then
            if client.focus then
                client.focus:kill()
            end
        end
    end),
    keyutil.register("XF86PowerOff", function(key, count)
        if count == 1 then
            -- sleep
        elseif count == 3 then
            awesome.restart()
        end
    end)
)

clientbuttons = gears.table.join(
    awful.button({ }, 1, function(c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
    end),
    awful.button({ modkey }, 1, function(c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function(c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.resize(c)
    end)
)

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
    awful.rules.rules = {
        -- All clients will match this rule.
        {
            rule = { },
            except = { class = "svkbd" },
            properties = {
                border_width = beautiful.border_width,
                border_color = beautiful.border_normal,
                focus = awful.client.focus.filter,
                raise = true,
                --keys = clientkeys,
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
                    "pinentry",
                },
                name = {
                    "Event Tester",  -- xev.
                },
            },
            properties = { floating = true }
        },

        {
            rule = { class = "svkbd" },
            properties = {
                placement = awful.placement.bottom,
                honor_workarea = false,
                border_width = 0,
                dockable = true,
                ontop = true,
                sticky = true,
                focusable = false,
                tags = {},
            },
            callback = function(c)
                c:struts { bottom = c.height }
            end
        }
    }
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function(c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position
      and not c.dockable
      then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

client.connect_signal("unmanage", function(c)
    if c.class == "svkbd" then
        -- Fixes a focusing issue when svkbd closes, there might be a better way but this works
        local t = awful.screen.focused().selected_tag
        awful.tag.viewtoggle(t)
        awful.tag.viewtoggle(t)
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}

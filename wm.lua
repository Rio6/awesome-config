local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")

local wm = {}

-- Signals
client.connect_signal("manage", function(c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup and
        not c.size_hints.user_position
        and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
        and awful.client.focus.filter(c) then
        client.focus = c
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)

-- Window swallowing
local swallow_rule = {
    rule = { class = "XTerm" },
    except = { name = "^%[WeeChat [%d.]+%]" },
}

local function is_tiled(c)
    if c == nil or awful.client.idx(c) == nil then return false end
    local layout = awful.layout.get(c.screen)
    return (layout == awful.layout.suit.tile or layout == awful.layout.suit.tile) and
        not c.minimized and not c.floating and not c.maximized and not c.fullscreen
end

client.connect_signal("manage", function(c)
    local prev = awful.client.focus.history.get(c.screen, 1)

    if is_tiled(prev) and is_tiled(c) then

        -- Move client to beside the last focused window
        local swapCount = awful.client.idx(prev).idx - awful.client.idx(c).idx
        local dir = swapCount > 0 and 1 or -1
        for i = 0, swapCount - dir, dir do
            awful.client.swap.byidx(dir, c)
        end

        -- window swallowing
        if awful.rules.matches(prev, swallow_rule) and not awful.rules.matches(c, swallow_rule) then
            -- Restore swalowee when child is not tiled
            c:connect_signal("property::floating_geometry", function(c)
                if not is_tiled(c) then
                    unswallow(c, false)
                end
            end)

            prev.minimized = true
            c.swallowed = prev
        end
    end
end)

-- Show or toggles swallowed window
function unswallow(c, toggle)
    local s = c.swallowed
    if s and s.valid then
        if toggle then
            s.minimized = not s.minimized
        else
            s.minimized = false
        end
    end
end

client.connect_signal("unmanage", function(c)
    unswallow(c, false)
end)

return {
    unswallow = unswallow
}

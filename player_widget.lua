local awful = require("awful")
local wibox = require("wibox")
local naughty = require("naughty")
local gears = require("gears")
local beautiful = require("beautiful")

local COVER_PATH = "/tmp/rio/awesome/cover.png"
local DEFAULT_COVER = gears.filesystem.get_configuration_dir() .. "/music.png"
local CAVA_NUM_BARS = 200

local state = {
    status = "Stopped",
    title = "",
    album = "",
    artist = "",
    position = 0,
    cover = DEFAULT_COVER,
}

local function file_exists(file)
    local f = io.open(file, "r")
    if f then
        f:close()
        return true
    end
    return false
end

local popup

local status_text = wibox.widget {
    widget = wibox.widget.textbox,
    align = "right"
}

local title_text = wibox.widget.textbox()

local bars = wibox.widget {
    widget = wibox.widget.graph,
    max_value = 1000,
    step_width = 3,
    step_spacing = 1,
    color = beautiful.bg_graph,
    background_color = beautiful.bg_normal,
}
bars:set_width((bars.step_width + bars.step_spacing) * CAVA_NUM_BARS)

local player_widget = wibox.widget {
    widget = wibox.container.margin,
    left = 10, right = 10,
    visible = false,
    {
        layout = wibox.layout.stack,
        {
            layout = wibox.layout.align.horizontal,
            expand = "outside",
            nil,
            bars
        },
        {
            layout = wibox.layout.align.horizontal,
            expand = "outside",
            status_text,
            {
                layout = wibox.container.scroll.horizontal,
                speed = 10,
                fps = 2,
                title_text
            }
        }
    }
}

-- cava graph
local run_cava = false
local cava_cmd = "cava -p " .. gears.filesystem.get_configuration_dir() .. "/cava.conf"
local cava_pid
local function start_cava()
    if type(cava_pid) == "number" then return end
    if not run_cava then return end
    cava_pid = awful.spawn.with_line_callback(cava_cmd, {
        stdout = function(line)
            if cava_pid == nil then return end
            local i = CAVA_NUM_BARS
            for value in line:gmatch('[0-9]+') do
                -- give it some overshoot
                bars._private.values[i] = math.min(tonumber(value) * 1.8, bars.max_value)
                i = i - 1
            end
            bars:emit_signal("widget::redraw_needed")
        end,
        exit = function(reason, code)
            bars:clear()
            cava_pid = nil
        end
    })
end

local function stop_cava()
    if type(cava_pid) == "number" then
        os.execute("kill -int " .. cava_pid)
    end
end

function player_widget:cmd(cmd)
    awful.spawn.easy_async("playerctl " .. cmd, function() end)
end

local function show_popup()
    local info = ""
    for _,item in ipairs { {"", state.artist}, {"", state.album} } do
        if item[2] ~= "" then
            info = info .. string.format("  %s %s\n", item[1], item[2])
        end
    end
    --info = info ..  string.format("   %s", state.position)

    popup = naughty.notify({
        replaces_id = popup,
        title = state.title,
        text = info,
        icon = state.cover ~= "" and file_exists(COVER_PATH) and COVER_PATH or DEFAULT_COVER,
        icon_size = 200,
        timeout = 0,
        hover_timeout = 0.5,
        screen = awful.screen.focused(),
        position = "bottom_middle",
        border_width = 0,
        margin = 10
    })
end

local function hide_popup()
    if popup ~= nil then
        naughty.destroy(popup)
        popup = nil
    end
end

local last_status = state.status
local last_cover = state.cover
function player_widget:update()
    if state.cover ~= "" and state.cover ~= last_cover then
        -- update cover art
        last_cover = state.cover
        awful.spawn.easy_async_with_shell(
            "curl -s --create-dirs -o " .. COVER_PATH .. " " .. state.cover,
            function() self:update() end
        )
    end

    if state.status ~= last_status then
        if state.status == "Playing" then
            status_text:set_text(" ")
            start_cava()
        elseif state.status == "Paused" then
            status_text:set_text(" ")
            stop_cava()
        else
            status_text:set_text(" ")
            stop_cava()
        end
        last_status = state
    end

    if state.status == "Playing" or state.status == "Paused" then
        if state.artist ~= "" then
            title_text:set_text(string.format("%s - %s", state.title, state.artist))
        else
            title_text:set_text(state.title)
        end

        self.visible = true
    else
        self.visible = false
    end

    if popup ~= nil then
        show_popup()
    end
end

player_widget:connect_signal("button::press", function(widget, x, y, button, mods, widget)
    local ratio = x / widget.width
    if button == 1 then
        if ratio < 0.3 then
            player_widget:cmd("previous")
        elseif ratio > 0.6 then
            player_widget:cmd("next")
        else
            player_widget:cmd("play-pause")
        end
    elseif button == 2 then
        player_widget:cmd("stop")
    --elseif button == 3 and duration > 0 then
        --player_widget:cmd("position " .. math.floor(ratio * duration + .5))
    elseif button == 3 then
        run_cava = not run_cava
        if run_cava then start_cava() else stop_cava() end
    elseif button == 4 then
        player_widget:cmd("previous")
    elseif button == 5 then
        player_widget:cmd("next")
    else
        player_widget:update()
    end
end)

-- idle loop
local playerctl_pid
local playerctl_running = true
local function playerctl_idle()
    if type(playerctl_pid) == "number" then return end
    playerctl_pid = awful.spawn.with_line_callback(
        "playerctl metadata -F -f '" ..
        "status:{{status}}\n" ..
        "title:{{title}}\n" ..
        "album:{{album}}\n" ..
        "artist:{{artist}}\n" ..
        "position:{{duration(position)}}\n" ..
        "cover:{{mpris:artUrl}}\n" ..
        "eos:'",
    {
        stdout = function(msg)
            name, value = msg:match("(%a+):(.*)")
            if name == nil then
                state.status = "Stopped"
                player_widget:update()
            elseif name == "eos" then
                player_widget:update()
            elseif state[name] ~= nil then
                state[name] = value
            end
        end,
        exit = function()
            if playerctl_running then
                gears.timer.start_new(2, function()
                    playerctl_idle()
                    return false
                end)
            end
            playerctl_pid = nil
            state.status = "Stopped"
            player_widget:update()
        end
    })
end

local function stop_playerctl()
    if type(playerctl_pid) == "number" then
        playerctl_running = false
        os.execute("kill -term " .. playerctl_pid)
    end
end

awesome.connect_signal("exit", function()
    stop_cava()
    stop_playerctl()
end)

player_widget:connect_signal("mouse::enter", function() if player_widget.visible then show_popup() end end)
player_widget:connect_signal("mouse::leave", hide_popup)

playerctl_idle()

return player_widget

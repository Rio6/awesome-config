local awful = require("awful")
local wibox = require("wibox")
local naughty = require("naughty")
local gears = require("gears")
local beautiful = require("beautiful")

local MUSIC_DIR = "$HOME/Music" -- need to use $HOME here for some reason
local COVER_PATH = "/run/user/1000/awesome/cover.jpg"
local DEFAULT_COVER = gears.filesystem.get_configuration_dir() .. "/music.png"

local track, artist, album, title, file, state, elapsed, duration = 0, "", "", "", "", "", 0, 0
local start_cava, stop_cava

local function format_sec(sec)
    local sec = math.floor(tonumber(sec) or 0)
    return string.format("%02d:%02d:%02d", math.floor(sec/3600), math.floor(sec/60) % 60, sec % 60)
end

local popup = nil

local status_text = wibox.widget {
    widget = wibox.widget.textbox,
    align = "right"
}

local title_text = wibox.widget.textbox()

local progress = wibox.widget {
    widget = wibox.widget.progressbar,
    color = beautiful.bg_colored,
    background_color = beautiful.bg_dark,
    max_value = 1,
    shape = function(cr, w, h)
        gears.shape.transform(gears.shape.rectangle):translate(0, h-2)(cr, w, 2)
    end,
}

local bars = wibox.widget {
    widget = wibox.widget.graph,
    max_value = 1000,
    step_width = 3,
    step_spacing = 1,
    color = beautiful.bg_graph,
    background_color = beautiful.bg_normal,
}
bars:set_width((bars.step_width + bars.step_spacing) * 200)

local mpc_widget = wibox.widget {
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
        progress,
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

local function show()

    local info = ""
    for _,item in ipairs { {"", artist}, {"", album}, {"", track}, {"", file } } do
        if item[2] ~= "" then
            info = info .. string.format(" ├ %s %s\n", item[1], item[2])
        end
    end
    info = info ..  string.format(" └  %s / %s", format_sec(elapsed), format_sec(duration))

    if popup ~= nil then
        naughty.replace_text(popup, title, info)
    else
        popup = naughty.notify({
            title = title,
            text = info,
            icon = os.execute("test -f " .. COVER_PATH) and COVER_PATH or DEFAULT_COVER,
            icon_size = 200,
            timeout = 0,
            hover_timeout = 0.5,
            screen = awful.screen.focused(),
            position = "bottom_middle",
            border_width = 0,
            margin = 10
        })
    end
end

local function hide()
    if popup ~= nil then
        naughty.destroy(popup)
        popup = nil
    end
end

local last_file = nil
local last_state = nil

function mpc_widget:update(mpc_cmd)
    if mpc_cmd == nil then
        mpc_cmd = "status"
    end

    local msg = awful.spawn.easy_async_with_shell("mpc -f '%track%\\n%artist%\\n%album%\\n[%title%|%name%]\\n%file%' " .. mpc_cmd, function(stdout)

        local elapsed_min, elapsed_sec, duration_min, duration_sec
        track, artist, album, title, file, state, elapsed_min, elapsed_sec, duration_min, duration_sec =
            stdout:match("^([0-9]*)\n([^\n]*)\n([^\n]*)\n([^\n]*)\n([^\n]*)\n%[([a-z]+)%] .* ([0-9]+):([0-9]+)/([0-9]+):([0-9]+)")

        if track == nil then
            track, artist, album, title, file, state, elapsed, duration = 0, "", "", "", "", "", 0, 0
        else
            elapsed = tonumber(elapsed_min) * 60 + tonumber(elapsed_sec)
            duration = tonumber(duration_min) * 60 + tonumber(duration_sec)
        end

        if file ~= "" and file ~= last_file then
            last_file = file
            -- update cover art
            local cover_cmd = ([=[
                if mkdir -p "$(dirname "{cover}")"; then
                    test -e "{cover}" && rm "{cover}"
                    if [[ "{music_file}" == https://www.youtube.com/* ]]; then
                        rm -f "{cover}"
                        curl $(youtube-dl --get-thumbnail --skip-download "{music_file}") | convert - "{cover}"
                    else
                        cover=$(find "$(dirname "{music_dir}/{music_file}")" -name '*.jpg' -o -name '*.png' | head -n 1)
                        if [ -f "$cover" ]; then
                            ln -sf "$cover" "{cover}"
                        else
                            rm -f "{cover}"
                            ffmpeg -hide_banner -y -i "{music_dir}/{music_file}" -vf scale=200:-1 "{cover}"
                        fi
                    fi
                fi
            ]=]):gsub("{([^}]*)}", {
                ["music_file"] = file,
                ["music_dir"] = MUSIC_DIR,
                ["cover"] = COVER_PATH
            })
            awful.spawn.easy_async_with_shell(cover_cmd, function() end)
        end

        self:update_state(state)

        if popup ~= nil then
            show()
        end
    end)
end

function mpc_widget:update_state(state)
    if state ~= last_state then
        if state == "playing" then
            status_text:set_text(" ")
            --start_cava()
        elseif state == "paused" then
            status_text:set_text(" ")
        else
            status_text:set_text(" ")
            stop_cava()
        end
        last_state = state
    end

    if state == "playing" or state == "paused" then

        if title ~= "" then
            if artist ~= "" then
                title_text:set_text(string.format("%s - %s", artist, title))
            else
                title_text:set_text(title)
            end
        else
            title_text:set_text(file)
        end

        progress:set_value(elapsed / duration)
        self.visible = true
    else
        self.visible = false
    end
end

mpc_widget:connect_signal("button::press", function(widget, x, y, button, mods, widget)
    local ratio = x / widget.width
    if button == 1 then
        if ratio < 0.3 then
            mpc_widget:update("prev")
        elseif ratio > 0.6 then
            mpc_widget:update("next")
        else
            mpc_widget:update("toggle")
        end
    elseif button == 2 then
        mpc_widget:update("stop")
    elseif button == 3 and duration > 0 then
        mpc_widget:update("seek " .. math.floor(ratio * duration + .5))
    elseif button == 4 then
        mpc_widget:update("prev")
    elseif button == 5 then
        mpc_widget:update("next")
    else
        mpc_widget:update()
    end
end)
mpc_widget:connect_signal("mouse::enter", function() if mpc_widget.visible then show() end end)
mpc_widget:connect_signal("mouse::leave", hide)

-- idle loop and elapsed time counting
local function mpc_idle()
    awful.spawn.with_line_callback("mpc idleloop player", {
        stdout = function() mpc_widget:update() end,
        stderr = function() end,
        exit = function()
            gears.timer.start_new(2, function()
                mpc_idle()
                return false
            end)

            mpc_widget:update_state("stopped")
        end
    })
end

gears.timer.start_new(1, function()
    if state == "playing" then
        elapsed = elapsed + 1
        progress:set_value(elapsed / duration)

        if popup ~= nil then
            show()
        end
    end
    return true
end)

-- cava graph
local cava_cmd = "cava -p " .. gears.filesystem.get_configuration_dir() .. "/cava.conf"
local cava_pid = nil
start_cava = function()
    if type(cava_pid) == "number" then
        return
    end

    cava_pid = awful.spawn.with_line_callback(cava_cmd, {
        stdout = function(line)
            local i = 1
            for value in line:gmatch('[0-9]+') do
                -- give it some overshoot
                bars._private.values[i] = math.min(tonumber(value) * 1.8, bars.max_value)
                i = i + 1
            end
            bars:emit_signal("widget::redraw_needed")
        end,
        exit = function(reason, code)
            bars:clear()
            cava_pid = nil
        end
    })
end

stop_cava = function()
    if type(cava_pid) == "number" then
        os.execute("kill -int " .. cava_pid)
    end
end

awesome.connect_signal("exit", stop_cava)

mpc_widget:update()
mpc_idle()

return mpc_widget

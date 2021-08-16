local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")

local translator_config = "-show-languages n -show-prompt-message n"
local text = nil

local translate = {}

local box = wibox {
    ontop = true,
    bg = beautiful.bg_normal,
    border_color = beautiful.border_focus,
    border_width = 1,

    widget = wibox.container.margin (
        wibox.widget {
            widget = wibox.widget.textbox,
            align = "left",
            font = "Droid Sans Mono 12",
            wrap = "word",
        },
    20)
}

local function move_box()
    awful.placement.top(box, {
        bounding_rect = {
            x = box.screen.geometry.x + (box.screen.geometry.width - box.width) / 2,
            y = box.screen.geometry.y + box.position,
            width = box.width,
            height = box.height
        }
    })
end

local function show_box(text)

    local width = 0
    text:gsub("[^\n]+", function(str)
        if #str > width then
            width = #str
        end
    end)

    box.widget.widget:set_text(text)
    box.screen = awful.screen.focused()

    box.width = math.min(box.screen.geometry.width * 0.7, width * 12) -- 12px font (roughly)
    box.height = box.widget.widget:get_height_for_width(box.width, box.screen) + 20

    if box.height > box.screen.geometry.height then
        box.position = 0
    else
        box.position = 40
    end

    move_box()
    box.visible = true
end

box:connect_signal("button::release", function(box, x, y, btn)
    if btn == 1 then
        box.visible = false
    elseif btn == 3 then
        awful.spawn.easy_async({ "trans", "-speak", text }, function() end)
    elseif btn == 4 or btn == 5 then
        if btn == 4 then
            box.position = box.position + 40
        elseif btn == 5 then
            box.position = box.position - 40
        end

        move_box()
    end
end)

function translate.toggle()
    if box.visible then
        box.visible = false
        return
    end

    text = selection():gsub("'", "'\"'\"'")
    local cmd = ([[
        if trans -id '{text}' | grep Chinese > /dev/null; then
            trans {config} :en '{text}' | sed 's/[^[:print:]\t]\[[0-9]\+m//g'
        else
            trans {config} :zh-TW '{text}' | sed 's/[^[:print:]\t]\[[0-9]\+m//g'
        fi
    ]]):gsub("{([^}]*)}", {
        ["config"] = translator_config,
        ["text"]   = text
    })

    show_box("Translating ")

    awful.spawn.easy_async_with_shell(cmd, function(stdout, stderr)
        if stdout and #stdout > 0 then
            show_box(stdout)
        else
            show_box("Translator Error: " .. stderr)
        end
    end)
end

return translate

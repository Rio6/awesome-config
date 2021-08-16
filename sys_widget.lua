local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")

local path_input = io.popen("sh -c 'echo /sys/devices/platform/coretemp.0/hwmon/hwmon[0-9]/temp1_input'")
local temp_path = path_input:read("*line")
path_input:close()

local widgets = {}

local oldcpu = {}
local function sys_usage()
    local usages = {}

    -- cpu
    local stat = io.open("/proc/stat", "r")
    for i in stat:lines() do
        local x, newcpu = 0, {}
        for j in string.gmatch(i, "%d+") do
            newcpu[x] = j
            x = x + 1
        end
        if not oldcpu[0] then oldcpu[0], oldcpu[2], oldcpu[3] = 0, 0, 0 end
        usages.cpu = ((oldcpu[0] + oldcpu[2]) - (newcpu[0] + newcpu[2])) * 100 / ((oldcpu[0] + oldcpu[2] + oldcpu[3] ) - (newcpu[0] + newcpu[2] + newcpu[3]))
        oldcpu[0], oldcpu[2], oldcpu[3] = newcpu[0], newcpu[2], newcpu[3]
        break
    end
    stat:close()

    -- memory / swap
    local meminfo = io.open("/proc/meminfo", "r")
    local memtotal, memfree, swaptotal, swapfree
    for line in meminfo:lines() do
        local num = line:match("%d+")
        if line:match("^MemTotal") then
            memtotal = num
        elseif line:match("^MemAvailable") then
            memfree = num
        elseif line:match("^SwapTotal") then
            swaptotal = num
        elseif line:match("^SwapFree") then
            swapfree = num
        end
    end
    meminfo:close()

    usages.memory = (1 - memfree / memtotal) * 100
    usages.swap = (1 - swapfree / swaptotal) * 100

    -- temperature
    local temp_input = io.open(temp_path, "r")
    usages.temp = tonumber(temp_input:read("*number") or 0) / 1000
    temp_input:close()

    return usages
end

local function sys_widget(name)
    local disp = { cpu = "", memory = "", swap = "", temp = "" }

    local widget = {
        name = name,
        graph = wibox.widget {
            widget = wibox.widget.graph,
            max_value = 100,
            color = beautiful.bg_graph,
            background_color = beautiful.bg_dark,
            border_color = beautiful.bg_normal,
            step_width = 2,
            step_spacing = 1,
        },
        text = wibox.widget {
            widget = wibox.widget.textbox,
            font = beautiful.font_large,
            fg_color = beautiful.fg_focus,
            align = "center",
            opacity = 0.8
        },
        update = function(self, value)
            self.graph:add_value(value)
            self.text:set_markup(string.format('%s %3.2f', disp[name], value))
        end
    }

    table.insert(widgets, widget)

    return wibox.widget {
        layout = wibox.layout.stack,
        widget.graph,
        widget.text,
    }
end

local function update()
    local usage = sys_usage()
    for _,widget in ipairs(widgets) do
        widget:update(usage[widget.name])
    end
    return true
end

gears.timer.start_new(1, update)

return sys_widget

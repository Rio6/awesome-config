local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")

local widgets = {}
local nets = {}

-- network speed
local function update_speed(nic)

    for _,dir in ipairs{"tx", "rx"} do

        local file = io.open("/sys/class/net/" .. nic .. "/statistics/" .. dir .. "_bytes", "r")
        local newnet = file:read("*number")
        file:close()

        if not nets[nic].old[dir] then
            nets[nic].old[dir] = newnet
        end

        nets[nic].speed[dir] = (newnet - nets[nic].old[dir]) / 1024
        nets[nic].old[dir] = newnet
    end
end

local function net_widget(nics, dir)
    local disp = { rx = "", tx = "" }

    if type(nics) ~= "table" then
        nics = { nics }
    end

    local widget = {
        nics = nics,
        dir = dir,
        graph = wibox.widget {
            widget = wibox.widget.graph,
            scale = true,
            color = beautiful.bg_graph,
            border_width = 2,
            background_color = beautiful.bg_dark,
            border_color = beautiful.bg_normal,
            step_width = 2,
            step_spacing = 1,
        },
        text = wibox.widget {
            widget = wibox.widget.textbox,
            font = beautiful.font_large,
            align = "center",
            opacity = 0.8
        },
        update = function(self)
            local speed = 0
            for _,nic in ipairs(self.nics) do
                speed = speed + nets[nic].speed[self.dir]
            end

            self.graph:add_value(speed)
            if speed < 1000 then
                self.text:set_markup(string.format('%s %.1f', disp[self.dir], speed))
            else
                self.text:set_markup(string.format('%s %.0f', disp[self.dir], speed))
            end
        end
    }

    table.insert(widgets, widget)
    for _,nic in ipairs(nics) do
        nets[nic] = {
            old = {},
            speed = {}
        }
    end

    return wibox.widget {
        layout = wibox.layout.stack,
        widget.graph,
        {
            widget = wibox.container.constraint,
            strategy = "min",
            width = 110,
            widget.text,
        }
    }
end

local function update()
    for nic,_ in pairs(nets) do
        update_speed(nic)
    end
    for _,widget in ipairs(widgets) do
        widget:update()
    end
    return true
end

gears.timer.start_new(1, update)

return net_widget

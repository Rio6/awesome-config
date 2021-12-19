local awful = require("awful")
local gears = require("gears")

local multitime = 0.5
local longtime = 1

local function try(f, ...)
    if f then
        local success, ret = pcall(f, ...)
        if not success then
            print(ret)
        end
        return ret
    end
    return nil
end

return {
    register = function(key, multipress, longpress)
        local count = 0
        local pressed = false
        local timer = gears.timer.new()

        timer:connect_signal("timeout", function()
            if pressed then
                try(longpress, key, count)
            else
                try(multipress, key, count)
            end
            count = 0
            timer:stop()
        end)

        return awful.key({}, key,
            function()
                if pressed then return end
                count = count + 1
                pressed = true
                timer.timeout = longtime
                timer:again()
            end,
            function()
                if not pressed then return end
                pressed = nil
                if not count then return end
                timer.timeout = multitime
                timer:again()
            end
        )
    end
}

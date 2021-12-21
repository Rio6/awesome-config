local awful = require("awful")
local gears = require("gears")

local multitime = 0.3
local longtime = 0.6
local shorttime = 0.3

local alias = {
    Power = "XF86PowerOff",
    Up = "XF86AudioRaiseVolume",
    Down = "XF86AudioLowerVolume",
}

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

local function unalias(v)
    return alias[v] or v
end

local function list_to_string(list)
    local string = ""
    local last = nil
    for i, v in ipairs(list) do
        if type(v) == "number" then
            if not last then error("First key can't be a number") end
            for _ = 1, v do
                string = string .. last
            end
        else
            last = unalias(v)
            string = string .. last
        end
    end
    return string
end

--[[
{
    {"XF86AudioRaiseVolume", 2, "XF86PowerOff"}, function(duration, keys)
    end,
}
--]]
return function(handlers)
    local timer = gears.timer.new()
    local keyseq = {}
    local pressed = nil
    local count = 0

    timer:connect_signal("timeout", function()
        if pressed then
            count = count + 1
            local ret = try(handlers[list_to_string(keyseq)], count, keyseq)
            if ret then
                timer.timeout = shorttime
                timer:again()
                return
            end
        else
            try(handlers[list_to_string(keyseq)], count, keyseq)
        end

        keyseq = {}
        timer:stop()
    end)

    local function press(key)
        return function()
            if pressed == key then return end
            pressed = key
            count = 0
            table.insert(keyseq, key)
            timer.timeout = longtime
            timer:again()
        end
    end

    local function release(key)
        return function()
            if pressed ~= key then return end
            pressed = nil
            if count > 0 then return end
            timer.timeout = multitime
            timer:again()
        end
    end

    local haskey = {}
    local keys = {}
    for i, handler in ipairs(handlers) do
        for _, k in ipairs(handler[1]) do
            if type(k) == "string" then
                k = unalias(k)
                if not haskey[k] then
                    haskey[k] = true
                    gears.table.merge(keys, awful.key({}, k, press(k), release(k)))
                end
            end
        end
        handlers[list_to_string(handler[1])] = handler[2]
        handlers[i] = nil
    end
    return keys
end

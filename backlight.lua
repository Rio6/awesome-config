local backlight = {}

backlight.path = "/sys/class/backlight/intel_backlight"

local function clamp(num, min, max)
    return math.min(math.max(num, min), max)
end

local function read_num(name)
    local file = io.open(backlight.path .. "/" .. name)
    local content = file:read("*number")
    file:close()
    return content
end

local function write_num(name, value)
    local file = io.open(backlight.path .. "/" .. name, "w")
    file:write(tostring(math.floor(value)))
    file:close()
end

function backlight.get()
    local max = read_num("max_brightness")
    local current = read_num("brightness")
    return current / max
end

function backlight.set(value)
    local max = read_num("max_brightness")
    local b = clamp(value, 0, 1) * max
    write_num("brightness", b)
end

function backlight.inc(v)
    backlight.set(backlight.get() + v)
end

return backlight

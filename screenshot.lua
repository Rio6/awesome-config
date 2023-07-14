local awful = require("awful")

local function screenshot_with_option(opt)
    if opt == nil then opt = "" end
    awful.spawn.with_shell("maim "
        .. opt
        .. " | tee "
        .. os.getenv("HOME")
        .. "/tmp/" .. os.date("%Y-%m-%d-%H%M%S") .. ".png"
        .. " | xclip -t image/png -selection clipboard"
    )
end

return {
    all = function()
        screenshot_with_option()
    end,
    screen = function()
        local g = awful.screen.focused().geometry
        screenshot_with_option(string.format("-g %dx%d+%d+%d", g.width, g.height, g.x, g.y))
    end,
    select = function()
        screenshot_with_option("-s")
    end,
}

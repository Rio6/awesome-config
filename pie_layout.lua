local base = require("wibox.widget.base")
local background = require("wibox.container.background")
local grid = require("wibox.layout.grid")
local matrix = require("gears.matrix")
local gtable = require("gears.table")
local shape = require("gears.shape")
local tau = math.pi * 2

local pie = { mt = {} }

local properties = {
    "radius",
    "arc",
    "rotation",
}

for _, prop in ipairs(properties) do
    if not grid["set_" .. prop] then
        grid["set_"..prop] = function(self, value)
            if self._private[prop] ~= value then
                self._private[prop] = value
                self:emit_signal("widget::layout_changed")
            end
        end
    end
    if not grid["get_" .. prop] then
        grid["get_"..prop] = function(self)
            return self._private[prop]
        end
    end
end

local function triangle_base(r, th)
    return math.sqrt(2 * r^2 - 2 * r^2 * math.cos(th * tau))
end

function pie:layout(ctx, width, height)
    local result = {}

    local arc, rotation, radius = self._private.arc, self._private.rotation, self._private.radius
    local num_rows, num_cols = self._private.num_rows, self._private.num_cols

    local ncol = {}
    for i = 1, num_rows do
        ncol[i] = 0
    end

    for _, v in pairs(self._private.widgets) do
        local m = matrix.identity
        local r = v.row / num_rows * radius
        local th = v.row_span / num_cols * arc
        local w = triangle_base(r, th)
        local h = radius / num_rows

        local rot = (ncol[v.row] - 1) / num_cols * arc + rotation
        ncol[v.row] = ncol[v.row] + 1

        m = m:translate(width / 2, height / 2)
        m = m:rotate(-rot * tau)
        m = m:translate(-w / 2, -r)

        v.widget:set_shape(shape.transform(function(cr, w, h)
            return shape.arc(cr, r * 2, r * 2, radius / num_rows, (-1/4 - th / 2) * tau, (-1/4 + th / 2) * tau)
        end):translate(w / 2 - r, 0))

        table.insert(result, base.place_widget_via_matrix(v.widget, m, w, h))
    end

    return result
end

function pie:fit(ctx, width, height)
    self._private.radius = math.min(width, height) / 2
    return width, height
end

function pie:add_widget_at(widget, ...)
    return grid.add_widget_at(self, base.make_widget_declarative {
        widget = background,
        shape_clip = true,
        widget,
    }, ...)
end

function pie.new()
    local widget = grid("vertical")

    gtable.crush(widget, pie, true)

    widget._private.radius = 100
    widget._private.arc = 0.25
    widget._private.rotation = 0

    return widget
end

function pie.mt:__call(...)
    return pie.new(...)
end

return setmetatable(pie, pie.mt)

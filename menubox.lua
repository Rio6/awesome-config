---------------------------------------------------------------------------
--- Menubox module, which aims to provide a freedesktop menu alternative
--
-- @author Alexander Yakushev &lt;yakushev.alex@gmail.com&gt;
-- @copyright 2011-2012 Alexander Yakushev
-- @module menubox
---------------------------------------------------------------------------
-- Rio: Modified so it's a box not a bar, and enable mouse support

-- Grab environment we need
local capi = {
    client = client,
    mouse = mouse,
    screen = screen
}
local gmath = require("gears.math")
local awful = require("awful")
local gfs = require("gears.filesystem")
local common = require("awful.widget.common")
local theme = require("beautiful")
local wibox = require("wibox")
local gcolor = require("gears.color")
local gstring = require("gears.string")
local gdebug = require("gears.debug")
local cairo = require("lgi").cairo
local beautiful = require("beautiful")

local function get_screen(s)
    return s and capi.screen[s]
end

-- menubox
local menubox = { menu_entries = {} }
menubox.menu_gen = require("menubar.menu_gen")
menubox.utils = require("menubar.utils")
local compute_text_width = menubox.utils.compute_text_width

-- Options section
menubox.cache_entries = true
menubox.show_categories = false
menubox.geometry = { width = 600, height = 400, }
menubox.prompt_args = {}
menubox.unknown_icon = gcolor.recolor_image(gfs.get_configuration_dir() .. "/unknown.png", beautiful.fg_dim)
menubox.item_height = 40
menubox.widget_template = {
    id = "background_role",
    widget = wibox.container.background,
    {
        layout = wibox.layout.align.horizontal,
        {
            widget = wibox.container.constraint,
            strategy = "max",
            height = menubox.item_height,
            {
                id = "icon_role",
                widget = wibox.widget.imagebox,
            }
        },
        {
            id = "text_role",
            widget = wibox.widget.textbox,
        }
    }
}

-- Private section
local current_item = 1
local previous_item = nil
local current_category = nil
local shownitems = nil
local instance = nil

local common_args = { w = wibox.layout.fixed.vertical(),
                      data = setmetatable({}, { __mode = 'kv' }) }

--- Wrap the text with the color span tag.
-- @param s The text.
-- @param c The desired text color.
-- @return the text wrapped in a span tag.
local function colortext(s, c)
    return "<span color='" .. gcolor.ensure_pango_color(c) .. "'>" .. s .. "</span>"
end

--- Get how the menu item should be displayed.
-- @param o The menu item.
-- @return item name, item background color, background image, item icon.
local function label(o)
    local fg_color = theme.menubox_fg_normal or theme.menu_fg_normal or theme.fg_normal
    local bg_color = theme.menubox_bg_normal or theme.menu_bg_normal or theme.bg_normal
    if o.focused then
        fg_color = theme.menubox_fg_focus or theme.menu_fg_focus or theme.fg_focus
        bg_color = theme.menubox_bg_focus or theme.menu_bg_focus or theme.bg_focus
    end
    return colortext(gstring.xml_escape(o.name), fg_color),
           bg_color,
           nil,
           o.icon or menubox.unknown_icon
end

local function load_count_table()
    if instance.count_table then
        return instance.count_table
    end
    instance.count_table = {}
    local count_file_name = gfs.get_cache_dir() .. "/menu_count_file"
    local count_file = io.open (count_file_name, "r")
    if count_file then
        for line in count_file:lines() do
            local name, count = string.match(line, "([^;]+);([^;]+)")
            if name ~= nil and count ~= nil then
                instance.count_table[name] = count
            end
        end
        count_file:close()
    end
    return instance.count_table
end

local function write_count_table(count_table)
    count_table = count_table or instance.count_table
    local count_file_name = gfs.get_cache_dir() .. "/menu_count_file"
    local count_file = assert(io.open(count_file_name, "w"))
    for name, count in pairs(count_table) do
        local str = string.format("%s;%d\n", name, count)
        count_file:write(str)
    end
    count_file:close()
end

--- Perform an action for the given menu item.
-- @param o The menu item.
-- @return if the function processed the callback, new awful.prompt command, new awful.prompt prompt text.
local function perform_action(o)
    if not o then return end
    if o.key then
        current_category = o.key
        local new_prompt = shownitems[current_item].name .. ": "
        previous_item = current_item
        current_item = 1
        return true, "", new_prompt
    elseif shownitems[current_item].cmdline then
        awful.spawn(shownitems[current_item].cmdline, {
           tag = mouse.screen.selected_tag
        })
        -- load count_table from cache file
        local count_table = load_count_table()
        -- increase count
        local curname = shownitems[current_item].name
        count_table[curname] = (count_table[curname] or 0) + 1
        -- write updated count table to cache file
        write_count_table(count_table)
        -- Let awful.prompt execute dummy exec_callback and
        -- done_callback to stop the keygrabber properly.
        return false
    end
end

-- Cut item list to return only current page.
-- @tparam table all_items All items list.
-- @tparam str query Search query.
-- @tparam number|screen scr Screen
-- @return table List of items for current page.
local function get_current_page(all_items, query, scr)
    local available_space = instance.geometry.height - beautiful.xresources.apply_dpi(20)
    local height_sum = 0
    local current_page = {}
    for i, item in ipairs(all_items) do
        local item_height = item.height or menubox.item_height
        if height_sum + item_height > available_space then
            if current_item < i then
                break
            end
            current_page = { item }
            height_sum = item_height
        else
            table.insert(current_page, item)
            height_sum = height_sum + item_height
        end
    end
    return current_page
end

--- Update the menubox according to the command entered by user.
-- @tparam number|screen scr Screen
local function menulist_update(scr)
    local query = instance.query or ""
    shownitems = {}
    local pattern = gstring.query_to_pattern(query)

    -- All entries are added to a list that will be sorted
    -- according to the priority (first) and weight (second) of its
    -- entries.
    -- If categories are used in the menu, we add the entries matching
    -- the current query with high priority as to ensure they are
    -- displayed first. Afterwards the non-category entries are added.
    -- All entries are weighted according to the number of times they
    -- have been executed previously (stored in count_table).
    local count_table = load_count_table()
    local command_list = {}

    local PRIO_NONE = 0
    local PRIO_CATEGORY_MATCH = 2

    -- Add the categories
    if menubox.show_categories then
        for _, v in pairs(menubox.menu_gen.all_categories) do
            v.focused = false
            if not current_category and v.use then

                -- check if current query matches a category
                if string.match(v.name, pattern) then

                    v.weight = 0
                    v.prio = PRIO_CATEGORY_MATCH

                    -- get use count from count_table if present
                    -- and use it as weight
                    if string.len(pattern) > 0 and count_table[v.name] ~= nil then
                        v.weight = tonumber(count_table[v.name])
                    end

                    -- check for prefix match
                    if string.match(v.name, "^" .. pattern) then
                        -- increase default priority
                        v.prio = PRIO_CATEGORY_MATCH + 1
                    else
                        v.prio = PRIO_CATEGORY_MATCH
                    end

                    table.insert (command_list, v)
                end
            end
        end
    end

    -- Add the applications according to their name and cmdline
    for _, v in ipairs(menubox.menu_entries) do
        v.focused = false
        if not current_category or v.category == current_category then

            -- check if the query matches either the name or the commandline
            -- of some entry
            if string.match(v.name, pattern)
                or string.match(v.cmdline, pattern) then

                v.weight = 0
                v.prio = PRIO_NONE

                -- get use count from count_table if present
                -- and use it as weight
                if string.len(pattern) > 0 and count_table[v.name] ~= nil then
                    v.weight = tonumber(count_table[v.name])
                end

                -- check for prefix match
                if string.match(v.name, "^" .. pattern)
                    or string.match(v.cmdline, "^" .. pattern) then
                    -- increase default priority
                    v.prio = PRIO_NONE + 1
                else
                    v.prio = PRIO_NONE
                end

                table.insert (command_list, v)
            end
        end
    end

    local function compare_counts(a, b)
        if a.prio == b.prio then
            return a.weight > b.weight
        end
        return a.prio > b.prio
    end

    -- sort command_list by weight (highest first)
    table.sort(command_list, compare_counts)
    -- copy into showitems
    shownitems = command_list

    -- Insert a run item value as the last choice
    table.insert(shownitems, { name = "Exec: " .. query, cmdline = query, icon = nil })

    if #shownitems > 0 then
        if current_item > #shownitems then
            current_item = #shownitems
        end
        shownitems[current_item].focused = true
    end

    common.list_update(common_args.w, nil, label,
                       common_args.data,
                       get_current_page(shownitems, query, scr),
                       { widget_template = menubox.widget_template} )
end


menubox.widget_template.create_callback = function(w, _, i)
    w:connect_signal("mouse::enter", function()
        current_item = i
        menulist_update()
    end)

    w:connect_signal("button::press", function(w, lx, ly, btn)
        if btn == 1 then
            perform_action(shownitems[current_item])
            menubox.hide()
        end
    end)
end

--- Refresh menubox's cache by reloading .desktop files.
-- @tparam[opt] screen scr Screen.
function menubox.refresh(scr)
    scr = get_screen(scr or awful.screen.focused() or 1)
    menubox.menu_gen.generate(function(entries)
        menubox.menu_entries = entries
        if instance then
            menulist_update(scr)
        end
    end)
end

--- Awful.prompt keypressed callback to be used when the user presses a key.
-- @param mod Table of key combination modifiers (Control, Shift).
-- @param key The key that was pressed.
-- @param comm The current command in the prompt.
-- @return if the function processed the callback, new awful.prompt command, new awful.prompt prompt text.
local function prompt_keypressed_callback(mod, key, comm)
    if key == "Up" or (mod.Control and key == "k") or key == "XF86AudioRaiseVolume" then
        current_item = (current_item - 2 + #shownitems) % #shownitems + 1
        return true
    elseif key == "Down" or (mod.Control and key == "j") or key == "XF86AudioLowerVolume" then
        current_item = (current_item) % #shownitems + 1
        return true
    elseif key == "BackSpace" then
        if comm == "" and current_category then
            current_category = nil
            current_item = previous_item
            return true, nil, ""
        end
    elseif key == "Escape" then
        if current_category then
            current_category = nil
            current_item = previous_item
            return true, nil, ""
        end
    elseif key == "Home" then
        current_item = 1
        return true
    elseif key == "End" then
        current_item = #shownitems
        return true
    elseif key == "Return" or key == "KP_Enter" or key == "XF86PowerOff" then
        if mod.Control then
            current_item = #shownitems
            if mod.Mod1 then
                -- add a terminal to the cmdline
                shownitems[current_item].cmdline = menubox.utils.terminal
                        .. " -e " .. shownitems[current_item].cmdline
            end
        end
        menubox.hide()
        return perform_action(shownitems[current_item])
    end
    return false
end

--- Show the menubox on the given screen.
-- @param[opt] scr Screen.
function menubox.show(scr)
    scr = get_screen(scr or awful.screen.focused() or 1)
    local fg_color = theme.menubox_fg_normal or theme.menu_fg_normal or theme.fg_normal
    local bg_color = theme.menubox_bg_normal or theme.menu_bg_normal or theme.bg_normal
    local border_width = theme.menubox_border_width or theme.menu_border_width or 0
    local border_color = theme.menubox_border_color or theme.menu_border_color

    if not instance then
        -- Add to each category the name of its key in all_categories
        for k, v in pairs(menubox.menu_gen.all_categories) do
            v.key = k
        end

        if menubox.cache_entries then
            menubox.refresh(scr)
        end

        instance = {
            wibox = wibox{
                ontop = true,
                bg = bg_color,
                fg = fg_color,
                border_width = border_width,
                border_color = border_color,
            },
            widget = common_args.w,
            prompt = wibox.widget {
                widget = wibox.widget.textbox,
            },
            query = nil,
            count_table = nil,
        }
        instance.wibox.widget = wibox.widget {
            widget = wibox.container.margin,
            margins = 10,
            {
                layout = wibox.layout.fixed.vertical,
                instance.prompt,
                instance.widget,
            }
        }
    end

    if instance.wibox.visible then -- Menu already shown, exit
        return
    elseif not menubox.cache_entries then
        menubox.refresh(scr)
    end

    -- Set position and size
    local scrgeom = scr.workarea
    local geometry = menubox.geometry
    instance.geometry = {
        width = geometry.width or 600,
        height = geometry.height or 400,
    }
    instance.wibox:geometry(instance.geometry)
    awful.placement.centered(instance.wibox, { parent=scr })

    current_item = 1
    current_category = nil
    menulist_update(scr)

    local prompt_args = menubox.prompt_args or {}

    awful.prompt.run(setmetatable({
        textbox             = instance.prompt,
        font                = beautiful.font_menu,
        completion_callback = awful.completion.shell,
        history_path        = gfs.get_cache_dir() .. "/history_menu",
        done_callback       = menubox.hide,
        changed_callback    = function(query)
            instance.query = query
            menulist_update(scr)
        end,
        keypressed_callback = prompt_keypressed_callback
    }, {__index=prompt_args}))

    instance.wibox.visible = true
end

--- Hide the menubox.
function menubox.hide()
    if instance then
        instance.wibox.visible = false
        instance.query = nil
        awful.keygrabber.stop()
    end
end

local mt = {}
function mt.__call(_, ...)
    return menubox.get(...)
end

return setmetatable(menubox, mt)

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80

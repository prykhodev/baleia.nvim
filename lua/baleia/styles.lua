local ansi = require("baleia.ansi")
local colors = require("baleia.styles.colors")

local styles = {}

local function merge_value(from, to)
	if to.set then
		return to
	end
	return from
end

function styles.merge(from, to)
	local style = {
		foreground = merge_value(from.foreground, to.foreground),
		background = merge_value(from.background, to.background),
		special = merge_value(from.special, to.special),
		offset = to.offset or from.offset,
		modes = {},
	}

	for attr, from_value in pairs(from.modes) do
		style.modes[attr] = from_value
	end

	for attr, to_value in pairs(to.modes) do
		style.modes[attr] = merge_value(from.modes[attr], to_value)
	end

	return style
end

function styles.none()
	local style = {
		foreground = colors.none(),
		background = colors.none(),
		special = colors.none(),
		modes = {},
	}

	for _, mode in pairs(ansi.modes) do
		for attr, definition in ipairs(mode) do
			if style.modes[attr] == nil or style.modes[attr].name > definition.name then
				style.modes[attr] = {
					name = definition.name,
					value = false,
					set = false,
				}
			end
		end
	end

	return style
end

function styles.reset(offset)
	local style = {
		foreground = colors.reset(),
		background = colors.reset(),
		special = colors.reset(),
		offset = offset,
		modes = {},
	}

	for _, mode in pairs(ansi.modes) do
		for attr, definition in ipairs(mode) do
			if style.modes[attr] == nil or style.modes[attr].name > definition.name then
				style.modes[attr] = { set = true, value = false, name = definition.name }
			end
		end
	end

	return style
end

function styles.to_style(ansi_sequence)
	local codes = {}
	for code in ansi_sequence:gmatch("[:0-9]+") do
		table.insert(codes, tonumber(code) or code)
	end

	local style = styles.none()
	local index = 1
	while index <= #codes do
		if codes[index] == 0 then
			style = styles.reset(#ansi_sequence)
		elseif ansi.colors[codes[index]] then
			local entry = ansi.colors[codes[index]]

			if entry.definition then
				for attr, value in pairs(entry.definition) do
					style[attr] = value
				end
			elseif entry.generators then
				local flag = codes[index + 1]
				local generator = entry.generators[flag]

				local params = {}
				for i = 1, generator.params, 1 do
					params[i] = codes[index + 1 + i]
				end

				for attr, fn in pairs(generator.fn) do
					style[attr] = fn(unpack(params))
				end

				-- current index + 1 flag + N parameters
				index = index + 1 + generator.params
			end
		elseif ansi.modes[codes[index]] then
			local mode = ansi.modes[codes[index]]
			for attr, value in pairs(mode.definition) do
				style.modes[attr] = value
			end
		end

		index = index + 1
	end

	style.offset = #ansi_sequence
	return style
end

function styles.name(prefix, style)
	local modename = 0
	for _, value in pairs(style.modes) do
		if value.set then
			modename = bit.bor(modename, value.name)
		end
	end

	return prefix
		.. "_"
		.. modename
		.. "_"
		.. style.foreground.value.name
		.. "_"
		.. style.background.value.name
		.. "_"
		.. style.special.value.name
end

function styles.attributes(style, theme)
	local attributes = {}

	for mode, value in pairs(style.modes) do
		if value.set then
			attributes[mode] = value.value
		end
	end

	if style.foreground.set then
		local color = style.foreground.value
		attributes.ctermfg = colors.cterm(color)
		attributes.foreground = colors.gui(color, theme)
	end

	if style.background.set then
		local color = style.background.value
		attributes.ctermbg = colors.cterm(color)
		attributes.background = colors.gui(color, theme)
	end

	if style.special.set then
		local color = style.special.value
		attributes.special = colors.gui(color, theme)
	end

	return attributes
end

return styles

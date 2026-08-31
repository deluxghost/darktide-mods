local UIRenderer = require("scripts/managers/ui/ui_renderer")

local MASK_CHARACTER = "•"
local OVERFLOW_CHARACTER = "…"

local MaskedTextInput = {}

local function text_width(ui_renderer, text, style)
	local _, _, _, caret_offset = UIRenderer.text_size(ui_renderer, text, style.font_type, style.font_size)

	return caret_offset[1]
end

local function masked_text(first, last, text_length)
	local prefix = first > 1 and OVERFLOW_CHARACTER or ""
	local suffix = last < text_length and OVERFLOW_CHARACTER or ""

	return prefix .. string.rep(MASK_CHARACTER, last - first + 1) .. suffix, prefix
end


local function maximum_mask_count(ui_renderer, style, max_width, text_length)
	local low = 0
	local high = text_length

	while low < high do
		local middle = math.ceil((low + high) * 0.5)
		local candidate = OVERFLOW_CHARACTER .. string.rep(MASK_CHARACTER, middle) .. OVERFLOW_CHARACTER

		if text_width(ui_renderer, candidate, style) <= max_width then
			low = middle
		else
			high = middle - 1
		end
	end

	return low
end

local function masked_input_layout_pass()
	return {
		pass_type = "logic",
		value = function (pass, ui_renderer, ui_style, content, position, size)
			if not content.mask_input then
				if content._mask_input_active then
					content._mask_input_active = nil
					content._input_text = nil
					content.force_caret_update = true
				end

				return
			end

			content._mask_input_active = true

			local input_text = content.input_text or ""
			local text_length = Utf8.string_length(input_text)
			local caret_position = math.clamp(content.caret_position or text_length + 1, 1, text_length + 1)
			local display_style = ui_style.parent.display_text
			local caret_style = ui_style.parent.input_caret
			local max_width = size[1] - 1

			if display_style.size_addition then
				max_width = max_width + display_style.size_addition[1]
			end

			local full_mask = string.rep(MASK_CHARACTER, text_length)

			if text_width(ui_renderer, full_mask, display_style) <= max_width then
				content.display_text = full_mask
				content._input_text_first_visible_pos = 1
				caret_style.offset[1] = display_style.offset[1]
					+ text_width(ui_renderer, string.rep(MASK_CHARACTER, caret_position - 1), display_style)

				return
			end

			local visible_count = maximum_mask_count(ui_renderer, display_style, max_width, text_length)

			if visible_count < 1 then
				content.display_text = OVERFLOW_CHARACTER
				content._input_text_first_visible_pos = caret_position
				caret_style.offset[1] = display_style.offset[1]

				return
			end

			local max_first = math.max(text_length - visible_count + 1, 1)
			local first = math.clamp(content._input_text_first_visible_pos or 1, 1, max_first)

			if caret_position < first then
				first = caret_position
			elseif caret_position > first + visible_count then
				first = caret_position - visible_count
			end

			first = math.clamp(first, 1, max_first)

			local last = first + visible_count - 1
			local display_text = masked_text(first, last, text_length)

			while first == 1 and last < text_length do
				local candidate = masked_text(first, last + 1, text_length)

				if text_width(ui_renderer, candidate, display_style) > max_width then
					break
				end

				last = last + 1
				display_text = candidate
			end

			while last == text_length and first > 1 do
				local candidate = masked_text(first - 1, last, text_length)

				if text_width(ui_renderer, candidate, display_style) > max_width then
					break
				end

				first = first - 1
				display_text = candidate
			end

			local _, prefix = masked_text(first, last, text_length)
			local characters_before_caret = math.clamp(caret_position - first, 0, last - first + 1)
			local text_before_caret = prefix .. string.rep(MASK_CHARACTER, characters_before_caret)

			content.display_text = display_text
			content._input_text_first_visible_pos = first
			caret_style.offset[1] = display_style.offset[1] + text_width(ui_renderer, text_before_caret, display_style)
		end,
	}
end


MaskedTextInput.add_to_passes = function (passes)
	local selection_layout_index

	for i = 1, #passes do
		local pass = passes[i]

		if pass.pass_type == "logic" and pass.visibility_function then
			selection_layout_index = i
		end
	end

	assert(selection_layout_index, "Realms join view could not locate the text selection layout pass")
	table.insert(passes, selection_layout_index, masked_input_layout_pass())
end

return MaskedTextInput

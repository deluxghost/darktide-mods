local ffi = Mods.lua.ffi

local function decode(snapshot)
	local data = ffi.cast("const uint8_t*", snapshot)
	local function word(offset)
		return tonumber(ffi.cast("const uint32_t*", data + offset)[0])
	end
	local function text(offset)
		return ffi.string(data + offset)
	end
	local function read_node(kind, value)
		if kind <= 3 then
			return { kind = kind, value = value }
		elseif kind == 4 then
			return { kind = kind, value = text(value) }
		end

		local children = {}
		if kind == 5 then
			for index = 0, word(value + 4) - 1 do
				children[index + 1] = read_node(word(value), word(value + 8 + index * 4))
			end
		else
			assert(kind == 6, "Unexpected render config node")
			for index = 0, word(value) - 1 do
				local entry = value + 4 + index * 12
				children[text(word(entry))] = read_node(word(entry + 4), word(entry + 8))
			end
		end
		return { kind = kind, value = children }
	end

	return read_node(word(0), word(4))
end

local function encode(root, capacity)
	local data = ffi.new("uint8_t[?]", capacity)
	local cursor = 8
	local strings = {}
	local function word(offset, value)
		ffi.cast("uint32_t*", data + offset)[0] = value
	end
	local function reserve(bytes, alignment)
		local offset = math.ceil(cursor / alignment) * alignment
		cursor = offset + bytes
		assert(cursor <= capacity, "Expanded global render config exceeds its allocation")
		return offset
	end
	local function text(value)
		if strings[value] then
			return strings[value]
		end
		local offset = reserve(#value + 1, 1)
		ffi.copy(data + offset, value, #value)
		strings[value] = offset
		return offset
	end
	local function write_node(node)
		local kind, value = node.kind, node.value
		if kind <= 3 then
			return kind, value
		elseif kind == 4 then
			return kind, text(value)
		elseif kind == 5 then
			local offset = reserve(8 + #value * 4, 4)
			word(offset, #value > 0 and value[1].kind or 0)
			word(offset + 4, #value)
			for index, child in ipairs(value) do
				local child_kind, child_value = write_node(child)
				assert(child_kind == value[1].kind, "Mixed render config array")
				word(offset + 4 + index * 4, child_value)
			end
			return kind, offset
		end

		local keys = {}
		for key in pairs(value) do
			keys[#keys + 1] = key
		end
		table.sort(keys)
		local offset = reserve(4 + #keys * 12, 4)
		word(offset, #keys)
		for index, key in ipairs(keys) do
			local entry = offset + 4 + (index - 1) * 12
			local key_offset = text(key)
			local child_kind, child_value = write_node(value[key])
			word(entry, key_offset)
			word(entry + 4, child_kind)
			word(entry + 8, child_value)
		end
		return kind, offset
	end

	local kind, offset = write_node(root)
	word(0, kind)
	word(4, offset)
	return ffi.string(data, capacity)
end

return { decode = decode, encode = encode }

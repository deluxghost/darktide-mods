local mod = get_mod("GoodOldOutlines")
local Codec = mod:io_dofile("GoodOldOutlines/scripts/mods/GoodOldOutlines/runtime/config_codec")
local MASK_NAME = "goo_outline_mask"
local COMPOSITE_NAME = "goo_outline_composite"
local LAYERS_NAME = "goo_outline_layers"
local LAYERS_PREPARE = "goo_outline_layers_prepare"
local cached_snapshot, cached_layers, cached_bytes, cached_result

local function make_node(value)
	local value_type = type(value)
	if value_type == "string" then
		return { kind = 4, value = value }
	elseif value_type == "number" then
		return { kind = 2, value = value }
	elseif value_type == "boolean" then
		return { kind = 1, value = value and 1 or 0 }
	end

	local result = { kind = #value > 0 and 5 or 6, value = {} }
	for key, child in pairs(value) do
		result.value[key] = make_node(child)
	end
	return result
end

local function has_name(node, name)
	return node.value.name and node.value.name.value == name
end

local function find_transparent_branch(layers)
	local transparent
	for _, layer in ipairs(layers) do
		local pass = layer.value.pass
		if pass and pass.kind == 5 then
			for _, draw in ipairs(pass.value) do
				if has_name(draw, "transparent") then
					assert(not transparent, "Multiple transparent branches")
					transparent = layer.value
				end
			end
		end
	end
	assert(transparent, "Main transparent branch was not found")
	return transparent
end

local function patch_transparent_branch(branch_name, passes, mask, layers)
	for _, draw in ipairs(passes) do
		if has_name(draw, "transparent") then
			assert(#draw.value.render_targets.value == 1, "Transparent target layout changed")
			if mask then
				table.insert(draw.value.render_targets.value, make_node(MASK_NAME))
			end
		end
	end
	-- Retain pass indices: live draw batches refer to the existing layer layout.
	local allocation = passes[1]
	local final = passes[5]
	if layers then
		allocation.value.resource_generator = make_node(LAYERS_PREPARE)
		allocation.value.output = make_node({ [LAYERS_NAME] = LAYERS_NAME })
	end
	if branch_name == "fail" then
		local copy = passes[4]
		assert(has_name(passes[1], "dummy_alloc_temp") and has_name(copy, "dummy_copy_premultiply"), "Transparent pass layout changed")
		if mask then
			allocation.value.allocate = { kind = 5, value = { mask } }
			allocation.value.clear_flags = make_node({ "SURFACE" })
			allocation.value.render_targets = make_node({ MASK_NAME })
			final.value.deallocate = make_node({ MASK_NAME })
		end
		copy.value.resource_generator = make_node(COMPOSITE_NAME)
		return
	end
	assert(allocation.value.allocate and final.value.deallocate, "Upscaled transparent layout changed")
	if mask then
		table.insert(allocation.value.allocate.value, mask)
		table.insert(final.value.deallocate.value, make_node(MASK_NAME))
	end
	final.value.resource_generator = make_node(COMPOSITE_NAME)
end

local function prepare(snapshot, layers, buffer_bytes)
	if snapshot == cached_snapshot and layers == cached_layers and buffer_bytes == cached_bytes then
		return cached_result
	end
	local root = Codec.decode(snapshot)
	local settings = root.value
	local transparent = find_transparent_branch(settings.layer_configs.value.default.value)
	assert(not settings.resource_generators.value[COMPOSITE_NAME], "Global outline pass already exists")
	local mask = not layers and make_node({
		depends_on = "output_rt",
		format = "R32G32B32A32F",
		name = MASK_NAME,
		type = "render_target",
		clear_color = { 4096, 4096, 4096, 4096 },
	})
	for _, branch_name in ipairs({ "pass", "fail" }) do
		patch_transparent_branch(branch_name, transparent[branch_name].value, mask, layers)
	end
	if layers then
		settings.resource_generators.value[LAYERS_PREPARE] = make_node({
			modifiers = {
				{ type = "particle_lighting_atlas_counter", buffer_name = LAYERS_NAME,
					buffer_size = buffer_bytes, clear = true },
				{ type = "resource_barrier", actions = { { uav = { LAYERS_NAME } }, { flush = true } } },
			},
		})
	end
	settings.resource_generators.value[COMPOSITE_NAME] = make_node({
		modifiers = {
			{
				input = { layers and LAYERS_NAME or MASK_NAME },
				output = { "ldr0" },
				shader = "signed_distance_field_2d:VERTICAL_PASS",
				type = "fullscreen_pass",
				profiling_scope = "goo.sdf_outline",
			},
		},
	})
	if layers then
		table.insert(settings.resource_generators.value[COMPOSITE_NAME].value.modifiers.value, 1,
			make_node({ type = "resource_barrier", actions = { { uav = { LAYERS_NAME } }, { flush = true } } }))
		table.insert(settings.resource_generators.value[COMPOSITE_NAME].value.modifiers.value,
			make_node({ type = "resource_barrier", actions = {
				{ queue = "graphics", states = { "copy_source" }, transition = { LAYERS_NAME } },
				{ flush = true, queue = "graphics" },
			} }))
	end
	local result = Codec.encode(root, #snapshot)
	cached_snapshot, cached_layers, cached_bytes, cached_result = snapshot, layers, buffer_bytes, result
	return result
end

return { prepare = prepare }

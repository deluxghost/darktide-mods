local Outline = {}

local function set_layers(unit, layers, enabled)
	for _, layer in ipairs(layers) do
		Unit.set_material_layer(unit, layer, enabled)
	end
end

function Outline.sync(visuals, extensions)
	for parent, record in pairs(visuals) do
		local extension = extensions[parent]
		local wanted = not record.exploded and extension and extension.visible_material_layers or nil
		local previous = record.outline_layers
		if wanted ~= previous then
			if previous then set_layers(record.unit, previous, false) end
			if wanted then set_layers(record.unit, wanted, true) end
			Unit.set_unit_culling(record.unit, wanted == nil, true)
			record.outline_layers = wanted
			record.outline_color = nil
		end
		local color = wanted and extension.outlines[1].color
		local cached = record.outline_color
		if color and (not cached or color[1] ~= cached[1] or color[2] ~= cached[2] or color[3] ~= cached[3]) then
			local vector = Vector3(color[1], color[2], color[3])
			for _, layer in ipairs(wanted) do
				Unit.set_vector3_for_material(record.unit, layer, "outline_color", vector)
			end
			record.outline_color = { color[1], color[2], color[3] }
		end
	end
end

return Outline

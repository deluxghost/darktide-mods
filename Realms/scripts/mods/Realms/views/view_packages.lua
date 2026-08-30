local shared = {
	"packages/ui/views/inventory_background_view/inventory_background_view",
}

local by_view = {
	join = {},
	preparation = {
		"packages/ui/hud/mission_objective_feed/mission_objective_feed",
		"packages/ui/views/lobby_view/lobby_view",
		"packages/ui/views/loading_view/loading_view",
		"packages/ui/views/loading_view/loading_screen_background",
		"packages/ui/views/mission_intro_view/mission_intro_view",
		"packages/ui/views/mission_voting_view/mission_voting_view",
		"packages/ui/views/talent_builder_view/talent_builder_view",
	},
}

local ViewPackages = {}

local function append_unique(target, seen, source)
	for i = 1, #source do
		local package_name = source[i]

		if not seen[package_name] then
			seen[package_name] = true
			target[#target + 1] = package_name
		end
	end
end

function ViewPackages.for_view(view_name)
	local packages = {}
	local seen = {}

	append_unique(packages, seen, shared)
	append_unique(packages, seen, by_view[view_name])

	return packages
end

function ViewPackages.all()
	local packages = {}
	local seen = {}

	append_unique(packages, seen, shared)
	append_unique(packages, seen, by_view.join)
	append_unique(packages, seen, by_view.preparation)

	return packages
end

return ViewPackages

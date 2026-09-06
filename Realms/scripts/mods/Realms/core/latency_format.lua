return function (latency)
	if type(latency) ~= "number" then
		return "—"
	end
	if latency >= 1000 then
		return "999+ms"
	end

	return tostring(latency) .. "ms"
end

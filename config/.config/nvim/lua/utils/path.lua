local path = {}

function path.splitPath(path)
	local parts = {}
	for part in path:gmatch("[^/]+") do
		table.insert(parts, part)
	end
	return parts
end

function path.makeRelative(path1, path2)
	local parts1 = path.splitPath(path1)
	local parts2 = path.splitPath(path2)

	-- Remove common leading parts
	while #parts1 > 0 and #parts2 > 0 and parts1[1] == parts2[1] do
		table.remove(parts1, 1)
		table.remove(parts2, 1)
	end

	-- Construct the relative path
	local relativePath = ""
	for _ = 1, #parts1 do
		relativePath = relativePath .. "../"
	end
	relativePath = relativePath .. table.concat(parts2, "/")

	if #parts1 == 0 and #parts2 == 1 then
		relativePath = "./" .. relativePath
	end

	return relativePath
end

return path

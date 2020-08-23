function SeemsLikeValidMissionJSON(missionJson)
	-- A very simple sanity check to see if the string provided begins with "{" and ends with "}"
	return (type(missionJson) == "string" and string.sub(missionJson, 1, 1) == "{" and string.sub(missionJson, -1, -1) == "}")
end

function IsValidUGC(ugc)
	-- A very simple sanity check to see if the flag we set is there, 
	return (type(ugc) == "table" and ugc.__IsValidUGC)
end

--[[
	MissionJSON rules:
	1: Objects cannot contain the keys "x", "y" or "z" in which case they are Vector3 data

	From this, a logical process for determining the type of an object or array can be found.
	Simply check if you contain the key "x", if you do, you're a Vector3!
]]

local TraverseMissionJSON -- Forward Declaration

-- This function assumes me is a value which can be passed to pairs()
TraverseMissionJSON = function(me)
	if me.x then
		-- If I contain the key "x" then I am Vector3 data
		return vec3(me.x, me.y, me.z)
	else
		for k,v in pairs(me) do
			if type(v) == "table" then
				me[k] = TraverseMissionJSON(v)
			end
		end

		return me
	end
end

function ParseMissionJSON(missionJson)
	local output
	local success, err = pcall(function()
		output = TraverseMissionJSON(json.decode(missionJson))
	end)

	if type(output) == "table" then
		output.__IsValidUGC = success
	end

	return success and output, err
end

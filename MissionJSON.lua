function SeemsLikeValidMissionJSON(missionJson)
	-- A very simple sanity check to see if the string provided begins with "{" and ends with "}"
	return (type(missionJson) == "string" and string.sub(missionJson, 1, 1) == "{" and string.sub(missionJson, -1, -1) == "}")
end

function ParseMissionJSON(missionJson)
	-- I haven't been bothered with the custom vector parsing as of now, this is just a streight json.decode()
	return json.decode(missionJson)
end
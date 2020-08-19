local hasAnyUGCDirectives = false
local foundMapDirectiveData = false
local mapDirectiveDataType = false

AddEventHandler("onMapStart", function(mapName)
	-- Save the name of the current resource as we can't get it from getMapDirectives
	-- We'll do it in GlobalState as it may be useful! (and exports are meh)
	GlobalState.CurrentMap = mapName

	-- So that connected clients don't go to load things just right now, we'll set a variable for them to poll
	GlobalState.CurrentMapMissionJSONChecked = false
end)

-- Map directive stuff
AddEventHandler('getMapDirectives', function(add)
	-- Refresh the map directive state storage stuff
	hasAnyUGCDirectives = false
	foundMapDirectiveData = false
	mapDirectiveDataType = false

	-- Raw MissionJSON right in the map.lua file
	add('missionjson', function(state, jsonString)
		-- Only accept one of any type
		if hasAnyUGCDirectives then return end

		-- This directive can only be a string and has to seem like valid JSON
		if type(jsonString) ~= "string" and SeemsLikeValidMissionJSON(jsonString) then return end

		-- This is directly a MissionJSON string (or at least it should be...) so this is what we use as the map.
		foundMapDirectiveData = jsonString
		mapDirectiveDataType = "raw"
		hasAnyUGCDirectives = true
    end, function()
        -- We actually don't need to delete anything from state as thats handled when maps are loaded...
	end)

	-- A file name pointing to a file containing MissionJSON
	add('missionjson_file', function(state, filename)
		-- Only accept one of any type
		if hasAnyUGCDirectives then return end

		-- This directive can only be a string
		if type(filename) ~= "string" then return end

		-- We need to process the file somewhere else otherwise we'll cause resource warnings on mapmanager
		foundMapDirectiveData = filename
		mapDirectiveDataType = "resourcefile"
		hasAnyUGCDirectives = true
	end, function() end)
	
	-- A (cacheable) URL pointing to MissionJSON (probably a rockstar URL)
	add('missionjson_url', function(state, url)
		-- Only accept one of any type
		if hasAnyUGCDirectives then return end

		-- This directive can only be a string
		if type(url) ~= "string" then return end
		
		-- We need to process the url somewhere else otherwise we'll cause resource warnings on mapmanager
		foundMapDirectiveData = url
		mapDirectiveDataType = "url"
		hasAnyUGCDirectives = true
	end, function() end)

	-- The surrogate resource for whatever the outcome of the map voting was if it wasn't a discrete resource, usually a (cached) rockstar URL
	add('missionjson_surrogate', function(state, acknowledgement)
		-- Only accept one of any type
		if hasAnyUGCDirectives then return end
		
		-- Stop stupid people from being stupid
		if acknowledgement ~= "Yes, I understand that surrogate maps are only used by jaymo's racing gamemode and that I can't just make my own because that's not the purpose of a surrogate map." then return end
		
		-- Processed as part of the surrogate map start
		mapDirectiveDataType = "surrogate"
		hasAnyUGCDirectives = true
	end, function() end)
end)

AddEventHandler("onServerResourceStart", function(resourceName)
	-- Only do anything when the current map is the resource given
	if resourceName ~= GlobalState.CurrentMap then return end

	-- Once we've processed directives, get our MissionJSON string and update the GlobalState for clients to have fun with (om nom nom)
	if hasAnyUGCDirectives then
		local ok = true

		-- Process whatever data we got depending on the directive type
		if mapDirectiveDataType == "raw" and foundMapDirectiveData then
			-- The easiest type to deal with, just chuck it on GlobalState and it can cause errors if whoever set the map up was stupid.
			GlobalState.CurrentMapMissionJSON = foundMapDirectiveData
		elseif mapDirectiveDataType == "resourcefile" and foundMapDirectiveData then
			-- Seeing as we have the resource name, it's trivial to just grab the file.
			local fileContent = LoadResourceFile(resourceName, foundMapDirectiveData)

			-- If the file is empty or there wasn't a file to begin with, something went wrong.
			if fileContent ~= nil and fileContent ~= "" then 
				GlobalState.CurrentMapMissionJSON = fileContent
			else
				ok = false 
			end
		elseif mapDirectiveDataType == "url" and foundMapDirectiveData then
			-- We have a nice little function to get and cache URLs so we'll just call that.
			local urlContent = GetUGCURLContent(foundMapDirectiveData)

			if urlContent then
				GlobalState.CurrentMapMissionJSON = urlContent
			else
				ok = false
			end
		elseif mapDirectiveDataType == "surrogate" then
			-- This is the same as a URL but we get it from an export in racing.
			-- If racing isn't present or there is no URL in the export then something must have gone wrong and we'll tell mapmanager to get us a new map.
			print("surrogate maps aren't implemented yet as the voting system isn't implemented!")
			ok = false
		end

		if not ok then
			-- It may have a directive but we couldn't get the data, oh well..
			GlobalState.CurrentMapMissionJSON = false
		end
	else
		GlobalState.CurrentMapMissionJSON = false
	end

	-- Update the polling variable for connected clients, connecting clients will just be able to load it as it will be part of state!
	GlobalState.CurrentMapMissionJSONChecked = true

	print("map loading was oki doki? " .. ((not not GlobalState.CurrentMapMissionJSON) and "yes" or "no")) -- thanks lua syntax, very cool :^)
end)
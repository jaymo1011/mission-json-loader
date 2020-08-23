local loadedUGC = {}

local GetPropSpeedModificationParameters

do
	local speedUpObjects = {
		[-1006978322] = true,
		[-388593496] = true,
		[-66244843] = true,
		[-1170462683] = true,
		[993442923] = true,
		[737005456] = true,
		[-904856315] = true,
		[-279848256] = true,
		[588352126] = true,
	}

	local slowDownObjects = {
		[346059280] = true,
		[620582592] = true,
		[85342060] = true,
		[483832101] = true,
		[930976262] = true,
		[1677872320] = true,
		[708828172] = true,
		[950795200] = true,
		[-1260656854] = true,
		[-1875404158] = true,
		[-864804458] = true,
		[-1302470386] = true,
		[1518201148] = true,
		[384852939] = true,
		[117169896] = true,
		[-1479958115] = true,
		[-227275508] = true,
		[1431235846] = true,
		[1832852758] = true,
	}

	GetPropSpeedModificationParameters = function(model, prpsba)
		-- fast fail if there is no reason to continue
		if prpsba == -1 then return false end

		local var1, var2 = -1, -1

		if speedUpObjects[model] then
			if prpsba == 1 then
				var1, var2 = 15, 0.3
			elseif prpsba == 2 then
				var1, var2 = 25, 0.3
			elseif prpsba == 3 then
				var1, var2 = 35, 0.5
			elseif prpsba == 4 then
				var1, var2 = 45, 0.5
			elseif prpsba == 5 then
				var1, var2 = 100, 0.5
			else
				var1, var2 = 25, 0.4
			end
		elseif slowDownObjects[model] then
			var2 = -1
			if prpsba == 1 then
				var1 = 44
			elseif prpsba == 2 then
				var1 = 30
			elseif prpsba == 3 then
				var1 = 16
			else
				var1 = 30
			end
		else
			return false
		end

		return true, var1, var2
	end
end

local function LoadUGC(ugc)
	-- Set the flag so the server knows we're loading stuff right now.
	LocalPlayer.state:set("MissionJSONLoaded", false, true)

	print("Loading UGC...")

	ugc.objects = {}

	local missionData = ugc.data["mission"] or false
	if not missionData then error("UGC does not contain a mission array!") end

	local objectData = missionData["prop"] or false
	if not objectData then return end -- this is the only time we will fail silently.

	-- Common Data
	local modelArr = objectData.model
	local locationArr = objectData.loc
	local rotationArr = objectData.vRot
	local headingArr = objectData.head

	-- Extra Data
	local textVariantArr = objectData.prpclr or objectData.prpclc or false
	local lodDistArr = objectData.prplod or false
	local speedAdjArr = objectData.prpsba or false
	-- The rest of it are in bitsets and ugh, I can NOT be bothered

	for i=1, objectData["no"] do
		local model = modelArr[i]
		local heading = headingArr[i]
		local location = locationArr[i]--; location = Vector3FromTable(location)
		local rotation = rotationArr[i]--; rotation = Vector3FromTable(rotation)

		-- Request model and wait (if it exists!)
		if not IsModelInCdimage(model) then return end; RequestModel(model); while not HasModelLoaded(model) do Wait(0) end

		-- Create the object
		local newObj = CreateObjectNoOffset(model, location, false, true, false)
		ugc.objects[#ugc.objects+1] = newObj -- Save as early as possible so we can still undo!
		FreezeEntityPosition(newObj, true)

		-- Rotate it!
		SetEntityHeading(newObj, heading)
		SetEntityRotation(newObj, rotation, 2, false)

		-- Paint it!
		if textVariantArr then
			local textureVariant = textVariantArr[i]
			if textureVariant ~= -1 then
				SetObjectTextureVariant(newObj, textureVariant)
			end
		end

		-- Set it up!
		if lodDistArr then
			local lodDistance = lodDistArr[i]
			if lodDistance ~= -1 then
				SetEntityLodDist(newObj, textureVariant)
			end
		end

		if speedAdjArr then
			local speedAdjustment = speedAdjArr[i]
			local hasSpeedAdjust, speed, duration = GetPropSpeedModificationParameters(model, speedAdjustment)
			if hasSpeedAdjust then
				if speed > -1 then
					SetObjectStuntPropSpeedup(newObj, speed)
				end

				if duration > -1 then
					SetObjectStuntPropDuration(newObj, duration)
				end
			end
		end
	end

	print("Done loading UGC!")
end

local function UnloadUGC(ugc)
	if ugc.objects then
		for _, objectHandle in ipairs(ugc.objects) do
			DeleteObject(objectHandle)
		end
	end
end

AddEventHandler("onClientMapStart", function(resource)
	-- If the map was just restarted globally and the server hasn't checked if it has MissionJSON then just wait for it to do so (or timeout)
	if not GlobalState.CurrentMapMissionJSONChecked then
		local CheckForMissionJSONTimeout = GetGameTimer() + GetConvarInt("missionJsonLoader_clientLoadTimeout", 10000)
		while CheckForMissionJSONTimeout > GetGameTimer() and not GlobalState.CurrentMapMissionJSONChecked do Wait(500) end
	end

	-- Grab CurrentMapUGC from GlobalState
	local mapUGC = GlobalState.CurrentMapUGC

	-- If the current map actually is not actually properly parsed UGC, don't do anything with it
	if not IsValidUGC(mapUGC) then return end

	-- Well, if we've made this this far, this is almost certainly a valid map, lets use it!
	loadedUGC[resource] = {data = mapUGC}
 
	-- Trigger an event for other resources
	TriggerEvent("onMissionJSONLoading")

	-- And now we load it!
	LoadUGC(loadedUGC[resource])

	-- Finally, we update the LocalPlayer state to tell the server we've loaded! (by setting the loaded map to the resource name so it doesn't get confused)
	LocalPlayer.state:set("MissionJSONLoaded", resource, true)

	-- Trigger an event for other resources
	TriggerEvent("onMissionJSONLoaded")
end)

AddEventHandler("onClientMapStop", function(resource)
	-- If there is any loaded UGC, unload it
	if loadedUGC[resource] then
		UnloadUGC(loadedUGC[resource])
		loadedUGC[resource] = nil
	end
end)

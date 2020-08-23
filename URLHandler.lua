function GetUGCURLContent(url)
	-- Ensure that url is a string and (hopefully) a proper URL
	if type(url) ~= "string" then return end

	local urlContent = false
	local urlFilename = string.gsub(url, "([:/%.]+)", "_") .. ".cache"

	-- Try and load the URL from cache (except when missionJsonLoader_disableUrlCache is set...)
	-- If we're lucky, this is all we need to do!
	-- ISSUE: GetConvar must have a true default value otherwise it errors which is silly :(
	if GetConvar("missionJsonLoader_enableUrlCache", true) then urlContent = LoadResourceFile(GetCurrentResourceName(), urlFilename) end

	-- Perfect, we have a cached URL! Return it and we're done!
	if urlContent ~= nil and urlContent ~= "" then return urlContent end

	-- If we continued on, we don't have this URL cached, sad. Now we need to grab it from the web...
	local httpRequestTimer = GetGameTimer() + GetConvarInt("missionJsonLoader_httpTimeout", 10000)
	local httpRequestOk, err = pcall(function()
		PerformHttpRequest(url, function(errorCode, resultData, resultHeaders)
			-- aw :(
			if errorCode ~= 200 then httpRequestTimer = 0 return end

			-- If the return content **seems** like valid JSON then we'll treat it that way.
			-- This stops something like a HTML document from being treated as MissionJSON
			if SeemsLikeValidMissionJSON(resultData) then
				urlContent = resultData
			end

			-- Set the timer to 0 which will kill the while loop :D
			httpRequestTimer = 0
		end)

		-- Wait until the HTTP request has completed (or timed out)
		while httpRequestTimer > GetGameTimer() do Wait(100) end
	end)

	-- If the HTTP request breaks, return nil
	if not httpRequestOk then print(err) return end
	
	-- Cache the URL for next time (if there was one)
	if urlContent ~= nil and urlContent ~= "" then
		if GetConvar("missionJsonLoader_enableUrlCache", true) and not SaveResourceFile(GetCurrentResourceName(), urlFilename, urlContent) then 
			print("[MissionJSON Loader] ^1[ERROR] ^7Could not cache URL %s using filename %s\nURL cache may be broken somehow!")
		end
	end

	-- Return the content (if any)
	return urlContent
end

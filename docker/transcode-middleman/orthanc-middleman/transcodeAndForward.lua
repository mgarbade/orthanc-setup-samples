
-- Global tables to track the received instances for each series
seriesTracker = {
   ['lowdose'] = {},
   ['native'] = {}
}

 -- Function to check and record each instance received
 function CheckAndRecordInstance(seriesType, seriesId, instanceId)
    if seriesTracker[seriesType] then
        if not seriesTracker[seriesType][seriesId] then
            seriesTracker[seriesType][seriesId] = { count = 0 }
            print("Initializing tracking for " .. seriesType .. " series with ID " .. seriesId)
        end
        seriesTracker[seriesType][seriesId].count = seriesTracker[seriesType][seriesId].count + 1
        print("Received instance " .. instanceId .. " for series " .. seriesId .. "; count now " .. seriesTracker[seriesType][seriesId].count)
    else
        print("Received series type " .. seriesType .. " is not being tracked.")
    end
 end
 
 -- Function to check if both series are complete
 function CheckBothSeriesComplete()
    print("Checking if both series are complete...")
    for seriesId, data in pairs(seriesTracker['lowdose']) do
        if seriesTracker['native'][seriesId] then
            if data.count >= 10 and seriesTracker['native'][seriesId].count >= 10 then -- assuming 10 as the required number for each series
                print("Both series complete for series ID " .. seriesId)
                return true, seriesId
            else
                print("Series not complete: Lowdose count " .. data.count .. ", Native count " .. seriesTracker['native'][seriesId].count)
            end
        else
            print("No corresponding native series found for lowdose series ID " .. seriesId)
        end
    end
    return false
 end


function trim(s)
    return s:match'^%s*(.*%S)' or ''
end

function normalizeSeriesDescription(description)
    local lowerDescription = trim(description):lower()
    if lowerDescription:find("nativ") then
        return 'native'
    elseif lowerDescription:find("km") and lowerDescription:find("low dose") then
        return 'lowdose'
    else
        return nil
    end
end


function ensureDirectoryExists(dir)
    -- Debug print to indicate the directory check/creation attempt
    print("Ensuring directory exists: " .. dir)
    
    -- Use os.execute to create the directory if it does not exist
    local result = os.execute("mkdir -p " .. dir)
    
    -- Print the result of the directory creation attempt
    if result then
        print("Directory ensured: " .. dir)
    else
        print("Failed to create directory: " .. dir)
    end
end


-- Function to handle the storage of DICOM files into respective directories
function StoreDICOM(studyId, instanceId, seriesType, dicomData)
    local dirPath = '/path/to/store/' .. studyId .. "/" .. seriesType
    ensureDirectoryExists(dirPath)
    
    local filePath = dirPath .. '/' .. instanceId .. '.dcm'
    local file = io.open(filePath, 'wb')
    if file then
        file:write(dicomData)
        file:close()
        print("Stored DICOM file at " .. filePath)
    else
        print("Failed to open file for writing at " .. filePath)
    end
end
 
 function OnStoredInstance(instanceId, tags, metadata, origin)
    -- Avoid processing if it originates from Lua itself to prevent infinite loops
    if origin['RequestOrigin'] ~= 'Lua' then
        local studyId = tags.StudyInstanceUID        
        local seriesDescription = tags.SeriesDescription or ""
        local seriesType = normalizeSeriesDescription(seriesDescription)
        print("Processing instance " .. instanceId .. " of type " .. seriesType)
 
        local dicom = RestApiGet('/instances/' .. instanceId .. '/file')
        if dicom then
            print("Successfully retrieved DICOM for instance " .. instanceId)
            -- Store DICOM based on the series type
            if seriesType == 'lowdose' or seriesType == 'native' then
                StoreDICOM(studyId, instanceId, seriesType, dicom)
                CheckAndRecordInstance(seriesType, studyId, instanceId)
            else
                print("Series type " .. seriesType .. " is not part of the tracking process.")
            end
            -- Check if both series are complete
            local complete, completeSeriesId = CheckBothSeriesComplete()
            if complete then
                print("Triggering inference for complete series ID " .. completeSeriesId)
                TriggerInference('/path/to/store/lowdose/', '/path/to/store/native/', completeSeriesId)
            end
        else
            print("Failed to retrieve DICOM for instance " .. instanceId)
        end
    else
        print("Skipping processing for internal Lua-originated request.")
    end
 end
 
 -- Function to simulate the neural network inference
 function TriggerInference(lowdosePath, nativePath, seriesId)
    local lowdoseFullPath = lowdosePath .. seriesId .. '/'
    local nativeFullPath = nativePath .. seriesId .. '/'
    print("Simulating neural network inference with command: python3 run_inference.py " .. lowdoseFullPath .. " " .. nativeFullPath)
    -- Use this line to simulate command execution without running a real script
    os.execute("echo 'Simulating inference for lowdose path: " .. lowdoseFullPath .. " and native path: " .. nativeFullPath .. "'")
 end
 


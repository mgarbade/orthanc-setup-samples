-- Global variable for the base storage path
local basePath = '/path/to/store/'
local LOWDOSE_DIR = 'lowdose'
local NATIVE_DIR = 'native'


-- Global tables to track the received instances for each series
seriesTracker = {
   [LOWDOSE_DIR] = {},
   [NATIVE_DIR] = {}
}


-- Function to check and record each instance received
function CheckAndRecordInstance(seriesType, studyId, instanceId)
    if seriesTracker[seriesType] then
        if not seriesTracker[seriesType][studyId] then
            seriesTracker[seriesType][studyId] = { count = 0, instances = {} }
            print("Initializing tracking for " .. seriesType .. " study with ID " .. studyId)
        end

        -- Check if this instance has already been counted
        if not seriesTracker[seriesType][studyId].instances[instanceId] then
            seriesTracker[seriesType][studyId].count = seriesTracker[seriesType][studyId].count + 1
            seriesTracker[seriesType][studyId].instances[instanceId] = true
            print("Received instance " .. instanceId .. " for study " .. studyId .. "; count now " .. seriesTracker[seriesType][studyId].count)
        else
            print("Instance " .. instanceId .. " already recorded for study " .. studyId .. ". Skipping.")
        end
    else
        print("Received series type " .. seriesType .. " is not being tracked.")
    end
end

 
-- Helper function to count the number of .dcm files in a directory for a specific study
function countDICOMFiles(studyId, seriesType)
    local directory = basePath .. studyId .. "/" .. seriesType
    local handle = io.popen("ls " .. directory .. "/*.dcm 2>/dev/null | wc -l")
    local result = handle:read("*n")
    handle:close()
    return result or 0
end

-- Function to check if both series are complete by checking file counts in directories
function CheckBothSeriesComplete()
    print("Checking if both series are complete (by study)...")
    for studyId, data in pairs(seriesTracker[LOWDOSE_DIR]) do
        print("Lowdose study ID being checked: " .. studyId)
        if seriesTracker[NATIVE_DIR][studyId] then
            print("Found corresponding native series for study ID: " .. studyId)

            -- Dynamically determine the number of files for this study
            local lowdoseCount = countDICOMFiles(studyId, LOWDOSE_DIR)
            local nativeCount = countDICOMFiles(studyId, NATIVE_DIR)

            print("File counts - Lowdose: " .. lowdoseCount .. ", Native: " .. nativeCount)

            -- Ensure both series have the same number of files, and that this count matches
            if lowdoseCount > 0 and lowdoseCount == nativeCount and
                data.count == lowdoseCount and seriesTracker[NATIVE_DIR][studyId].count == nativeCount then
                print("Both series complete for study ID " .. studyId)
                return true, studyId
            else
                print("Series not complete: Lowdose count " .. data.count .. ", Native count " .. seriesTracker[NATIVE_DIR][studyId].count)
            end
        else
            print("No corresponding native series found for lowdose study ID " .. studyId)
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
        return NATIVE_DIR
    elseif lowerDescription:find("km") and lowerDescription:find("low dose") then
        return LOWDOSE_DIR
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
    local dirPath = basePath .. studyId .. "/" .. seriesType
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
            if seriesType == LOWDOSE_DIR or seriesType == NATIVE_DIR then
                StoreDICOM(studyId, instanceId, seriesType, dicom)
                CheckAndRecordInstance(seriesType, studyId, instanceId)
            else
                print("Series type " .. seriesType .. " is not part of the tracking process.")
            end
            -- Check if both series are complete
            local complete, studyID = CheckBothSeriesComplete()
            if complete then
                print("Triggering inference for complete series ID " .. studyID)
                TriggerInference(studyID)
                ResetSeriesTracker(studyID)
                DeleteDirectoriesAfterInference(studyID)
            end
        else
            print("Failed to retrieve DICOM for instance " .. instanceId)
        end
    else
        print("Skipping processing for internal Lua-originated request.")
    end
 end
 
 -- Function to simulate the neural network inference
 function TriggerInference(studyID)
    local dirPath = basePath .. studyID .. '/'
    local lowdoseFullPath = dirPath .. LOWDOSE_DIR .. '/'
    local nativeFullPath = dirPath .. NATIVE_DIR .. '/'
    print("Simulating neural network inference with command: python3 run_inference.py " .. lowdoseFullPath .. " " .. nativeFullPath)
    os.execute("echo 'Simulating inference for lowdose path: " .. lowdoseFullPath .. " and native path: " .. nativeFullPath .. "'")
    os.execute("python3 /python/run_inference.py")
end


function ResetSeriesTracker(studyID)
    print("Try clearing series tracking for study ID: " .. studyID)
    if seriesTracker and seriesTracker[LOWDOSE_DIR] and seriesTracker[NATIVE_DIR] then
        seriesTracker[LOWDOSE_DIR][studyID] = nil
        seriesTracker[NATIVE_DIR][studyID] = nil
        print("Cleared series tracking for study ID: " .. studyID)
    else
        print("Error: seriesTracker is not properly initialized or study ID does not exist.")
    end
end


 
function DeleteDirectoriesAfterInference(studyID)
    print("Deleting folders for lowdose, native and studyID paths...")
    local dirPath = basePath .. studyID .. '/'
    local lowdoseFullPath = dirPath .. LOWDOSE_DIR .. '/'
    local nativeFullPath = dirPath .. NATIVE_DIR .. '/'
    os.execute("rm -rf '" .. lowdoseFullPath .. "'")
    os.execute("rm -rf '" .. nativeFullPath .. "'")
    os.execute("rm -rf '" .. dirPath .. "'")
    print("Deleted folders for lowdose, native and studyID paths.")
end


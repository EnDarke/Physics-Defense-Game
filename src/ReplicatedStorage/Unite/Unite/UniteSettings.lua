-- !strict

-- Author: Alex/EnDarke
-- Description: Holds all game settings that are changeable

local Parent: Instance = script.Parent

--\\ Modules //--
local Util = require(Parent.Parent.Collection.Util)

--\\ Module Code //--
local UniteSettings = {}

UniteSettings.Data = {
    PlayerScope = "Player_DEV_A1"; -- Remove '_Dev' when using the public data store
    PlayerKey = "Defense_";
}

UniteSettings.Accounts = {
    RetryCooldown = 1; -- In seconds, will determine how long the code will wait before retrying the data loading
    AutoSaveAccounts = 30; -- In seconds, will determine how long the autosave period will be
    RobloxWriteDebounce = 7; -- In seconds, time between datastore calls
    ForceLoadMaxSteps = 8; -- Steps before the force load request takes the active session
    AssumeDeadSessionLock = 30 * 60; -- Seconds, for if the player's data hasn't been updated for x time, the session lock will die

    IssueCountForCriticalState = 5; -- Issues to find before pronouncing critical state
    IssueLast = 120; -- Seconds
    CriticalStateLast = 120; -- Seconds

    MetaTagsUpdated = {
        AccountCreateTime = true;
        SessionLoadCount = true;
        ActiveSession = true;
        ForeLoadSession = true;
        LastUpdate = true;
    };
}

UniteSettings.Match = {
    Intermission_Time = 10;
    Total_Time = 30;
    Castle_Health = 50;

    Node_Radius = 2;
}

UniteSettings.Admin = {
    IDs = {
        32839980; -- EnDarke
        63158161; -- Awesome3_Eric
    };
    KickMessages = {
        [1] = "Your Data could not be found! Please try rejoining, or contact the developers!";
    };
}

UniteSettings.ErrorCodes = {
    -- 000-099 | Player Data
    [000] = "Player could not be found";
    [001] = "Player Account could not be found";
    [002] = "Player Data could not be found";
    [003] = "Inputted DataType could not be found";
}

return Util._readOnly(UniteSettings)
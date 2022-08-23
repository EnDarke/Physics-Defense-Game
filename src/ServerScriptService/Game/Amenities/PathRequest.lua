-- !strict

-- Author: Alex/EnDarke
-- Description: Handles path requests

--\\ Unite //--
local Unite = require(game:GetService("ReplicatedStorage").Unite.Unite)
local services = Unite.Services
local collection = Unite.Collection

--\\ Collection //--
local TaskQueue = collection.TaskQueue

--\\ Module Code //--
local pathRequestAmenity = Unite.ForgeAmenity {
    Name = "PathRequestAmenity";
    Client = {};
}

function pathRequestAmenity.AcceptPathRequests(requests: {})
    if requests[1] then
        for _, request in ipairs(requests) do
            local path = pathRequestAmenity.pathClass:findPath(request.startPos, request.endPos)
            if path then
                request.object:OnPathFound(path)
            end
        end
    end
end

function pathRequestAmenity:AddPathRequest(obj: Instance)
    if obj then
        pathRequestAmenity.currentRequests:Add(obj)
        return true
    else
        return false
    end
end

function pathRequestAmenity:UniteInit()
    pathRequestAmenity.matchAmenity = Unite.AcquireAmenity("MatchAmenity")
end

function pathRequestAmenity:UniteStart()
    pathRequestAmenity.pathClass = pathRequestAmenity.matchAmenity.PathClass
    pathRequestAmenity.currentRequests = TaskQueue.new(pathRequestAmenity.AcceptPathRequests)
end

return pathRequestAmenity
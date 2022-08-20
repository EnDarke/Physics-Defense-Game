-- !strict

-- Author: Alex/EnDarke
-- Description: Initializes the Unite framework for server/client usage

--\\ Services //--
local RunService = game:GetService("RunService")

--\\ Module Code //--
if RunService:IsServer() then
    local Unite = require(script.UniteServer)
    Unite.Settings = require(script.UniteSettings)
    return Unite
else
    local UniteServer = script:FindFirstChild("UniteServer")
    if UniteServer then
        UniteServer:Destroy()
    end
    local Unite = require(script.UniteClient)
    Unite.Settings = require(script.UniteSettings)
    return Unite
end
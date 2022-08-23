-- !strict

-- Author: Alex/EnDarke
-- Description: Handles client initialization

local Parent: Instance = script.Parent

--\\ Unite //--
local Unite = require(game:GetService("ReplicatedStorage").Unite.Unite)
local services: {} = Unite.Services
local collection: {} = Unite.Collection
local signals: {} = Unite.Signals

--\\ Types //--
type Oath = {Oath}
type FnBind = (Instance, ...any) -> ...any
type ServerRouteFunction = (Instance, Args) -> (boolean, ...any)
type ServerRoute = {ServerRouteFunction}
type Commune = {
    _instancesFolder: Folder;
    _useOath: Oath;
    GetFunction: ({name: string, inboundRoute: ServerRoute?, outboundRoute: ServerRoute?}) -> ();
    GetSignal: ({name: string, inboundRoute: ServerRoute?, outboundRoute: ServerRoute?}) -> ();
    GetProperty: ({name: string, inboundRoute: ServerRoute?, outboundRoute: ServerRoute?}) -> ();
}

--\\ Collection //--
local commune = collection.Commune.ClientCommune

--\\ Variables //--
local clientCommune: Commune = commune.new(services.ReplicatedStorage, false, "Communication")
signals.Announce = clientCommune:GetSignal("Announce")

--\\ Client Code //--
Unite.AppendManagers(Parent.Managers) -- Adds all managers under this instance, add a bool after to get all descendants as well

--\\ Unite Start-up //--
Unite.Start():Follow(function()
end):Hook(warn)
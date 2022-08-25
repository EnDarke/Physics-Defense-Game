-- !strict

-- Author: Alex/EnDarke
-- Description: Handles server initialization

local Parent: Instance = script.Parent

--\\ Unite //--
local Unite = require(game:GetService("ReplicatedStorage").Unite.Unite)
local services: {} = Unite.Services
local collection: {} = Unite.Collection
local signals: {} = Unite.Signals

--\\ Modules //--
local Element = collection.Element

--\\ Types //--
type FnBind = (Instance, ...any) -> ...any
type ServerRouteFunction = (Instance, Args) -> (boolean, ...any)
type ServerRoute = {ServerRouteFunction}
type Commune = {
    _instancesFolder: Folder;
    BindableFunction: ({name: string, fn: FnBind, inboundRoute: ServerRoute?, outboundRoute: ServerRoute?}) -> (any);
    Wrap: ({tbl: {}, name: string, inboundRoute: ServerRoute?, outboundRoute: ServerRoute?}) -> (any);
    ForgeSignal: ({name: string, inboundRoute: ServerRoute?, outboundRoute: ServerRoute?}) -> (any);
    ForgeProperty: ({name: string, initialValue: any, inboundRoute: ServerRoute?, outboundRoute: ServerRoute?}) -> (any);
    Destroy: () -> ();
}

--\\ Collection //--
local commune = collection.Commune.ServerCommune

--\\ Variables //--
local folder: Folder = Instance.new("Folder")
local serverCommune: Commune = commune.new(services.ReplicatedStorage, "Communication")
signals.Announce = serverCommune:ForgeSignal("Announce")

--\\ Server Code //--
Unite.AppendAmenities(Parent.Amenities)

Unite.Start():Follow(function()
    Element.Auto(Parent.Elements)
end):Hook(warn)
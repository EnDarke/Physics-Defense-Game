-- !strict

-- Author: Alex/EnDarke
-- Description: Holds types

export type Args = {
    n: number;
    [any]: any;
}

export type FnBind = (Instance, ...any) -> ...any

export type ServerRouteFunction = (Instance, Args) -> (boolean, ...any)
export type ServerRoute = {ServerRouteFunction}

export type ClientRouteFunction = (Args) -> (boolean, ...any)
export type ClientRoute = {ClientRouteFunction}

return nil
--original https://steamcommunity.com/sharedfiles/filedetails/?id=2373890872
local function AddVehicle( t, class )
	list.Set( "Vehicles", class, t )
end

local Category = "HL2 CAGE BUGGY"



AddVehicle( {
	-- Required information
	Name = "HL2 Buggy 10 Cage",
	Model = "models/buggy_10.mdl",
	Class = "prop_vehicle_jeep",
	Category = Category,

	-- Optional information
	Author = "Donald",
	Information = "HL2 Buggy 10",

	KeyValues = {
		vehiclescript = "scripts/vehicles/buggy_don_01.txt"
	}
}, "Buggy_10" )

AddVehicle( {
	-- Required information
	Name = "HL2 Buggy Karp",
	Model = "models/buggy_21.mdl",
	Class = "prop_vehicle_jeep",
	Category = Category,

	-- Optional information
	Author = "Donald",
	Information = "HL2 Buggy 21",

	KeyValues = {
		vehiclescript = "scripts/vehicles/buggy_don_01.txt"
	}
}, "Buggy_21" )
if (SERVER) then --the init.lua stuff goes in here
   AddCSLuaFile ("shared.lua");
   SWEP.Weight = 5;
   SWEP.AutoSwitchTo = false;
   SWEP.AutoSwitchFrom = false;
end
 
if (CLIENT) then --the cl_init.lua stuff goes in here
   SWEP.PrintName = "Restrainer";
   SWEP.Slot = 0;
   SWEP.SlotPos = 4;
   SWEP.DrawAmmo = false;
   SWEP.DrawCrosshair = false;
end
 
 
SWEP.Author = "NoOriginality"; -- I just copy pasated most of this because I know nothing about sweps.
SWEP.Contact = "";
SWEP.Purpose = "Become restrained";
SWEP.Category = "JSRestrainer"
 
SWEP.Spawnable = true;
SWEP.AdminSpawnable = true;
 
SWEP.ViewModelFOV			= 60
SWEP.HoldType				= "normal"
SWEP.ShowViewModel = true
SWEP.ShowWorldModel = false

SWEP.Primary.ClipSize = -1;
SWEP.Primary.DefaultClip = -1;
SWEP.Primary.Automatic = false;
SWEP.Primary.Ammo = "none";
SWEP.Primary.Delay		= 0


SWEP.Secondary.ClipSize = -1;
SWEP.Secondary.DefaultClip = -1;
SWEP.Secondary.Automatic = false;
SWEP.Secondary.Ammo = "none";
SWEP.Secondary.Delay		= 0

SWEP.JSVector1 = Vector(0,0,0) -- Left hand
SWEP.JSVector2 = Vector(0,0,0) -- Right hand
 
function SWEP:Think()
	
	return false
end

function SWEP:Initialize()



	self:SetWeaponHoldType(self.HoldType)

	if CLIENT then

		// Create a new table for every weapon instance
		self.VElements = table.FullCopy( self.VElements )
		self.WElements = table.FullCopy( self.WElements )
		self.ViewModelBoneMods = table.FullCopy( self.ViewModelBoneMods )

		self:CreateModels(self.VElements) // create viewmodels
		self:CreateModels(self.WElements) // create worldmodels
		
		// init view model bone build function
		if IsValid(self.Owner) then
			local vm = self.Owner:GetViewModel()
			if IsValid(vm) then				
				// Init viewmodel visibility
				if (self.ShowViewModel == nil or self.ShowViewModel) then
					vm:SetColor(Color(255,255,255,255))
				else
					// we set the alpha to 1 instead of 0 because else ViewModelDrawn stops being called
					vm:SetColor(Color(255,255,255,1))
					// ^ stopped working in GMod 13 because you have to do Entity:SetRenderMode(1) for translucency to kick in
					// however for some reason the view model resets to render mode 0 every frame so we just apply a debug material to prevent it from drawing
					vm:SetMaterial("Debug/hsv")			
				end
			end
		end
		
	end

end

function SWEP:Deploy()

	self.Owner:DrawViewModel(false)
end



SWEP.wRenderOrder = nil
function SWEP:DrawWorldModel()

	if (self.ShowWorldModel == nil or self.ShowWorldModel) then
		self:DrawModel()
	end
	
	if (!self.WElements) then return end
	
	if (!self.wRenderOrder) then

		self.wRenderOrder = {}

		for k, v in pairs( self.WElements ) do
			if (v.type == "Model") then
				table.insert(self.wRenderOrder, 1, k)
			elseif (v.type == "Sprite" or v.type == "Quad") then
				table.insert(self.wRenderOrder, k)
			end
		end

	end
	
	if (IsValid(self.Owner)) then
		bone_ent = self.Owner
	else
		// when the weapon is dropped
		bone_ent = self
	end
	
	for k, name in pairs( self.wRenderOrder ) do
	
		local v = self.WElements[name]
		if (!v) then self.wRenderOrder = nil break end
		if (v.hide) then continue end
		
		local pos, ang
		
		if (v.bone) then
			pos, ang = self:GetBoneOrientation( self.WElements, v, bone_ent )
		else
			pos, ang = self:GetBoneOrientation( self.WElements, v, bone_ent, "ValveBiped.Bip01_R_Hand" )
		end
		
		if (!pos) then continue end
		
		local model = v.modelEnt
		local sprite = v.spriteMaterial
		
		if (v.type == "Model" and IsValid(model)) then

			if type(v.size) == "string" then -- Make sure it ain't a vector
				v.size = self:GetCuffSize(v.size, self:GetOwner()) -- Fixes the friggin function
			end

			// Setting the vectors for the dumb beam draw
			if v.bone == "ValveBiped.Bip01_L_Forearm" then -- Left hand
				self.JSVector1 = Vector(0,0,1.5) + (pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z)
			elseif v.bone == "ValveBiped.Bip01_R_Forearm" then -- Right hand
				self.JSVector2 = (pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z)
			end

			// Drawing the dumb beam
			if self.JSVector1 and self.JSVector2 then
				render.SetMaterial(Material("cable/rope"))
				render.DrawBeam(self.JSVector1 + Vector(0,0,-1.1), self.JSVector2 + Vector(0,0,.5), .6, 0, 5, Color(108, 76,0))
			end

			model:SetPos(pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z )
			ang:RotateAroundAxis(ang:Up(), v.angle.y)
			ang:RotateAroundAxis(ang:Right(), v.angle.p)
			ang:RotateAroundAxis(ang:Forward(), v.angle.r)

			model:SetAngles(ang)
			//model:SetModelScale(v.size)
			local matrix = Matrix()
			matrix:Scale(v.size)
			model:EnableMatrix( "RenderMultiply", matrix )
			
			-- Models get spawned here

			if (v.material == "") then
				model:SetMaterial("")
			elseif (model:GetMaterial() != v.material) then
				model:SetMaterial( v.material )
			end
			
			if (v.skin and v.skin != model:GetSkin()) then
				model:SetSkin(v.skin)
			end
			
			if (v.bodygroup) then
				for k, v in pairs( v.bodygroup ) do
					if (model:GetBodygroup(k) != v) then
						model:SetBodygroup(k, v)
					end
				end
			end
			
			if (v.surpresslightning) then
				render.SuppressEngineLighting(true)
			end
			
			render.SetColorModulation(v.color.r/255, v.color.g/255, v.color.b/255)
			render.SetBlend(v.color.a/255)
			model:DrawModel()
			render.SetBlend(1)
			render.SetColorModulation(1, 1, 1)
			
			if (v.surpresslightning) then
				render.SuppressEngineLighting(false)
			end
			
		elseif (v.type == "Sprite" and sprite) then
			
			local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
			render.SetMaterial(sprite)
			render.DrawSprite(drawpos, v.size.x, v.size.y, v.color)
			
		elseif (v.type == "Quad" and v.draw_func) then
			
			if type(v.size) == "string" then -- Make sure it ain't a vector
				v.size = self:GetCuffSize(v.size, self:GetOwner())
			end

			local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
			ang:RotateAroundAxis(ang:Up(), v.angle.y)
			ang:RotateAroundAxis(ang:Right(), v.angle.p)
			ang:RotateAroundAxis(ang:Forward(), v.angle.r)
			
			cam.Start3D2D(drawpos, ang, v.size)
				v.draw_func( self )
			cam.End3D2D()

		end
	end
end

function SWEP:GetBoneOrientation( basetab, tab, ent, bone_override )
	
	local bone, pos, ang
	if (tab.rel and tab.rel != "") then
		
		local v = basetab[tab.rel]
		
		if (!v) then return end
		
		// Technically, if there exists an element with the same name as a bone
		// you can get in an infinite loop. Let's just hope nobody's that stupid.
		pos, ang = self:GetBoneOrientation( basetab, v, ent )
		
		if (!pos) then return end
		
		pos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
		ang:RotateAroundAxis(ang:Up(), v.angle.y)
		ang:RotateAroundAxis(ang:Right(), v.angle.p)
		ang:RotateAroundAxis(ang:Forward(), v.angle.r)
			
	else
	
		bone = ent:LookupBone(bone_override or tab.bone)

		if (!bone) then return end
		
		pos, ang = Vector(0,0,0), Angle(0,0,0)
		local m = ent:GetBoneMatrix(bone)
		if (m) then
			pos, ang = m:GetTranslation(), m:GetAngles()
		end
		
		if (IsValid(self.Owner) and self.Owner:IsPlayer() and 
			ent == self.Owner:GetViewModel() and self.ViewModelFlip) then
			ang.r = -ang.r // Fixes mirrored models
		end
	
	end
	
	return pos, ang
end

function SWEP:CreateModels( tab )

	if (!tab) then return end

	// Create the clientside models here because Garry says we can't do it in the render hook
	for k, v in pairs( tab ) do
		if (v.type == "Model" and v.model and v.model != "" and (!IsValid(v.modelEnt) or v.createdModel != v.model) and 
				string.find(v.model, ".mdl") and file.Exists (v.model, "GAME") ) then
			
			v.modelEnt = ClientsideModel(v.model, RENDER_GROUP_VIEW_MODEL_OPAQUE)
			if (IsValid(v.modelEnt)) then
				v.modelEnt:SetPos(self:GetPos())
				v.modelEnt:SetAngles(self:GetAngles())
				v.modelEnt:SetParent(self)
				v.modelEnt:SetNoDraw(true)
				v.createdModel = v.model
			else
				v.modelEnt = nil
			end
			
		elseif (v.type == "Sprite" and v.sprite and v.sprite != "" and (!v.spriteMaterial or v.createdSprite != v.sprite) 
			and file.Exists ("materials/"..v.sprite..".vmt", "GAME")) then
			
			local name = v.sprite.."-"
			local params = { ["$basetexture"] = v.sprite }
			// make sure we create a unique name based on the selected options
			local tocheck = { "nocull", "additive", "vertexalpha", "vertexcolor", "ignorez" }
			for i, j in pairs( tocheck ) do
				if (v[j]) then
					params["$"..j] = 1
					name = name.."1"
				else
					name = name.."0"
				end
			end

			v.createdSprite = v.sprite
			v.spriteMaterial = CreateMaterial(name,"UnlitGeneric",params)
			
		end
	end
	
end

/**************************
	Global utility code
**************************/

// Fully copies the table, meaning all tables inside this table are copied too and so on (normal table.Copy copies only their reference).
// Does not copy entities of course, only copies their reference.
// WARNING: do not use on tables that contain themselves somewhere down the line or you'll get an infinite loop
function table.FullCopy( tab )

	if (!tab) then return nil end
	
	local res = {}
	for k, v in pairs( tab ) do
		if (type(v) == "table") then
			res[k] = table.FullCopy(v) // recursion ho!
		elseif (type(v) == "Vector") then
			res[k] = Vector(v.x, v.y, v.z)
		elseif (type(v) == "Angle") then
			res[k] = Angle(v.p, v.y, v.r)
		else
			res[k] = v
		end
	end
	
	return res
	
end


-- This is my own custom shit. 
-- Get the distance between two vectors of the bone hitbox
-- Lol jk, it just does some secret math stuff and returns the vector size.
function SWEP:GetCuffSize(boneroo, ply)

	local function lookupbone(lubone) -- Gets the bone id
		return ply:LookupBone(lubone)
	end

	local JSHBGroups = ply:GetHitBoxGroupCount() -- The amount of groups of hitboxes in the ent
    local JSHBXS = {} -- My little table to store the hitboxs I need
    JSHBXS.LeftHandHB = {}
    JSHBXS.RightHandHB = {}

    for k=0, JSHBGroups - 1 do -- Loops through all the hitbox groups with i = the hitbox group num
        local HBCount = ply:GetHitBoxCount(k) -- The amount of hitboxes in the hitbox group
        
        for v=0, HBCount do -- Loop through all the hitboxes in the group 'i'
            -- k now = the hitbox group and v = the hitbox in that group
            local mybone = ply:GetHitBoxBone(v,k) -- Gets a bone based on k,v

            if mybone == lookupbone(boneroo) and boneroo == "ValveBiped.Bip01_L_Forearm" then -- RBS.LHand is the bone id for Left hand
                JSHBXS.LeftHandHB["Group"] = k
                JSHBXS.LeftHandHB["HB"] = v
            elseif mybone == lookupbone(boneroo) and boneroo == "ValveBiped.Bip01_R_Forearm" then -- Same thing with right hand
                JSHBXS.RightHandHB["Group"] = k
                JSHBXS.RightHandHB["HB"] = v
            end
        end
    end

    -- Now we should have the hitboxes as needed.
	local function jsvecmath(boney)

		local JLH = JSHBXS.LeftHandHB -- So I don't have to type it all out
		local JRH = JSHBXS.RightHandHB

		local function jsquickr(hand)
			return ply:GetHitBoxBounds(hand["HB"], hand["Group"]) -- returns the vectors of hitbox
		end

	    if boney == "ValveBiped.Bip01_L_Forearm" then -- If we're dealing with the left hand
	    	local v1, v2 = jsquickr(JLH) -- HB first, then group
	    	v1.x = math.abs(v1.x - v2.x) -- get the distance between the two amirite?
	    	v1.z = math.abs(v1.z - v2.z) -- get the distance between the two amirite?
	    	local offsetx = (math.ceil(((v1.x/30.2941176471)*100))/100) -- Sets this to 2 decimal places
	    	local offsetz = (math.ceil(((v1.z/20.4705882353)*100))/100) -- Sets this to 2 decimal places
	    	if offsetx >= offsetz then
		    	return Vector(offsetz,.1,offsetz)
	    	elseif offsetz >= offsetx then
	    		return Vector(offsetx,.1,offsetx)
	    	end
	    	return Vector(offsetx,.1,offsetz)

	    elseif boney == "ValveBiped.Bip01_R_Forearm" then -- If we're dealing with the right hand
	    	local v1, v2 = jsquickr(JRH) -- HB first, then group
	    	v1.x = math.abs(v1.x - v2.x) -- get the distance between the two amirite?
	    	v1.z = math.abs(v1.z - v2.z) -- get the distance between the two amirite?
	    	local offsetx = (math.ceil(((v1.x/30.2941176471)*100))/100) -- Sets this to 2 decimal places
	    	local offsetz = (math.ceil(((v1.z/20.4117647059)*100))/100) -- Sets this to 2 decimal places
	    	if offsetx >= offsetz then
		    	return Vector(offsetz,.1,offsetz)
	    	elseif offsetz >= offsetx then
	    		return Vector(offsetx,.1,offsetx)
	    	end
	    else
	    	return Vector(.17, .1, .17)
	    end
	end

	local jscaledvec = jsvecmath(boneroo) -- Gets the scaled vector

	if jscaledvec == nil then
		return (Vector(.17, .1, .17))
	else
		return jscaledvec
	end
  
-- Edit x and z

end

SWEP.WElements = {

	["JSrighthandcuff"] = { 
		type = "Model",
		model = "models/props_vehicles/carparts_tire01a.mdl",
		bone = "ValveBiped.Bip01_R_Forearm",
		rel = "",
		pos = Vector(9, -.3, 0),
		angle = Angle(0, 100, -8.44),
		size = "ValveBiped.Bip01_R_Forearm",
		color = Color(160, 160, 160, 255),
		surpresslightning = false,
		material = "phoenix_storms/cube",
		skin = 0,
		bodygroup = {} 
	},

	["JSlefthandcuff"] = { 
		type = "Model", 
		model = "models/props_vehicles/carparts_tire01a.mdl", 
		bone = "ValveBiped.Bip01_L_Forearm", 
		rel = "", 
		pos = Vector(9, -.4, 0), 
		angle = Angle(-10, 100, 7), 
		size = "ValveBiped.Bip01_L_Forearm", 
		color = Color(160, 160, 160, 255), 
		surpresslightning = false, 
		material = "phoenix_storms/cube", 
		skin = 0,
		bodygroup = {} 
	}
}
-- original https://github.com/Heyter/Justice-System-DarkRp-
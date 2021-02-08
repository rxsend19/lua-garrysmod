hook.Add("PostGamemodeLoaded", "JSRunMainScript", function() -- This is here because the includes don't run without it.

AddCSLuaFile("config/config.lua")
include("config/config.lua")
AddCSLuaFile("lua/autorun/client/cl_main.lua")

-- This creates the function table
PolSys = {}

-- Client / Server Communication --
    -- Get Eye Ent Name Net
    util.AddNetworkString("JSConfirmCheckSV")
    util.AddNetworkString("JSConfirmCheckCL")
    -- Pardon Nets
    util.AddNetworkString("JSPardonSV")
    util.AddNetworkString("JSPardonCL")
    -- Ticket Nets (Getting Ticket Amount)
    util.AddNetworkString("JSTicketSV1")
    util.AddNetworkString("JSTicketCL1")
    -- Ticket Nets (Sending Ticket Confirm)
    util.AddNetworkString("JSTicketSV2")
    util.AddNetworkString("JSTicketCL2")
    -- Ticket Nets (Actual Sending)
    util.AddNetworkString("JSTicketSV3")
    util.AddNetworkString("JSTicketCL3")
    -- Ticket Nets (If ticket was paid or not)
    util.AddNetworkString("JSTicketSV4")
    util.AddNetworkString("JSTicketCL4")
    -- Send To Jail Nets
    util.AddNetworkString("JSSendJailSV")
    util.AddNetworkString("JSSendJailCL")
    -- Get Crime Numbers Nets
    util.AddNetworkString("JSViewCrimesSV")
    util.AddNetworkString("JSViewCrimesCL")
    -- Search Perp Nets
    util.AddNetworkString("JSSearchPersonSV")
    util.AddNetworkString("JSSearchPersonCL")
    -- Seize Items Nets
    util.AddNetworkString("JSSeizeItemsSV")
    util.AddNetworkString("JSSeizeItemsCL")
    -- Restrain Ply Nets
    util.AddNetworkString("JSRestrainPlySV")
    util.AddNetworkString("JSRestrainPlyCL")
    -- Escort Ply Nets
    util.AddNetworkString("JSEscortPlySV")
    util.AddNetworkString("JSEscortPlyCL")
    -- Client Side Deny Msg
    util.AddNetworkString("JSDenyMsgCL")
    /*-- Restrain SWEP Old Ply Data Table Transfer
    util.AddNetworkString("RestrainTableSV")
    util.AddNetworkString("RestrainTableCL")
    */

-- General Functions --

    -- If person is correct job
    function PolSys.isJob(ply, netstring)

        if table.HasValue(PoliceSystem.AllowedJobsPoliceMenu, ply:Team()) then
            return true
        else
            net.Start(netstring)
                net.WriteBool(false)
                net.WriteInt(1, 32)
            net.Send(ply)
            return false
        end
    end

    -- If looking at player/distance
    function PolSys.isPlyNear(ent, ply, netstring)

        if ent:IsPlayer() then -- Just a quick check to make sure it's actually a player, not world or some shit

            if table.HasValue(PoliceSystem.AllowedJobsPoliceMenu, ent:Team()) then -- If the ent is a cop
                net.Start(netstring) -- By default, netstrings are usually "JSDenyMsgCL", but sometimes, I need it custom.
                    net.WriteBool(true)
                    net.WriteInt(3, 32) -- State the perp is actually a cop and tell the other cop to piss off.
                net.Send(ply)
                return false
            end

            local dis = ply:GetPos():Distance(ent:GetPos()) -- Gets the distance between both pos's.

            if dis < 150 then -- Makes sure the distance is small enough.
                return true
            else
                net.Start(netstring)
                    net.WriteBool(false)
                    net.WriteInt(2, 32)
                net.Send(ply)
                return false
            end
        else
            net.Start(netstring)
                net.WriteBool(false)
                net.WriteInt(2, 32)
            net.Send(ply)
            return false
        end
    end

    -- If person is being escorted
    function PolSys.isEscorted(ent, ply, netstring)

        if ent:GetNWBool("JSEscorted") then

            net.Start(netstring)
                net.WriteBool(true)
                net.WriteInt(1 ,32)
            net.Send(ply)
            return true
        else
            return false
        end
    end

    -- If the person is restrained
    function PolSys.isRestrained(ent, ply, netstring)

        if ent:GetNWBool("JSRestrained") then
            return true
        else
            net.Start(netstring)
                net.WriteBool(true)
                net.WriteInt(2, 32)
            net.Send(ply)
            return false
        end
    end

    -- If person is wanted
    function PolSys.isWanted(ply, netstring, charges)
        local crimess = 0

        for k,v in pairs(charges) do
            crimess = crimess + v
        end

        if crimess > 0 then
            return true
        else
            net.Start(netstring)
                net.WriteBool(false)
                net.WriteInt(3, 32)
            net.Send(ply)
            return false
        end
    end

    -- Total Crime Fines
    function PolSys.crimeFine(ent)

        local totalfine = 0

        for k,v in pairs(ent.JSCTable) do

            if k == "Contraband" then
                totalfine = totalfine + (PoliceSystem.CrimeFines.ContrabandFine * v)
            elseif k == "Murder" then
                totalfine = totalfine + (PoliceSystem.CrimeFines.MurderFine * v)
            elseif k == "Mugging" then
                totalfine = totalfine + (PoliceSystem.CrimeFines.MuggingFine * v)
            elseif k == "CarJacking" then
                totalfine = totalfine + (PoliceSystem.CrimeFines.CarJackingFine * v)
            elseif k == "IllegalWeapons" then
                totalfine = totalfine + (PoliceSystem.CrimeFines.IllWeaponsFine * v)
            elseif k == "Burglary" then
                totalfine = totalfine + (PoliceSystem.CrimeFines.BurglaryFine * v)
            elseif k == "Terrorism" then
                totalfine = totalfine + (PoliceSystem.CrimeFines.TerrorismFine * v)
            elseif k == "HitRun" then
                totalfine = totalfine + (PoliceSystem.CrimeFines.HitRunFine * v)
            end
        end

        return totalfine
    end

    -- Clear Crimes
    function PolSys.clearCrimes(ent)

        if not(IsValid(ent)) then return end -- A quick check when the ent disconnects and this calls so it doesn't run (It also calls when ent rejoins, and is arrested)

        for k,v in pairs(ent.JSCTable) do
            ent.JSCTable[k] = 0
        end
        file.Write("jsystem/charges/" .. ent:SteamID64() .. ".txt", util.TableToJSON(ent.JSCTable))
    end

    -- Jail Time Amount
    function PolSys.jailTime(ent)

        local charges = ent.JSCTable
        local jailtime = 0

        for k,v in pairs(charges) do

             if k == "Contraband" then
                jailtime = jailtime + (PoliceSystem.JailTimeCharges.ContrabandTime * v)
            elseif k == "Murder" then
                jailtime = jailtime + (PoliceSystem.JailTimeCharges.MurderTime * v)
            elseif k == "Mugging" then
                jailtime = jailtime + (PoliceSystem.JailTimeCharges.MuggingTime * v)
            elseif k == "CarJacking" then
                jailtime = jailtime + (PoliceSystem.JailTimeCharges.CarJackingTime * v)
            elseif k == "IllegalWeapons" then
                jailtime = jailtime + (PoliceSystem.JailTimeCharges.IllWeaponsTime * v)
            elseif k == "Burglary" then
                jailtime = jailtime + (PoliceSystem.JailTimeCharges.BurglaryTime * v)
            elseif k == "Terrorism" then
                jailtime = jailtime + (PoliceSystem.JailTimeCharges.TerrorismTime * v)
            elseif k == "HitRun" then
                jailtime = jailtime + (PoliceSystem.JailTimeCharges.HitRunTime * v)
            end
        end

        return jailtime
    end

    -- Return Crime Amounts
    function PolSys.getCrimes(ent)

        local crimenumt = {

            Mug = 0,
            Mur = 0,
            Car = 0,
            Con = 0,
            IWep = 0,
            Bur = 0,
            Ter = 0,
            Hnr = 0
        }

        for k,v in pairs(ent.JSCTable) do

            if k == "Contraband" then
                crimenumt.Con = v
            elseif k == "Murder" then
                crimenumt.Mur = v
            elseif k == "Mugging" then
                crimenumt.Mug = v
            elseif k == "CarJacking" then
                crimenumt.Car = v
            elseif k == "IllegalWeapons" then
                crimenumt.IWep = v
            elseif k == "Burglary" then
                crimenumt.Bur = v
            elseif k == "Terrorism" then
                crimenumt.Ter = v
            elseif k == "HitRun" then
                crimenumt.Hnr = v
            end
        end

        return crimenumt
    end

    -- Return Search/Seize Table
    function PolSys.searchSeize(ent) -- Ent is perp

        local returntable = {}
        returntable.wep = {} -- Gets weapons on ply
        returntable.pock = {} -- Sets up table
        returntable.pock.wep = {} -- Gets weapons in pocket
        returntable.pock.ship = {} -- Gets Shipments in pocket
        returntable.pock.misc = {} -- Everything Else in pocket

        local oweps = ent.JSWepTable
        local opock = ent.darkRPPocket or {}

        -- The weapons on person search
        for k,v in pairs(oweps) do
            if table.HasValue(PoliceSystem.SearchSeizeItems, v) then
                returntable.wep[v] = 0
            end
        end

        -- The pocket search
        for k,v in pairs(opock) do
            if v.ClassName == "spawned_weapon" then
                local ttb = v.DT.WeaponClass
                if table.HasValue(PoliceSystem.SearchSeizeItems, ttb) then
                    returntable.pock.wep[ttb] = k
                end
            elseif v.ClassName == "spawned_shipment" then
                local ships = CustomShipments[v.DT.contents]
                if table.HasValue(PoliceSystem.SearchSeizeItems, ships.entity) then
                    local rst = ships["name"]
                    returntable.pock.ship[rst .. " Shipment"] = k
                end
            else
                if table.HasValue(PoliceSystem.SearchSeizeItems, v.ClassName) then
                    local miscw = v.PrintName
                    returntable.pock.misc[miscw] = k
                end
            end
        end

        return returntable
    end

    -- Returns the amount of time left in jail
    function PolSys.jailTimeLeft(ply)

        local timetable = ply.JStimetable

        return timetable.arresttime - (CurTime() - timetable.starttime)
    end

    -- This is for the restrain function (Don't want it constantly writing)
    function PolSys.removeWeps(ply)

        local weaponstable = ply:GetWeapons()
        ply:StripWeapons()

        ply.JSWepTable = {}
        ply.JSAmmoTable = {}
        ply.JSAmmoTable2 = {}

        for k,v in pairs(weaponstable) do
            ply.JSWepTable[k] = v:GetClass()
            ply.JSAmmoTable[v:GetPrimaryAmmoType()] = ply:GetAmmoCount(v:GetPrimaryAmmoType())
            ply.JSAmmoTable2[v:GetSecondaryAmmoType()] = ply:GetAmmoCount(v:GetSecondaryAmmoType())
        end
    end

    -- Restrain the player
    function PolSys.restrainPly(ply) -- ply is perp

        ply:ChatPrint("You were restrained!")
        ply:EmitSound("weapons/p90/p90_clipin.wav")

        PolSys.removeWeps(ply)

        /* -- Tried saving the old data but didn't work. Meh
        local function unrestraindataTable()

            local boneyc = ply:GetBoneCount()
            local curboneTable = {}

            while boneyc >= 0 do
                curboneTable[boneyc] = ply:GetManipulateBoneAngles(boneyc)
                boneyc = boneyc - 1
            end

            local UnrestrainData = {}
            UnrestrainData.MOVETYPE = ply:GetMoveType()
            UnrestrainData.BonePos = curboneTable

            return UnrestrainData
        end

        ply.olddataur = unrestraindataTable()

        -- Send the data of old ply data to the ply when unrestraining
        net.Receive("RestrainTableSV", function(len, ply)

            net.Start("RestrainTableCL")
                net.WriteTable(ply.olddataur)
            net.Send(ply)
        end)
        */

        ply:SetMoveType(MOVETYPE_NONE)
        ply:SetNWBool("JSRestrained", true) -- set the bool of being restrained

        local RBS = {}
        RBS.Head = ply:LookupBone("ValveBiped.Bip01_Head1")
        RBS.Neck = ply:LookupBone("ValveBiped.Bip01_Neck1")
        RBS.Spine1 = ply:LookupBone("ValveBiped.Bip01_Spine1")
        RBS.Spine2 = ply:LookupBone("ValveBiped.Bip01_Spine2")
        RBS.Spine3 = ply:LookupBone("ValveBiped.Bip01_Spine4")
        RBS.Pelvis = ply:LookupBone("ValveBiped.Bip01_Pelvis")
        RBS.LShoulder = ply:LookupBone("ValveBiped.Bip01_L_Clavicle")
        RBS.RShoulder = ply:LookupBone("ValveBiped.Bip01_R_Clavicle")
        RBS.LUpArm = ply:LookupBone("ValveBiped.Bip01_L_UpperArm")
        RBS.RUpArm = ply:LookupBone("ValveBiped.Bip01_R_UpperArm")
        RBS.LFArm = ply:LookupBone("ValveBiped.Bip01_L_Forearm")
        RBS.RFArm = ply:LookupBone("ValveBiped.Bip01_R_Forearm")
        RBS.LHand = ply:LookupBone("ValveBiped.Bip01_L_Hand")
        RBS.RHand = ply:LookupBone("ValveBiped.Bip01_R_Hand")
        RBS.LHandAtt = ply:LookupBone("ValveBiped.Anim_Attachment_LH")
        RBS.RHandAtt = ply:LookupBone("ValveBiped.Anim_Attachment_RH")
        RBS.LThigh = ply:LookupBone("ValveBiped.Bip01_L_Thigh")
        RBS.RThigh = ply:LookupBone("ValveBiped.Bip01_R_Thigh")
        RBS.LCalf = ply:LookupBone("ValveBiped.Bip01_L_Calf")
        RBS.RCalf = ply:LookupBone("ValveBiped.Bip01_R_Calf")
        RBS.LFoot = ply:LookupBone("ValveBiped.Bip01_L_Foot")
        RBS.RFoot = ply:LookupBone("ValveBiped.Bip01_R_Foot")

        if isnumber(RBS.Head) then
            ply:ManipulateBoneAngles(RBS.Head, Angle(0,0,0))
            ply:ManipulateBoneAngles(RBS.Neck, Angle(0,0,0))
            ply:ManipulateBoneAngles(RBS.Spine1, Angle(0,0,0))
            ply:ManipulateBoneAngles(RBS.Spine2, Angle(0,0,0))
            ply:ManipulateBoneAngles(RBS.Spine3, Angle(0,0,0))
            ply:ManipulateBoneAngles(RBS.Pelvis, Angle(0,0,0))
            ply:ManipulateBoneAngles(RBS.LShoulder, Angle(25,0,0))
            ply:ManipulateBoneAngles(RBS.RShoulder, Angle(-25,0,0))
            ply:ManipulateBoneAngles(RBS.LUpArm, Angle(-10,0,0))
            ply:ManipulateBoneAngles(RBS.RUpArm, Angle(10,0,0))
            ply:ManipulateBoneAngles(RBS.LFArm, Angle(20,0,0))
            ply:ManipulateBoneAngles(RBS.RFArm, Angle(-20,0,0))
            ply:ManipulateBoneAngles(RBS.LHand, Angle(0,-15,70))
            ply:ManipulateBoneAngles(RBS.RHand, Angle(0,-15,-70))
            ply:ManipulateBoneAngles(RBS.LThigh, Angle(0,0,0))
            ply:ManipulateBoneAngles(RBS.RThigh, Angle(0,0,0))
            ply:ManipulateBoneAngles(RBS.LCalf, Angle(0,0,0))
            ply:ManipulateBoneAngles(RBS.RCalf, Angle(0,0,0))
            ply:ManipulateBoneAngles(RBS.LFoot, Angle(0,0,0))
            ply:ManipulateBoneAngles(RBS.RFoot, Angle(0,0,0))
        end

        ply:Give("police_restrained")
        ply:SelectWeapon("police_restrained") -- In case something goofs up and the or isn't active weapon yet (apperantly very much needed)

        --return unrestraindataTable() -- Had this for other reasons
    end

    -- This is for the unrestrain function (I don't want this function writing everytime it's called)
    function PolSys.returnWeps(ply)

        for k,v in pairs(ply.JSWepTable) do
            ply:Give(v)
        end

        for k,v in pairs(ply.JSAmmoTable) do
            ply:SetAmmo(v, k)
        end
        for k,v in pairs(ply.JSAmmoTable2) do
            ply:SetAmmo(v, k)
        end
        ply.JSWepTable = {}
        ply.JSAmmoTable = {}
        ply.JSAmmoTable2 = {}
    end

    -- Unrestrains the player
    function PolSys.unrestrainPly(ply, returnweps)

        if returnweps == nil or NULL then -- in case I forget to set a number when I call this function
            returnweps = true
        end

        ply:EmitSound("weapons/elite/elite_sliderelease.wav")
        ply:StripWeapon("police_restrained")

        if IsValid(ply) then
            local rbones = ply:GetBoneCount()

            while rbones >= 0 do

                ply:ManipulateBoneAngles(rbones, Angle(0,0,0))

                rbones = rbones - 1
            end

            ply:SetMoveType(MOVETYPE_WALK)
            ply:SetNWBool("JSRestrained", false)
            if returnweps then
                PolSys.returnWeps(ply)
            end
        end
    end

    -- Resets vars and hooks of escort
    function PolSys.resetEscort(plyy) -- plyy is the cop
        local ent1 = plyy:GetNWEntity("JSEscortPerp")
        ent1:SetNWBool("JSEscorted", false)
        plyy:SetNWBool("JSEscorting", false)
        plyy:SetNWEntity("JSEscortPerp", nil)
        ent1:SetNWEntity("JSEscortCop", nil)
        ent1.JSOCollide = false
        hook.Remove("Think", "JSES" .. plyy:SteamID64())
    end

    -- Resets the collisions of the escortee
    function PolSys.resetColls(ent1) -- ent1 is the perp

        ent1:SetMoveType(MOVETYPE_WALK)

        if not(ent1.JSOCollide) then
            ent1:SetCollisionGroup(COLLISION_GROUP_NONE)
        else
            ent1:SetCollisionGroup(ent1.JSOCollide)
        end
    end

    -- Starts/Resets Restrained Timer
    function PolSys.timerRS(ent, ply, start)

        local entst = ent:SteamID64()

        local function JSreTFunction()
            if ent:GetNWBool("JSEscorted", false) then -- If the perp is being escorted then
                PolSys.resetEscort(ent:GetNWEntity("JSEscortCop", ply)) -- We're gonna assume ply is the actual cop, but just in-case, we'll make it the fall back.
                PolSys.resetColls(ent)
                ent:ChatPrint("You were automaticlly unescorted/unrestrained!")
                PolSys.unrestrainPly(ent, true)
            elseif ent:GetNWBool("JSRestrained") then -- Check for restrain bool next ( if isn't being escorted)
                ent:ChatPrint("You were automaticlly unrestrained!")
                PolSys.unrestrainPly(ent, true)
            end
        end

        if start then -- If we are starting the timer
            timer.Create("JSRestrainedEnt" .. ent:SteamID64(), PoliceSystem.RestrainingTimer, 1, function()
                JSreTFunction()
            end)
        elseif not(start) then -- I know I can do a "else" but incase something goofs up, I don't want it running like that.
            if timer.Exists("JSRestrainedEnt" .. entst) then
                timer.Adjust("JSRestrainedEnt" .. entst, PoliceSystem.RestrainingTimer, 1, function()
                    JSreTFunction()
                end)
            end
        end
    end

    -- Check if escorting can be stopped
    function PolSys.canStopEscort(ply, ent)


        -- Deny messege
        local function jdenymsg()
            net.Start("JSEscortPlyCL")
                net.WriteBool(true)
                net.WriteInt(105,32)
            net.Send(ply)
            return false
        end

        -- Check if the ent(perp) is colliding with anything (above his disgusting feet)
        local function jstuckent()
            
            local pos = ent:GetPos()
            local tracedata = {}
            tracedata.start = pos
            tracedata.endpos = pos
            tracedata.filter = ent
            tracedata.mins = ent:OBBMins() + Vector(0,0,10) -- Adding a little z for ignoring the feet
            tracedata.maxs = ent:OBBMaxs()
            local trace = util.TraceHull( tracedata )

            if trace.Entity and (trace.Entity:IsWorld() or trace.Entity:IsValid()) then -- I copy pasated this from FP, thanks bobbleheadbob
                return false --They're touching something.
            else
                return true
            end
        end

        local trdata = util.TraceLine({ -- Our trace data between ply and ent
            start = ply:GetPos() + Vector(0,0,50), -- Starts at ply
            endpos = ent:GetPos() + Vector(0,0,50), -- Ends at ent(perp)
            filter = {ply, ent} -- Ignore if the "wall" is the perp or cop
        })
        local gtrdata = util.QuickTrace(ent:GetPos(), Vector(0,0,-46), ent) -- Check the ground distance, ignore perp
        local ctrdata = util.QuickTrace(ent:GetPos(), Vector(0,0,72), ent) -- Check the ceiling distance, ignore perp

        if (ent:IsInWorld()) && not(trdata.Hit) then -- If there is nothing between the two, and perp is in the world
            if (gtrdata.Hit)  && not(ctrdata.Hit) && jstuckent() then -- If the ground is close enough, and not hitting ceiling.
                return true
            else
                jdenymsg()
            end
        else
            jdenymsg()
        end
    end

    -- This function is for the net.Receive(Seize)
    function PolSys.countSeizeWeps(wtable)

        local qnum = 0

        for k,v in pairs(wtable.wep) do
            qnum = qnum + 1
        end

        for k,v in pairs(wtable.pock.wep) do
            qnum = qnum + 1
        end

        for k,v in pairs(wtable.pock.ship) do
            qnum = qnum + 1
        end

        for k,v in pairs(wtable.pock.misc) do
            qnum = qnum + 1
        end

        return qnum
    end

-- Charge Functions --

    -- Add Murder Charge
    function PolSys.addMurder(plyarg)

        if plyarg:IsPlayer() then

            local charges = plyarg.JSCTable
            charges["Murder"] = charges["Murder"] + 1
            file.Write("jsystem/charges/" .. plyarg:SteamID64() .. ".txt", util.TableToJSON(charges))
            plyarg.JSCTable = charges
        end
    end

    -- Add Carjacking Charge
    function PolSys.addCarJack(plyarg)

        local charges = plyarg.JSCTable
        charges["CarJacking"] = charges["CarJacking"] + 1
        file.Write("jsystem/charges/" .. plyarg:SteamID64() .. ".txt", util.TableToJSON(charges))
        plyarg.JSCTable = charges
    end

    -- Add Hit and Run Charge
    function PolSys.addHitRun(plyarg)

        local charges = plyarg.JSCTable
        charges["HitRun"] = charges["HitRun"] + 1
        file.Write("jsystem/charges/" .. plyarg:SteamID64() .. ".txt", util.TableToJSON(charges))
        plyarg.JSCTable = charges
    end

    -- Adds Terrorism Charge
    function PolSys.addTerror(plyarg)

            plyarg.TerrorTouch = true
            local charges = plyarg.JSCTable
            charges["Terrorism"] = charges["Terrorism"] + 1

            file.Write("jsystem/charges/" .. plyarg:SteamID64() .. ".txt", util.TableToJSON(charges))
            plyarg.JSCTable = charges
    end

    -- Adds Contraband Charge
    function PolSys.addContraband(plyarg)
        local charges = plyarg.JSCTable
        charges["Contraband"] = charges["Contraband"] + 1
        file.Write("jsystem/charges/" .. plyarg:SteamID64() .. ".txt", util.TableToJSON(charges))
        plyarg.JSCTable = charges
    end

    -- Adds Mugging Charge
    function PolSys.addMug(plyarg)
        local charges = plyarg.JSCTable
        charges["Mugging"] = charges["Mugging"] + 1
        file.Write("jsystem/charges/" .. plyarg:SteamID64() .. ".txt", util.TableToJSON(charges))
        plyarg.JSCTable = charges
    end

    -- Adds Illegal Weapons Charge
    function PolSys.addIllWep(plyarg)
        local charges = plyarg.JSCTable
        charges["IllegalWeapons"] = charges["IllegalWeapons"] + 1
        file.Write("jsystem/charges/" .. plyarg:SteamID64() .. ".txt", util.TableToJSON(charges))
        plyarg.JSCTable = charges
    end

    -- Adds Burglary Charge
    function PolSys.addBurglary(plyarg)
        local charges = plyarg.JSCTable
        charges["Burglary"] = charges["Burglary"] + 1
        file.Write("jsystem/charges/" .. plyarg:SteamID64() .. ".txt", util.TableToJSON(charges))
        plyarg.JSCTable = charges
    end

-- Net Crimes/Checks --

    -- Net Name
    net.Receive("JSConfirmCheckSV", function(len, ply)

        local ent = net.ReadEntity()
        local charges = ent.JSCTable
        local crimess = 0

        if not(PolSys.isJob(ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isPlyNear(ent, ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isRestrained(ent, ply, "JSDenyMsgCL")) then return end
        if PolSys.isEscorted(ent, ply, "JSDenyMsgCL") then return end -- beingEscorted returns true if being escorted

        for k,v in pairs(charges) do
            crimess = crimess + v
        end

        if (crimess > 0) then
             net.Start("JSConfirmCheckCL")
                net.WriteBool(true) -- If At Player
                net.WriteInt(0, 32) -- Just a filler
                net.WriteBool(true) -- If Wanted
                net.WriteString(ent:GetName())
            net.Send(ply)
        elseif not(crimess > 0) then
            net.Start("JSDenyMsgCL") -- custom Deny Msg Net Format
                net.WriteBool(false) 
                net.WriteInt(3, 32) -- person isn't wanted
            net.Send(ply)
        end
    end)

    -- Net Pardon 
    net.Receive("JSPardonSV", function(len, ply)

        local ent = net.ReadEntity()

        if not(PolSys.isJob(ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isPlyNear(ent, ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isRestrained(ent, ply, "JSDenyMsgCL")) then return end
        if PolSys.isEscorted(ent, ply, "JSDenyMsgCL") then return end -- beingEscorted returns true if being escorted
        if not(PolSys.isWanted(ply, "JSDenyMsgCL", ent.JSCTable)) then return end
        
        PolSys.clearCrimes(ent)
        PolSys.unrestrainPly(ent, true)
        ent:ChatPrint("You were unrestrained")
        PrintMessage(3, ply:GetName() .. " has pardoned " .. ent:GetName() .. "!")
    end)

    -- Net Ticket Confirm
    net.Receive("JSTicketSV1", function(len, ply)

        local ent = net.ReadEntity()

        if not(PolSys.isJob(ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isPlyNear(ent, ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isRestrained(ent, ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isWanted(ply, "JSDenyMsgCL", ent.JSCTable)) then return end
        if PolSys.isEscorted(ent, ply, "JSDenyMsgCL") then return end -- Check to make sure perp isn't being escorted
        
        if PolSys.crimeFine(ent) > 0 then
            net.Start("JSTicketCL1")
                net.WriteBool(true)
                net.WriteInt(PolSys.crimeFine(ent), 32)
            net.Send(ply)
        end

    end)

    -- Net Ticket Check If Can Send
    net.Receive("JSTicketSV2", function(len, ply)

        local ent = net.ReadEntity()
        local fineamount = PolSys.crimeFine(ent)
      
        if not(PolSys.isPlyNear(ent, ply, "JSDenyMsgCL")) then return end

        if fineamount > 0 then
            if not(ent:GetNWBool("JSTicketPay")) then
                net.Start("JSTicketCL2")
                    net.WriteBool(true)
                    net.WriteInt(0, 32)
                    net.WriteBool(true)
                net.Send(ply)
            else
                net.Start("JSDenyMsgCL")
                    net.WriteBool(true)
                    net.WriteInt(5, 32)
                net.Send(ply)
            end
        else
            net.Start("JSDenyMsgCL") -- Custom deny msg in CL (won't be the same net format)
                net.WriteBool(false)
                net.WriteInt(3, 32)
            net.Send(ply)
        end
    end)

    -- Net Ticket Actual Sending
    net.Receive("JSTicketSV3", function(len, ply)

        local ent = net.ReadEntity()

        PolSys.timerRS(ent, ply, false)

        ent:SetNWBool("JSTicketPay", true)
        timer.Create("JSResetTicketPerp" .. ent:SteamID64(), 10, 1, function() -- timer to reset the ability to give another ticket to that player
            ent:SetNWBool("JSTicketPay", false)
        end)

        net.Start("JSTicketCL3")
            net.WriteInt(PolSys.crimeFine(ent), 32)
            net.WriteEntity(ply)
        net.Send(ent)
    end)

    -- Net Ticket If Ticket Paid
    net.Receive("JSTicketSV4", function(len, ply)

        local cop = net.ReadEntity()
        local numcheck = net.ReadInt(32)
        ply:SetNWBool("JSTicketPay", false)

        if numcheck == 1 then
            local amount = PolSys.crimeFine(ply)
            local camount = amount - (amount * 2)
            local compfcop = ((amount/100) * PoliceSystem.CopPercentage)
            local compfcop = math.floor(compfcop)

            if ply:canAfford(camount) then
                ply:addMoney(camount)
                cop:addMoney(compfcop)
                net.Start("JSTicketCL2")
                    net.WriteBool(true)
                    net.WriteInt(1, 32)
                net.Send(cop)
            else
                net.Start("JSDenyMsgCL")
                    net.WriteBool(true)
                    net.WriteInt(4, 32)
                net.Send(cop)
            end

        elseif numcheck == 2 then

            net.Start("JSTicketCL2")
                net.WriteBool(true)
                net.WriteInt(2, 32)
            net.Send(cop)
        end
    end)

    -- Net Send To Jail
    net.Receive("JSSendJailSV", function(len, ply)

        local ent = net.ReadEntity()

        if not(PolSys.isJob(ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isPlyNear(ent, ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isRestrained(ent, ply, "JSDenyMsgCL")) then return end
        if PolSys.isEscorted(ent, ply, "JSDenyMsgCL") then return end                  
        if not(PolSys.isWanted(ply, "JSDenyMsgCL", ent.JSCTable)) then return end

        local jailtime = PolSys.jailTime(ent)
        ent:arrest(jailtime, ply) -- DarkRp Function
    end)

    -- Net View Crimes
    net.Receive("JSViewCrimesSV", function(len, ply)

        local ent = net.ReadEntity()

        if not(PolSys.isJob(ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isPlyNear(ent, ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isRestrained(ent, ply, "JSDenyMsgCL")) then return end
        if PolSys.isEscorted(ent, ply, "JSDenyMsgCL") then return end
        
        local crimetable = PolSys.getCrimes(ent)

        net.Start("JSViewCrimesCL")
            net.WriteBool(true)
            net.WriteInt(0,32)
            net.WriteTable(crimetable)
        net.Send(ply)
    end)

    -- Net Search Person
    net.Receive("JSSearchPersonSV", function(len, ply)

        local ent = net.ReadEntity()

        if not(PolSys.isJob(ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isPlyNear(ent, ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isRestrained(ent, ply, "JSDenyMsgCL")) then return end
        if PolSys.isEscorted(ent, ply, "JSDenyMsgCL") then return end 
        
        local searchtable = PolSys.searchSeize(ent)
        net.Start("JSSearchPersonCL")
            net.WriteBool(true)
            net.WriteInt(0, 32)
            net.WriteTable(searchtable)
        net.Send(ply)
    end)

    -- Net Seize Items
    net.Receive("JSSeizeItemsSV", function(len, ply)

        local ent = net.ReadEntity()

        if not(PolSys.isJob(ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isPlyNear(ent, ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isRestrained(ent, ply, "JSDenyMsgCL")) then return end
        if PolSys.isEscorted(ent, ply, "JSDenyMsgCL") then return end 

        local seizetable = PolSys.searchSeize(ent)

        local numnum = PolSys.countSeizeWeps(seizetable)

        if numnum > 0 then

            if PoliceSystem.DropRemoveSeize == false then
                local timernum = 1 -- I need this here for the incremental value of making sure all the weapons don't drop all at once, don't you dare touch it.
                for k,v in pairs(seizetable.wep) do -- k is the class name, v is just 0 :/ .
                    timer.Simple(timernum, function()
                        local ssweapon = ents.Create(k)
                        if (not(IsValid(ssweapon))) then return end -- In case something goofs up
                        ssweapon:SetPos(ent:GetPos() + ent:GetForward()*80)
                        ssweapon:Spawn()
                        table.RemoveByValue(ent.JSWepTable, k) -- Removes the weapon name from the plys table
                        print(k)
                    end)
                    timernum = timernum + 1
                end

                for k,v in pairs(seizetable.pock.wep) do
                    timer.Simple(timernum, function()
                        ent:dropPocketItem(v)
                    end)
                    timernum = timernum + 1
                end

                for k,v in pairs(seizetable.pock.ship) do
                    timer.Simple(timernum, function()
                        ent:dropPocketItem(v)
                    end)
                    timernum = timernum + 1
                end

                for k,v in pairs(seizetable.pock.misc) do
                    timer.Simple(timernum, function()
                        ent:dropPocketItem(v)
                    end)
                    timernum = timernum + 1
                end

                net.Start("JSSeizeItemsCL")
                    net.WriteBool(true)
                    net.WriteInt(101 ,32)
                net.Send(ply)

            elseif PoliceSystem.DropRemoveSeize then

                for k,v in pairs(seizetable.wep) do
                    ent:StripWeapon(k:GetClass())
                end

                for k,v in pairs(seizetable.pock.wep) do
                    ent:removePocketItem(v)
                end

                for k,v in pairs(seizetable.pock.ship) do
                    ent:removePocketItem(v)
                end

                for k,v in pairs(seizetable.pock.misc) do
                    ent:removePocketItem(v)
                end

                net.Start("JSSeizeItemsCL")
                    net.WriteBool(true)
                    net.WriteInt(102 ,32)
                net.Send(ply)
            end

        elseif numnum == 0 then
            net.Start("JSSeizeItemsCL")
                net.WriteBool(true)
                net.WriteInt(103, 32)
            net.Send(ply)
        end
    end)

    -- Net Escort/Unescort Person
    net.Receive("JSEscortPlySV", function(len, ply)

        local ent = net.ReadEntity()

        -- The Escort "function" / Error Msg
        if not(PolSys.isJob(ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isPlyNear(ent, ply, "JSDenyMsgCL")) then return end
        
        if not(ply:GetNWBool("JSEscorting")) && not(ent:GetNWBool("JSEscorted")) && (ent:GetNWBool("JSRestrained"))then -- If perp isn't being escorted and cop isn't escorting

            PolSys.timerRS(ent, ply, false) -- Reset the restrained timer

            -- Sets the vars and bools for much needed information (collisions, bool checks and ply objects in the ply tables)
            ent:SetNWBool("JSEscorted", true)
            ply:SetNWBool("JSEscorting", true)
            ply:SetNWEntity("JSEscortPerp", ent)
            ent:SetNWEntity("JSEscortCop", ply)
            ent.JSOCollide = ent:GetCollisionGroup()
            ent:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
            ent:SetMoveType(MOVETYPE_NOCLIP)

            -- This hook sets the perps position based on the eye trace of the cop (Unit Circle Style)
            hook.Add("Think", "JSES" .. ply:SteamID64(), function()

                local JSradius = PoliceSystem.EscortDistance
                local copcurpos = ply:GetPos()
                local perpcurpos = ent:GetPos()
                local eyeang = ply:EyeAngles().y
                local angle = math.rad(eyeang)
                local newx = JSradius * math.cos(angle) + copcurpos.x
                local newy = JSradius * math.sin(angle) + copcurpos.y

                ent:SetPos(Vector(newx, newy, copcurpos.z))
                ent:SetEyeAngles(Angle(0, tonumber(eyeang), 0))
            end)

            -- Sends a msg to the cop
            net.Start("JSEscortPlyCL")
                net.WriteBool(true) -- Ply bool
                net.WriteInt(102, 32)
            net.Send(ply)
        
        elseif not(ent:GetNWBool("JSRestrained")) && not(ply:GetNWBool("JSEscorting")) then -- Checks if ply is restrained

            -- Send a msg saying the ply isn't restrained
            net.Start("JSEscortPlyCL")
                net.WriteBool(true) -- Ply bool
                net.WriteInt(101, 32) -- Int Msg
            net.Send(ply)

        -- The Unescort "function"
        elseif ply:GetNWBool("JSEscorting") then -- No need to do checks since you can only start escorting when you pass checks
            if PolSys.canStopEscort(ply, ent) then

                PolSys.timerRS(ent, ply, false) -- Reset the timer for unrestraining of the ply's perp

                PolSys.resetColls(ply:GetNWEntity("JSEscortPerp")) -- If something screws up here, it's a problem with the inital escort
                PolSys.resetEscort(ply)

                -- Send a "Stopped escorting" msg
                net.Start("JSEscortPlyCL") 
                    net.WriteBool(true) -- Ply bool
                    net.WriteInt(103, 32) -- Msg Int
                net.Send(ply)
            end
        
        else -- Incase the code screw's up
            
            net.Start("JSEscortPlyCL") -- Write "You can't escort"
                net.WriteBool(true) -- Write a bool saying it's a perp
                net.WriteInt(104, 32) -- Int for what to do in client side
            net.Send(ply)
        end
    end)

    -- Net Restrain/Unrestrain Person
    net.Receive("JSRestrainPlySV", function(len, ply)

        local ent = net.ReadEntity()

        if not(PolSys.isJob(ply, "JSDenyMsgCL")) then return end
        if not(PolSys.isPlyNear(ent, ply, "JSDenyMsgCL")) then return end
        
        if not(ent:GetNWBool("JSRestrained")) then

            PolSys.restrainPly(ent)
            PolSys.timerRS(ent, ply, true) -- Adds the true so that "it starts" and not resets

            net.Start("JSRestrainPlyCL")
                net.WriteBool(true)
                net.WriteInt(101, 32)
            net.Send(ply)

        elseif ent:GetNWBool("JSRestrained") then -- This is the function when the cop unrestrains
            if not(PolSys.isEscorted(ent, ply, "JSDenyMsgCL")) then -- Check to make sure perp isn't being escorted

                PolSys.unrestrainPly(ent, true)
                ent:ChatPrint("You were unrestrained!")

                net.Start("JSRestrainPlyCL")
                    net.WriteBool(true)
                    net.WriteInt(102, 32)
                net.Send(ply)
            end
        end
    end)

--Function to delete outdated Data files
local function JSDeleteOutDateFile()

    if PoliceSystem.DeleteDaFiles == true then
        local FileTable1 = file.Find("jsystem/charges/*.txt", "DATA")
        local FileTable2 = file.Find("jsystem/arresttime/*.txt", "DATA")

        for k,v in pairs(FileTable2) do

            if v ~= "timeupdate.txt" then

                file.Write("jsystem/charges/timeupdate.txt", "TimeCheck")
                local CheckTime = file.Time("jsystem/charges/" .. v, "DATA")
                local CurrentTime = file.Time("jsystem/charges/timeupdate.txt", "DATA")

                if CurrentTime > CheckTime + (PoliceSystem.TimeFileDeleteDelayCharges * 60) then
                    file.Delete("jsystem/charges/" .. v)
                end
            end
        end

        for k,v in pairs(FileTable2) do

            if v ~= "timeupdate.txt" then

                file.Write("jsystem/arresttime/timeupdate.txt", "TimeCheck")
                local CheckTime = file.Time("jsystem/arresttime/" .. v, "DATA")
                local CurrentTime = file.Time("jsystem/arresttime/timeupdate.txt", "DATA")

                if CurrentTime > CheckTime + (PoliceSystem.TimeFileDeleteDelayArrest * 60) then
                    file.Delete("jsystem/arresttime/" .. v)
                end
            end
        end

    end
end

--Check if the Time File Updater Exists
local function JSWriteTimeFile()

    if not(file.Exists("jsystem/charges/timeupdate.txt", "DATA")) then
        file.Write("jsystem/charges/timeupdate.txt", "TimeCheck")
    end
    if not(file.Exists("jsystem/arresttime/timeupdate.txt", "DATA")) then
        file.Write("jsystem/arresttime/timeupdate.txt", "TimeCheck")
    end
end

--Check Police System Directory
if not(file.IsDir("jsystem", "DATA")) then

    file.CreateDir("jsystem")
end

--Check Charges Directory
if not(file.IsDir("jsystem/charges", "DATA")) then

    file.CreateDir("jsystem/charges")
end

--Check Arrest Time Directory
if not(file.IsDir("jsystem/arresttime", "DATA")) then

    file.CreateDir("jsystem/arresttime")
end

--Check if Ply Data File Exists
local function JScheckdata(ply)
    local newJSCTable = {}
    if not (file.Exists("jsystem/charges/" .. ply:SteamID64() .. ".txt", "DATA")) then
        newJSCTable = {
        ["Murder"] = 0,
        ["Burglary"] = 0,
        ["CarJacking"] = 0,
        ["IllegalWeapons"] = 0,
        ["Contraband"] = 0,
        ["Mugging"] = 0,
        ["Terrorism"] = 0,
        ["HitRun"] = 0
        }
        file.Write("jsystem/charges/" .. ply:SteamID64() .. ".txt", util.TableToJSON(newJSCTable))

    elseif (file.Exists("jsystem/charges/" .. ply:SteamID64() .. ".txt", "DATA")) then
        newJSCTable = util.JSONToTable(file.Read("jsystem/charges/" .. ply:SteamID64() .. ".txt", "DATA"))
    end
    ply.JSCTable = newJSCTable
end

--Check On Ply Connect
hook.Add("PlayerAuthed", "JSCheckFile", function(ply)

    JScheckdata(ply)  
end)

--Init Hook to run config.lua/all other crap
hook.Add("Initialize", "JSConfigInit", function()

    if SERVER then
        JSWriteTimeFile() -- Update Time
        JSDeleteOutDateFile() -- Delete the old files
    end
end)

-- Charges --

--Murder Charge
hook.Add("PlayerSpawnedProp", "JSCheckPropMurder", function(ply, model, ent)

    ent.TheOwner = ply
end)

hook.Add("PlayerDeath", "JSMurder", function(vic, wep, killer)

    if not(wep:IsVehicle()) and wep:IsWeapon() then
        if (not(table.HasValue(PoliceSystem.MurderTable_1, killer:Team()))) and (killer ~= vic) and (PoliceSystem.MurderEnable == true) then
            PolSys.addMurder(killer)
        end
    elseif wep:IsVehicle() and IsValid(wep) and IsValid(wep:GetDriver()) then
        local killer1 = wep:GetDriver()
        if (not(table.HasValue(PoliceSystem.MurderTable_1, killer1:Team()))) and (killer1 ~= vic) and (PoliceSystem.MurderEnable == true) and (PoliceSystem.HitRunMurder == true) then
            PolSys.addMurder(wep:GetDriver())
        end
    elseif not(wep:IsVehicle()) and not(wep:IsWeapon()) then
        if IsValid(killer) then
            if killer ~= vic then
                PolSys.addMurder(killer)
            end
        elseif (wep.TheOwner == nil) then
            if wep:GetOwner() ~= vic then
                PolSys.addMurder(wep:GetOwner())
            end
        end        
    end
end)

--Burglary Charge
local function JSdoortable(ent)  --Table that checks for doors

    if table.HasValue(PoliceSystem.doorcheck, ent) then
        return true
    else
        return false
    end
end

hook.Add("KeyPress", "JSBurglary", function(ply, key)
    
    local eye = ply:GetEyeTrace()

    if not((key == IN_ATTACK) or (key == IN_ATTACK2)) then return end-- Checks KeyPressed
    if not(ply:Alive()) or not(IsValid(ply)) or not(IsValid(ply:GetActiveWeapon())) then return end -- Sometimes goofs up when ply rejoins with arrests, so we have this here to make sure everything is in order
    if not(table.HasValue(PoliceSystem.LockPickTable, ply:GetActiveWeapon():GetClass())) then return end -- Check what weapon ply is holding and if it in the table of lockpicks
    if not(JSdoortable(eye.Entity:GetClass())) and (eye.Fraction < 0.003070) then return end -- Checks if Distance and if door
    if not(ply.burglarytimer == nil or ply.burglarytimer < CurTime()) then return end -- Checks if timer exists or if time has passed
    if (table.HasValue(PoliceSystem.BurglaryTable_1, ply:Team()) and (PoliceSystem.BurglaryEnable)) then return end -- Checks job and if enabled

    ply.burglarytimer = CurTime() + PoliceSystem.DelayBurglaryTime
    PolSys.addBurglary(ply)
end)

--CarJacking Charge
local function JScheckVehicle(stringa) -- Check if ent is vehicle

    local ans = string.match(stringa, "vehicle")
    if ans == "vehicle" then
        return true
    else
        return false
    end
end

hook.Add("KeyPress", "JSCarJacking", function(ply, key)
    local eye = ply:GetEyeTrace()

    if eye.Entity:IsPlayer() then return end -- Makes sure the entity isn't a player
    if ply:isArrested() then return end -- Makes sure to not run when ply is arrested
    if not((key == IN_ATTACK) or (key == IN_ATTACK2)) then return end -- Checks KeyPressed
    if not(ply:Alive()) then return end -- If ply is ded...
    if not(table.HasValue(PoliceSystem.LockPickTable, ply:GetActiveWeapon():GetClass())) then return end-- Check what weapon ply is holding and if it in the table of lockpicks
    if not(JScheckVehicle(eye.Entity:GetClass()) and (eye.Entity:IsVehicle()) and (eye.Fraction < 0.003070)) then return end -- Checks if Distance and if door
    if (table.HasValue(PoliceSystem.CarJackTable_1, ply:Team()) and not(PoliceSystem.CarJackingEnable)) then return end -- Checks job and if enabled
    
    local ent = eye.Entity

    if not(ent[ply:SteamID64()]) then return end
    
    ent[ply:SteamID64()] = true
    PolSys.addCarJack(ply)
end)

--HitRun Charge
hook.Add("PlayerDeath", "JSHitRun", function(vic, wep, killer)

    if not(wep:IsVehicle() and IsValid(wep) and IsValid(wep:GetDriver())) then return end
    
    local killer1 = wep:GetDriver()
    
    if (table.HasValue(PoliceSystem.HitRunTable_1, killer1:Team()) and not(PoliceSystem.HitRunEnable)) then return end

    PolSys.addHitRun(killer1) 
end)

--Terrorism Charge
hook.Add("KeyPress", "JSTerrorism", function(ply, key)

    if not((key == IN_ATTACK) and PoliceSystem.TerrorismEnable) then return end
    if not(ply:Alive()) then return end
    if not(IsValid(ply:GetActiveWeapon())) then return end
    if not(table.HasValue(PoliceSystem.TerrorismWeapons, ply:GetActiveWeapon():GetClass())) then return end -- Checks if the weapon is in the list of terrorist weapons
                   
    local wep = ply:GetActiveWeapon()
    local AmmoType11 = nil
    
    if wep:GetPrimaryAmmoType() == -1 then -- Ammo Type Check
        AmmoType11 = wep:GetSecondaryAmmoType()
    elseif wep:GetPrimaryAmmoType() > -1 then
        AmmoType11 = wep:GetPrimaryAmmoType()
    end
    
    if (ply:GetAmmoCount(AmmoType11) > 0) then --Ammo Check 
        if PoliceSystem.TerrorJobCheck then -- Check what type of jobs to check for
            if table.HasValue(PoliceSystem.TerrorismJobTable_1, ply:Team()) then -- Checks if ply is that job
                PolSys.addTerror(ply)
            end
        elseif not(PoliceSystem.TerrorJobCheck) then -- Check what type of jobs to check for
            if not(table.HasValue(PoliceSystem.TerrorismJobTable_1, ply:Team())) then -- Checks if ply is not that job
                if plyarg.TerrorTouch == false or plyarg.TerrorTouch == nil then
                    PolSys.addTerror(ply)
                end
            end
        end
    end
end)

hook.Add("PlayerDeath", "JSTerrorismDeath", function(vic, wep, killer)

    vic.TerrorTouch = false
end)

--Mugging Charge
local function JSstringstarts(String,Start)

   return string.sub(String,1,string.len(Start))==Start
end

hook.Add("PlayerSay", "JSMugging", function(ply1, text1, team1)

    if team1 then return end -- If it's in teamchat

    local text1 = string.lower(text1)

    if not(JSstringstarts(text1, "!mug ")) then return end

    local text2 = string.gsub(text1, "!mug ", "") -- Removes the "!mug "

    local thing1 = string.gsub(text2, " ", "") -- Now it should be a number

    /*
    local thing1 = string.match(thing1, "%d+") -- Take the number in the string           
    local thing2 = string.gsub(text2, thing1, "") -- Now it should be just the name
    local thing2 = string.gsub(thing2, " ", "") -- Takes out all the spaces in the name
    local checknum = 0
    local name = nil

     -- This was to check for names
    for k,v in pairs(player.GetAll()) do

        if not(string.find(v:GetName(), thing2) == nil) then -- Check if the name exists in the server
            checknum = checknum + 1
        end

        if checknum == 1 then
            ply1.mugcheck = true
            checknum = 0
            name = v:GetName() -- Get the persons name
        elseif checknum ~= 1 then
            ply1.mugcheck = false
            checknum = 0
        end
    end
    */

    if (not(table.HasValue(PoliceSystem.MuggerJobTable_1, ply1:Team()))) and (PoliceSystem.MuggingEnable) then
        if (not(tonumber(thing1) == nil)) and ((ply1.mugcheck == nil) or (CurTime() > ply1.mugcheck)) then
            if (tonumber(thing1) < PoliceSystem.MaxMugging + 1) and (not(tonumber(thing1) < 10)) then

                ply1.mugcheck = CurTime() + PoliceSystem.MugDelaying

                PolSys.addMug(ply1)

                print("(Muggin): " .. ply1:GetName() .. " is mugging someone for $" .. thing1 .. "!")
                for k,v in pairs(player.GetAll()) do
                    v:ChatPrint("(Muggin): " .. ply1:GetName() .. " is mugging someone for $" .. thing1 .. "!")
                end
            elseif tonumber(thing1) < 10 then
                ply1:ChatPrint("You cannot mug someone below 10$!")
            else
                ply1:ChatPrint("You cannot mug for that much!")
            end

        elseif (not(type(tonumber(thing1)) == "number")) then
            ply1:ChatPrint("You must type in a number between 10 and " .. tostring(PoliceSystem.MaxMugging) .. "!")
        else
            ply1:ChatPrint("You can't mug right now.")
        end

    else
        ply1:ChatPrint("You can't mug right now.")
    end
end)

--Contraband Charge
/* -- This is for dev purposes
hook.Add("PlayerSay", "JSContrabandEntCheck", function(ply, text)

    if text == "!!GetEnt" then
        if ply:IsUserGroup("superadmin") or ply:IsSuperAdmin() or ply:IsAdmin() then

            local ent = ply:GetEyeTraceNoCursor().Entity

               -- Testing restrained bools.
            --if ent:IsPlayer() then
              --  if ent:GetNWBool("JSRestrained") then
                --    ent:SetNWBool("JSRestrained", false)
                --elseif ent:GetNWBool("JSRestrained") == false or ent:GetNWBool("JSRestrained") == nil then
                  --  ent:SetNWBool("JSRestrained", true)
                --end
                --PrintMessage(3, tostring(ent:GetNWBool("JSRestrained")))
            --end

            
            if ent:GetClass() == "spawned_shipment" then
                local contents = CustomShipments[ent:Getcontents()]
                ply:PrintMessage(3, tostring(contents["name"]))
            elseif ent:IsVehicle() then
                ply:PrintMessage(3, tostring(ent:GetClass()))
            elseif ent:IsWorld() then
                ply:PrintMessage(3, tostring(ent:GetClass()) .. " || This may print 'World' for you but acutally it is 'worldspawn'!")
            elseif ent:GetClass() == "spawned_weapon" then
                ply:PrintMessage(3, ent:GetWeaponClass())
            else
                ply:PrintMessage(3, tostring(ent:GetClass()))
            end
        end
    end
end)
*/

hook.Add("GravGunOnPickedUp", "JSContrabandGrav", function(ply, ent)

    if (table.HasValue(PoliceSystem.ContrabandJob_1, ply:Team()) and (not(PoliceSystem.ContrabandEnable))) then return end

    if ent:GetClass() == "spawned_shipment" then
        local contents = CustomShipments[ent:Getcontents()]
        if table.HasValue(PoliceSystem.ContrabandShip_1, contents["name"]) then
            if ent[ply:SteamID64()] == false or ent[ply:SteamID64()] == nil then
                ent[ply:SteamID64()] = true
                PolSys.addContraband(ply)
            end
        end
    elseif ent:GetClass() == "spawned_weapon" then
        if table.HasValue(PoliceSystem.ContrabandWep_1, ent:GetWeaponClass()) then
            if ent[ply:SteamID64()] == false or ent[ply:SteamID64()] == nil then
                ent[ply:SteamID64()] = true
                PolSys.addContraband(ply)
            end
        end
    else
        if table.HasValue(PoliceSystem.ContrabandXtra_1, ent:GetClass()) then
            if ent[ply:SteamID64()] == false or ent[ply:SteamID64()] == nil then
                ent[ply:SteamID64()] = true
                PolSys.addContraband(ply)
            end
        end
    end
end)

if PoliceSystem.ContrabandDarkRp then

    hook.Add("playerBoughtCustomEntity", "JSContrabandDarkEnt", function(ply, table1, ent1)

        if (not(table.HasValue(PoliceSystem.ContrabandJob_1, ply:Team())) and (PoliceSystem.ContrabandEnable == true)) then
            if table.HasValue(PoliceSystem.ContrabandXtra_1, tostring(ent1:GetClass())) then
                ent1[ply:SteamID64()] = true
                PolSys.addContraband(ply)
            end
        end
    end)

    hook.Add("playerBoughtPistol", "JSContrabandDarkWep", function(ply, table1, ent1)

        if (not(table.HasValue(PoliceSystem.ContrabandJob_1, ply:Team())) and (PoliceSystem.ContrabandEnable == true)) then
            if table.HasValue(PoliceSystem.ContrabandWep_1, ent1:GetWeaponClass()) then
                ent1[ply:SteamID64()] = true
                PolSys.addContraband(ply)
            end
        end
    end)

    hook.Add("playerBoughtShipment", "JSContrabandDarkShip", function(ply, table1, ent1)

        local contents = CustomShipments[ent1:Getcontents()]
        if (not(table.HasValue(PoliceSystem.ContrabandJob_1, ply:Team())) and (PoliceSystem.ContrabandEnable == true)) then
            if table.HasValue(PoliceSystem.ContrabandShip_1, tostring(contents["name"])) then
                ent1[ply:SteamID64()] = true
                PolSys.addContraband(ply)
            end
        end
    end)
end

--Illegal Weapon Charge
if PoliceSystem.ChoiceIWep then

    hook.Add("WeaponEquip", "JSPlyPickedIllegalWep", function(wep)

        timer.Simple(0, function()

            local ply = wep:GetOwner()

            if not(table.HasValue(PoliceSystem.IllegalWepJob_1, ply:Team())) and (PoliceSystem.IllegalWepEnable == true) then
                if (table.HasValue(PoliceSystem.IllegalWeapons_1, tostring(wep:GetClass()))) then

                    PolSys.addIllWep(ply)
                end
            end
        end)
    end)
elseif not(PoliceSystem.ChoiceIWep) then

    hook.Add("PlayerSwitchWeapon", "JSIllegalWeps", function (ply, prevwep, nextwep)

        if ply.illegalwep == nil then
            ply.illegalwep = {}
        end

        if not(table.HasValue(PoliceSystem.IllegalWepJob_1, ply:Team())) and (PoliceSystem.IllegalWepEnable == true) then
            if (table.HasValue(PoliceSystem.IllegalWeapons_1, tostring(nextwep:GetClass()))) then 
                if ply.illegalwep[tostring(nextwep:GetClass())] == nil or ply.illegalwep[tostring(nextwep:GetClass())] == false then

                    ply.illegalwep[tostring(nextwep:GetClass())] = true
                    PolSys.addIllWep(ply)
                end
            end
        end
    end)

    hook.Add("PlayerDeath", "JSRemoveIllWeps", function(ply)

        ply.illegalwep = {}
    end)

    if PoliceSystem.IWepDarkRp == true then

        hook.Add("playerArrested", "JSJailIWepRemove", function(ply)

            ply.illegalwep = {}
        end)
    end
end

-- Misc Hooks --

-- Prevent suicide when restrained
hook.Add("CanPlayerSuicide", "JSRestrainedSuicide", function(ply)

    if ply:GetNWBool("JSRestrained") then
        ply:ChatPrint("You can't kill yourself while restrained!")
        return false
    end
end)

-- Add 64ID when arrested/Clear Charges when Arrested/Save Time When Player Is Arrested/Unrestrain if restrained
hook.Add("playerArrested", "JSSystemSaveTime", function(ply, time, cop)

    if SERVER then
        local timetableJS = {}
        timetableJS.starttime = CurTime()
        timetableJS.arresttime = time

        ply.JStimetable = timetableJS
        file.Write("jsystem/arresttime/" .. ply:SteamID64() .. ".txt", tostring(time))
        timer.Simple(0, function()
            PolSys.clearCrimes(ply) -- Clear the charges
        end)

        -- Unrestrain if restrained
        if ply:GetNWBool("JSRestrained") then
            PolSys.unrestrainPly(ply, false)
            ply:ChatPrint("You were unrestrained!")
        end
    end
end)

-- Save Time When Player Disconnects/Send To Jail If Restrained
-- Checks for escorting/escorted
hook.Add("PlayerDisconnected", "JSPlyDisconnectTimeStamp", function(ply)

    -- Save Time
    if ply:isArrested() then
        local timeleft = math.ceil(PolSys.jailTimeLeft(ply))
        file.Write("jsystem/arresttime/" .. ply:SteamID64() .. ".txt", tostring(timeleft))
    end

    -- Send To Jail
    if ply:GetNWBool("JSRestrained") then
        constraint.RemoveConstraints(ply, "Rope") -- Removes nice little rope between two (now unrestrained) hands
        if PolSys.jailTime(ply) > 0 then
            ply:arrest(PolSys.jailTime(ply))
        end
    end

    -- Escort checks
     if ply:GetNWBool("JSEscorting", false) then -- The Cop
        PolSys.resetColls(ply:GetNWEntity("JSEscortPerp")) -- The arg is the perp
        PolSys.resetEscort(ply) -- The arg is the cop
    elseif ply:GetNWBool("JSEscorted", false) then -- The Perp
        PolSys.resetColls(ply) -- The arg is the perp
        PolSys.resetEscort(ply:GetNWEntity("JSEscortCop")) -- The arg is the cop
    end
end)

-- Send Player To Jail On Connect (if he has time)
-- Set Default Vars for the player (NWBools)
hook.Add("PlayerInitialSpawn", "JSJailConnect", function(ply)

    -- Send ply to jail if he's been a bad boy
    if file.Exists("jsystem/arresttime/" .. ply:SteamID64() .. ".txt", "DATA") then
        local timeleft = file.Read("jsystem/arresttime/" .. ply:SteamID64() .. ".txt", "DATA")
        -- Quick Frame Check To Init
        timer.Simple(0, function()
            ply:arrest(tonumber(timeleft))
        end)
    end

    -- Set all NWBools to false to prevent any unseen bugs
    ply:SetNWBool("JSRestrained", false) -- If person is restrained bool
    ply:SetNWBool("JSEscorting", false) -- If person is escorting someone bool
    ply:SetNWBool("JSEscorted", false) -- If person is being escorted bool
end)

-- Remove Time Stamp File When Unarrested
hook.Add("playerUnArrested", "JSRemoveFileArrestTime", function(ply)

    file.Delete("jsystem/arresttime/" .. ply:SteamID64().. ".txt")
    ply.JStimetable = {}
end)

-- Prevent a person being arrested while being escorted
hook.Add("canArrest", "JSPreventEscortArrest", function(cop, perp)

    if perp:GetNWBool("JSEscorted") then
        return false
    end
end)

-- Remove Default Arresting On Re-Join
hook.Remove("PlayerInitialSpawn", "Arrested")

-- Restart The Saved Weapon Tables/Ammo Tables (On Death)
-- Checks if restrained.
-- Checks if escorting or being escorted.
hook.Add("PlayerDeath", "JSAmmoWepTableRe", function(ply)

    ply.JSWepTable = {}
    ply.JSAmmoTable = {}
    ply.JSAmmoTable2 = {}

    -- Check if that person was restrained.
    if ply:GetNWBool("JSRestrained", false) then
        PolSys.unrestrainPly(ply, false)
        ply:ChatPrint("You were unrestrained!")
    end

    -- Check for escorting or escorted
    if ply:GetNWBool("JSEscorting", false) then -- The Cop
        PolSys.resetColls(ply:GetNWEntity("JSEscortPerp")) -- The arg is the perp
        PolSys.resetEscort(ply) -- The arg is the cop
    elseif ply:GetNWBool("JSEscorted", false) then -- The Perp
        PolSys.resetColls(ply) -- The arg is the perp
        PolSys.resetEscort(ply:GetNWEntity("JSEscortCop")) -- The arg is the cop
    end
end)

-- Prevent 'JSRestrained' swep from being dropped
hook.Add("canDropWeapon", "JSPreventRestrainDrop", function(ply, wep)
    if wep:GetClass() == "police_restrained" then -- If you want me to add cop checks, bite me. Why does the cop have this in the first place?
        return false
    end
end)

-- Prevent crouch if restrained
hook.Add("StartCommand", "JSPreventCrouch", function(ply, thecmd)
    -- A basic 'fuck you' if a person tries to crouch while restrained or really tries to do anything.
    if ply:GetNWBool("JSRestrained") then
        thecmd:ClearButtons()
        thecmd:ClearMovement()
    end
end)

-- Prevent job changing when restrained / set job later
hook.Add("playerCanChangeTeam", "JSPreventJobC", function(ply, jobnum)
    if ply:GetNWBool("JSRestrained") then
        hook.Remove("Think", "PolSys.restrainPlyJob" .. ply:SteamID64()) -- Removes the prevouis think, incase it exists
        hook.Add("Think", "PolSys.restrainPlyJob", function() -- Adds the think to switch job when unrestrained hook
            if not(ply:GetNWBool("JSRestrained")) then -- If not restrained
                ply:changeTeam(jobnum)
                hook.Remove("Think", "PolSys.restrainPlyJob") -- Removes think
            end
        end)
        return false
    end
end)

-- On job change reset escorting/restrain
hook.Add("OnPlayerChangedTeam", "JSTeamChangeReset", function(ply, teambefore, teamafter)
    if table.HasValue(PoliceSystem.AllowedJobsPoliceMenu, teambefore) then -- Checks if the job the person is switcing from is allowed to access the police menu.
        if not(table.HasValue(PoliceSystem.AllowedJobsPoliceMenu, teamafter)) then -- Making sure that the person isn't switching to another cop job
            if ply:GetNWBool("JSEscorting") then -- If the person is escorting
                ent = ply:GetNWEntity("JSEscortPerp")
                PolSys.resetColls(ent) -- The arg is the perp
                PolSys.resetEscort(ply) -- The arg is the cop
                PolSys.unrestrainPly(ent, true) -- Unrestrain the perp
                ent:ChatPrint("You were unrestrained!")
            end
        end
    end
end)

-- Prevent switching from restrain swep
hook.Add("PlayerSwitchWeapon", "JSPreventRestrainSwtich", function(ply, oldwep, newwep)
    if IsValid(oldwep) then -- Just a check for when a player spawns in.
        if oldwep:GetClass() == "police_restrained" then
            return true -- Prevent the swtich
        end
    end
end)

-- Prevent lockpicking on a person being escorted
hook.Add("canLockpick", "JSCanLockpick", function(ply, ente)
    if ente:GetNWBool("JSEscorted") then
        return false
    elseif ente:GetNWBool("JSRestrained") then -- Make it so the person is lockpickable
        return true
    end
end)

-- Unresrains the person is they were lockpicked
hook.Add("onLockpickCompleted", "JSLockpickRestrain", function(ply, succi, ente) -- succi, get it? ( ͡° ͜ʖ ͡°)
    if ente:GetNWBool("JSRestrained") then -- If not restrained
        if succi then -- If lockpick is successful
            if not(ente:GetNWBool("JSEscorted")) then -- If not being escorted (shouldn't be able to anyway, but you know, code likes to goof)
                PolSys.unrestrainPly(ente, true)
                ente:PrintMessage(3, "You were unrestrained!")
            end
        end
    end
end)

-- Prevents a weapon dupe
hook.Add("onDarkRPWeaponDropped", "JSPreventWeaponDupe", function(ply, entwep, swepwep)
    if ply:GetNWBool("JSRestrained") then
        table.RemoveByValue(ply.JSWepTable, swepwep:GetClass())
    end
end)

end) -- End of the Post Gamemode Hook


/*

*NOTICE*

    This work is copyrighted. Trying to steal it is a big no-no.
    Just to clarify a few things to save headaches. This isn't a terms of service, this is U.S law. (Which conditions apply to most countries out there too.)

    You cannot modify this work. (If you feel the need to, either make a pull request on the github this is hosted, or keep it local.)
    You cannot claim credit for this work.
    You cannot redistribute this work.

    Pretty much it. You can't do anything but use it. But I'm not done yet :D

*Terms of service*

    By using this addon you agree to my terms of service.

    I only have one term of service. 
    Even though this will be public, I still reserve my right to enact a DMCA claim on anyone who I think is abusing it.

    What constitutes abuse? In this terms of service, the definition of abuse is anything I don't like.
    It is extremely subjective, to which its definition can vary based on the creators(me) opinion.

    (In a nutshell, if I think you're doing scummy things and you're using my addon, I will DMCA you.
    And by using this addon, you agree to that.)

*/
-- original https://github.com/Heyter/Justice-System-DarkRp-
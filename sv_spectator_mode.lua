--original https://steamcommunity.com/sharedfiles/filedetails/?id=2263096878
concommand.Add("spectate", function(self, cmd, args)
	if self:IsAdmin() == false then
		self:ChatPrint("You need admin privileges to spectate!") return end
	if self:GetObserverMode() != 6 then
		self:ChatPrint("You are spectator now.\nTo exit spectator mode press R(+reload)")
		self:Flashlight(false)
		self.handsmodel = nil
		self:Spectate(6)
		self:SetObserverMode(6)
		self:SetColor(0, 0, 0, 255)
		self:SetModel("models/props_junk/watermelon01.mdl")
		self:StripWeapons()
		self:RemoveAllAmmo()
		--self:SetTeam(TEAM_SPECTATOR)
		self:SetNoDraw(true)
		self:SetNoTarget(true)
		self:AllowFlashlight(false)
	end
end)

hook.Add("KeyPress","key_exit_spectator", function(self, cmd, args)
	if self:GetObserverMode() == 6 and self:KeyPressed(IN_RELOAD) then
		self:UnSpectate()
		self:Spawn()
		self:SetNoDraw(false)
		self:SetNoTarget(false)
		self:AllowFlashlight(true)
	end
end)

hook.Add("PlayerUse", "spectator_prevent_use", PlayerUse)
hook.Add("CanPlayerSuicide", "spectator_prevent_suicide", CanPlayerSuicide)
hook.Add("PlayerSpray", "spectator_prevent_spray", PlayerSpray)

function GAMEMODE:CanPlayerSuicide(self, cmd, args)
	if self:GetObserverMode() == 6 then
	return false -- я запрещаю вам умирать за наблюдателя
	end
end

function GAMEMODE:PlayerSpray(self, cmd, args)
	if self:GetObserverMode() == 6 then
	return true -- я запрещаю вам ставить спрей за наблюдателя
	end
end

function GAMEMODE:PlayerUse(self, cmd, args)
	if self:GetObserverMode() == 6 then
	return false -- я запрещаю вам взаимодействовать с предметами за наблюдателя
	end
end
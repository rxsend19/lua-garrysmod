function HUD()
	local client = LocalPlayer()
	
	if !client:Alive() then		--Checks to see if the player is alive, if the player is dead, this stops drawing the HUD
		return
	end
	
	draw.RoundedBox(2, 0, ScrH() - 100, 250, 100, Color(50, 50, 50, 230))  --Draws a custom box for use in HUD display 
	draw.SimpleText("Health: "..client:Health(), "Trebuchet24", 10, ScrH() - 100, Color(255, 255, 255, 255), 0, 0)		--This draws the health display in the box, Draws simple text which contains the clients health "..client:Health()" "Trebuchet24" this defines the text font. ScrH() defines the screenheight
	draw.SimpleText("Armor: "..client:Armor().. "%" , "Trebuchet24", 10, ScrH() - 60, Color(255, 255, 255, 255), 0, 0)		--Same as above but draws Armor
	draw.RoundedBox(0, 10, ScrH() - 75, math.Clamp(client:Health(), 0, 100) * 2.2, 15, Color(0, 255, 0 , 255)) --Creates a rounded box below the Health display, math.Clamp() is used to find a middle value between 0 and 100, the clients health is used for a value, and this results in a health bar
	draw.RoundedBox(0, 10, ScrH() - 35, math.Clamp(client:Armor(), 0, 100) * 2.2, 15, Color(0, 255, 255, 255)) --Same as above but for Armor
	draw.RoundedBox(0, 10, ScrH() - 75, 100 * 2.2, 15, Color(0, 255, 0, 30)) --- Health special effect
	draw.RoundedBox(0, 10, ScrH() - 35, 100 * 2.2, 15, Color(0, 255, 255, 30)) --- Armor special effect
	
	draw.RoundedBox(0, 2, ScrH() - 800, 73, 25, Color(50, 50, 50, 230)) -- Moneybox
	draw.SimpleText("" .. client:GetNWInt("playerMoney") .. "$", "Trebuchet24", 10, ScrH() - 800, Color(255, 255, 255, 255), 0, 0) --Money text
	
	draw.RoundedBox(0, 255, ScrH() - 70, 150, 70, Color(30, 30, 30, 230))
	if (client:GetActiveWeapon():GetPrintName() ~= nil) then --This checks the players active weapon, then checks the print name of the weapon
		draw.SimpleText(client:GetActiveWeapon():GetPrintName(), "Trebuchet24", 260, ScrH() - 60, Color(255, 255, 255, 255), 0, 0) --This will print the players current weapon as a string in the rounded box above
	end
	
	if (client:GetActiveWeapon():Clip1() != -1) then --Checks players clip
		draw.SimpleText("Ammo: " .. client:GetActiveWeapon():Clip1() .. "/" .. client:GetAmmoCount(client:GetActiveWeapon():GetPrimaryAmmoType()), "Trebuchet24", 260, ScrH() - 40, Color(255, 255, 255, 255),0 ,0) --Displays players clip and remaining ammo in the format "x/y"
	end
	
	
	
end

hook.Add("HUDPaint", "TestHud", HUD)			--Allows heads up display to be painted

function HideHud(name)		--This function creates a for loop for all elements in the table, essentially hiding the default heads up display.
	for k,v in pairs({"CHudHealth", "CHudBattery", "CHudAmmo", "CHudSecondaryAmmo"}) do
		if name == v then
			return false
		end
	
	end
end
hook.Add("HUDShouldDraw", "HideDefaultHud", HideHud)
--original https://github.com/phonej/breach
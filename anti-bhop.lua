--Anti Bunny Hopping / Bhop.
hook.Add("OnPlayerHitGround", "Anti-Bhop", function(player)
    --Admin1911.cloudns.cl RXSEND.
    player:SetVelocity(- player:GetVelocity() / 2)
end)
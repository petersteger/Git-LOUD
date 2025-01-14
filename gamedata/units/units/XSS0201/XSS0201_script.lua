local SSubUnit =  import('/lua/defaultunits.lua').SubUnit

local SeraphimWeapons = import('/lua/seraphimweapons.lua')

local SDFUltraChromaticBeamGenerator = SeraphimWeapons.SDFUltraChromaticBeamGenerator02

local SANAnaitTorpedo = SeraphimWeapons.SANAnaitTorpedo

local SDFAjelluAntiTorpedoDefense = SeraphimWeapons.SDFAjelluAntiTorpedoDefense

XSS0201 = Class(SSubUnit) {
    
    Weapons = {
        Turret = Class(SDFUltraChromaticBeamGenerator) {},
        Torpedo = Class(SANAnaitTorpedo) {},
        AntiTorpedo = Class(SDFAjelluAntiTorpedoDefense) {},
    },
    
    OnKilled = function(self, instigator, type, overkillRatio)
	
        local wep1 = self:GetWeaponByLabel('Turret')
		
        local bp1 = wep1:GetBlueprint()
		
        if bp1.Audio.BeamStop then
            wep1:PlaySound(bp1.Audio.BeamStop)
        end
		
        if bp1.Audio.BeamLoop and wep1.Beams[1].Beam then
            wep1.Beams[1].Beam:SetAmbientSound(nil, nil)
        end
		
        for k, v in wep1.Beams do
            v.Beam:Disable()
        end     
--[[        
        local wep2 = self:GetWeaponByLabel('BackTurret')
        local bp2 = wep2:GetBlueprint()
		
        if bp2.Audio.BeamStop then
            wep2:PlaySound(bp2.Audio.BeamStop)
        end
		
        if bp2.Audio.BeamLoop and wep2.Beams[1].Beam then
            wep2.Beams[1].Beam:SetAmbientSound(nil, nil)
        end
		
        for k, v in wep2.Beams do
            v.Beam:Disable()
        end
--]]        
        SSubUnit.OnKilled(self, instigator, type, overkillRatio)
		
    end,
    
	OnStopBeingBuilt = function(self, builder, layer)
	
		SSubUnit.OnStopBeingBuilt(self, builder, layer)
		
		IssueDive({self})
		
	end,
	
}

TypeClass = XSS0201
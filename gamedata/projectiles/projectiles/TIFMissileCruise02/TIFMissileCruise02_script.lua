--
-- Terran Sub-Launched Cruise Missile
--
local TMissileCruiseSubProjectile = import('/lua/terranprojectiles.lua').TMissileCruiseSubProjectile
local ForkThread = ForkThread
local KillThread = KillThread
local WaitSeconds = WaitSeconds
local VDist2 = VDist2

TIFMissileCruise02 = Class(TMissileCruiseSubProjectile) {

	FxAirUnitHitScale = 1.65,
    FxLandHitScale = 1.65,
    FxNoneHitScale = 1.65,
    FxPropHitScale = 1.65,
    FxProjectileHitScale = 1.65,
    FxProjectileUnderWaterHitScale = 1.65,
    FxShieldHitScale = 1.65,
    FxUnderWaterHitScale = 1.65,
    FxUnitHitScale = 1.65,
    FxWaterHitScale = 1.65,
    FxOnKilledScale = 1.65,

    OnCreate = function(self)
        TMissileCruiseSubProjectile.OnCreate(self)
        self:SetCollisionShape('Sphere', 0, 0, 0, 2.0)
        self.MovementTurnLevel = 1
        self:ForkThread( self.MovementThread )
    end,

    MovementThread = function(self)        
        self.WaitTime = 0.1
        self:SetTurnRate(8)
        WaitSeconds(0.3)        
        while not self:BeenDestroyed() do
            self:SetTurnRateByDist()
            WaitSeconds(self.WaitTime)
        end
    end,

    SetTurnRateByDist = function(self)
        local dist = self:GetDistanceToTarget()
        #Get the nuke as close to 90 deg as possible
        if dist > 50 then        
            #Freeze the turn rate as to prevent steep angles at long distance targets
            WaitSeconds(2)
            self:SetTurnRate(20)
        elseif dist > 64 and dist <= 107 then
						# Increase check intervals
						self:SetTurnRate(30)
						WaitSeconds(1.5)
            self:SetTurnRate(30)
        elseif dist > 21 and dist <= 53 then
						# Further increase check intervals
            WaitSeconds(0.3)
            self:SetTurnRate(50)
				elseif dist > 0 and dist <= 21 then
						# Further increase check intervals            
            self:SetTurnRate(100)   
            KillThread(self.MoveThread)         
        end
    end,        

    GetDistanceToTarget = function(self)
        local tpos = self:GetCurrentTargetPosition()
        local mpos = self:GetPosition()
        local dist = VDist2(mpos[1], mpos[3], tpos[1], tpos[3])
        return dist
    end,
    
    OnExitWater = function(self)
        TMissileCruiseSubProjectile.OnExitWater(self)
        self:SetDestroyOnWater(true)
    end,
}

TypeClass = TIFMissileCruise02


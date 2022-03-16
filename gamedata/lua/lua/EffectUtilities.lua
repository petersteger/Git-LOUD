--	/lua/EffectUtilities.lua

-- This file is responsible for a lot of the faction specific visuals

local import = import

local util = import('utilities.lua')

local Random = Random

local Entity = import('/lua/sim/Entity.lua').Entity

local EffectTemplate = import('/lua/EffectTemplates.lua')
local ReclaimBeams = import('/lua/EffectTemplates.lua').ReclaimBeams
local ReclaimObjectAOE = import('/lua/EffectTemplates.lua').ReclaimObjectAOE
local ReclaimObjectEnd = import('/lua/EffectTemplates.lua').ReclaimObjectEnd
local AeonBuildBeams01 = import('/lua/EffectTemplates.lua').AeonBuildBeams01
local AeonBuildBeams02 = import('/lua/EffectTemplates.lua').AeonBuildBeams02
local CybranBuildSparks01 = import('/lua/EffectTemplates.lua').CybranBuildSparks01
local CybranBuildFlash01 = import('/lua/EffectTemplates.lua').CybranBuildFlash01
local CybranBuildUnitBlink01 = import('/lua/EffectTemplates.lua').CybranBuildUnitBlink01
local SeraphimBuildBeams01 = import('/lua/EffectTemplates.lua').SeraphimBuildBeams01

local LOUDGETN = table.getn
local LOUDREMOVE = table.remove
local VDist3Sq = VDist3Sq
local LOUDWARP = Warp

local BeenDestroyed = moho.entity_methods.BeenDestroyed
local CreateLightParticle = CreateLightParticle
local CreateProjectile = moho.entity_methods.CreateProjectile
local GetFractionComplete = moho.entity_methods.GetFractionComplete
local GetPosition = moho.entity_methods.GetPosition
local SetVelocity = moho.projectile_methods.SetVelocity

local LOUDFLOOR = math.floor	
local WaitTicks = coroutine.yield

local LOUDEMITONENTITY = CreateEmitterOnEntity
local LOUDEMITATENTITY = CreateEmitterAtEntity
local LOUDEMITATBONE = CreateEmitterAtBone
local LOUDATTACHEMITTER = CreateAttachedEmitter
local LOUDATTACHBEAMENTITY = AttachBeamEntityToEntity

local ALLBPS = __blueprints

-- credit to Jip for this re-use technique
-- modified to use simple table rather than Vector
local VectorCached = { 0, 0, 0 }


function CreateEffects( obj, army, EffectTable )

    local emitters = {}
    local counter = 1
	
    for _, v in EffectTable do
		emitters[counter] = LOUDEMITATENTITY( obj, army, v )
        counter = counter + 1
    end
    
    return emitters
end

function CreateEffectsWithOffset( obj, army, EffectTable, x, y, z )

    local emitters = {}
    local counter = 1
	
    for _, v in EffectTable  do
		emitters[counter] = LOUDEMITATENTITY( obj, army, v ):OffsetEmitter(x, y, z)
        counter = counter + 1
    end
    
    return emitters
end

function CreateEffectsWithRandomOffset( obj, army, EffectTable, xRange, yRange, zRange )

    local emitters = {}
	local counter = 1
	
    for _, v in EffectTable do
		emitters[counter] = LOUDEMITONENTITY( obj, army, v ):OffsetEmitter(util.GetRandomOffset(xRange, yRange, zRange, 1))
		counter = counter + 1
    end
    
	return emitters
end


function CreateBoneEffects( obj, bone, army, EffectTable )

    local emitters = {}
    local counter = 1
	
    for _, v in EffectTable do
		emitters[counter] = LOUDEMITATBONE( obj, bone, army, v )
        counter = counter + 1
    end
    
    return emitters
end

function CreateBoneEffectsOffset( obj, bone, army, EffectTable, x, y, z )

    local emitters = {}
    local counter = 1

    for _, v in EffectTable do
		emitters[counter] = LOUDEMITATBONE( obj, bone, army, v ):OffsetEmitter(x, y, z)
        counter = counter + 1
    end

    return emitters
end

function CreateBoneTableEffects( obj, BoneTable, army, EffectTable )

    local LOUDINSERT = table.insert
	
    for _, vBone in BoneTable do
    
        for _, vEffect in EffectTable do
            LOUDINSERT(emitters,LOUDEMITATBONE( obj, vBone, army, vEffect ))
        end
    end
end

function CreateBoneTableRangedScaleEffects( obj, BoneTable, EffectTable, army, ScaleMin, ScaleMax )
	
    for _, vBone in BoneTable do
        for _, vEffect in EffectTable do
            LOUDEMITATBONE( obj, vBone, army, vEffect ):ScaleEmitter(ScaleMin + (Random() * (ScaleMax - ScaleMin)))
        end
    end
end


function CreateRandomEffects( obj, army, EffectTable, NumEffects )
	
    local NumTableEntries = LOUDGETN(EffectTable)
    local emitters = {}
	local counter = 1
	
    for i = 1, NumEffects do
    
        emitters[counter] = LOUDEMITONENTITY( obj, army, EffectTable[ 1 + LOUDFLOOR( Random() * (NumTableEntries)) ] )
		counter = counter + 1
    end
	
    return emitters
end

function ScaleEmittersParam( Emitters, param, minRange, maxRange )

    for _, v in Emitters do
        v:SetEmitterParam( param, minRange + (Random()*(maxRange - minRange)) )
    end
end


function CreateBuildCubeThread( unitBeingBuilt, builder, OnBeingBuiltEffectsBag )

	local BeenDestroyed = moho.entity_methods.BeenDestroyed
    local CreateProjectile = moho.entity_methods.CreateProjectile
	local GetFractionComplete = moho.entity_methods.GetFractionComplete

	local LOUDABS = math.abs
    local WaitTicks = coroutine.yield
	
    local bp = ALLBPS[unitBeingBuilt.BlueprintID]
    
	local pos = GetPosition(unitBeingBuilt)
    
    local proj, slice = nil

    local x = bp.Physics.MeshExtentsX or bp.SizeX or (bp.Footprint.SizeX * 1.02) 
    local z = bp.Physics.MeshExtentsZ or bp.SizeZ or (bp.Footprint.SizeZ * 1.02) 
    local y = bp.Physics.MeshExtentsY or bp.SizeY or (0.5 + (x + z) * 0.1) 

    local SlicePeriod = 1.5
    
    -- Create a quick glow effect at location where unit is goig to be built
    proj = unitBeingBuilt:CreateProjectile('/effects/Entities/UEFBuildEffect/UEFBuildEffect02_proj.bp',0,0,0, nil, nil, nil )
    proj:SetScale(x * 1.02, y * 0.2, z * 1.02)
    
    WaitTicks(1)
	
    if unitBeingBuilt.Dead then
        return
    end
	
    local BuildBaseEffect = unitBeingBuilt:CreateProjectile('/effects/Entities/UEFBuildEffect/UEFBuildEffect03_proj.bp', 0, 0, 0, nil, nil, nil )
	
	OnBeingBuiltEffectsBag:Add(BuildBaseEffect)

	unitBeingBuilt.Trash:Add(BuildBaseEffect)

    local vec = VectorCached
    
    vec[1] = pos[1]
	vec[2] = pos[2] + (bp.Physics.MeshExtentsOffsetY or 0) - y
	vec[3] = pos[3]
    
	LOUDWARP( BuildBaseEffect, vec )
    
	BuildBaseEffect:SetScale(x, y, z)
	BuildBaseEffect:SetVelocity(0, 1.4 * y, 0)

    WaitTicks(6)
	
    if unitBeingBuilt.Dead then
        return
    end
    
    if not BuildBaseEffect:BeenDestroyed() then
        BuildBaseEffect:SetVelocity(0)
    end
    
    unitBeingBuilt:ShowBone(0, true)
    unitBeingBuilt:HideLandBones()
    unitBeingBuilt.BeingBuiltShowBoneTriggered = true

    local lComplete = GetFractionComplete(unitBeingBuilt)
	
    WaitTicks(4)
	
    if unitBeingBuilt.Dead then
        return
    end
	
    local cComplete = GetFractionComplete(unitBeingBuilt)

    -- Create glow slice cuts and resize base cube
    while not unitBeingBuilt.Dead and cComplete < 1.0 do
	
        if lComplete < cComplete and not BeenDestroyed(BuildBaseEffect) then
        
	        proj = CreateProjectile( BuildBaseEffect, '/effects/Entities/UEFBuildEffect/UEFBuildEffect02_proj.bp',0,y * (1-cComplete),0, nil, nil, nil )
			
			TrashAdd( OnBeingBuiltEffectsBag, proj)
			
            slice = LOUDABS(lComplete - cComplete)
            
            proj:SetScale(x, y * slice, z)
            BuildBaseEffect:SetScale(x, y * (1-cComplete), z)
            
        end
		
        WaitTicks(SlicePeriod * 10)
		
        if unitBeingBuilt.Dead then
            break
        end
		
        lComplete = cComplete
        cComplete = GetFractionComplete(unitBeingBuilt)
    end
	
	if not BeenDestroyed(BuildBaseEffect) then
		BuildBaseEffect:Destroy()
	end
    
end

function CreateUEFUnitBeingBuiltEffects( builder, unitBeingBuilt, BuildEffectsBag )

    BuildEffectsBag:Add( LOUDATTACHEMITTER( builder, ALLBPS[builder.BlueprintID].Display.BuildAttachBone, builder.Sync.army, '/effects/emitters/uef_mobile_unit_build_01_emit.bp' ) )
end

function CreateUEFBuildSliceBeams( builder, unitBeingBuilt, BuildEffectBones, BuildEffectsBag )

    local army = builder.Sync.army
    
    local BeenDestroyed = moho.entity_methods.BeenDestroyed
    
    local WaitTicks = coroutine.yield
    
    local buildbp = ALLBPS[unitBeingBuilt.BlueprintID]
    
	local pos = GetPosition(unitBeingBuilt)

	local x = pos[1]
	local y = pos[2] + (buildbp.Physics.MeshExtentsOffsetY or 0)
	local z = pos[3]

    -- Create a projectile for the end of build effect and WARP it to the unit
    local BeamEndEntity = unitBeingBuilt:CreateProjectile('/effects/entities/UEFBuild/UEFBuild01_proj.bp',0,0,0,nil,nil,nil)
	
    BuildEffectsBag:Add( BeamEndEntity )

    -- Create build beams
    if BuildEffectBones != nil then
        
        for i, BuildBone in BuildEffectBones do
        
            BuildEffectsBag:Add( LOUDATTACHBEAMENTITY( builder, BuildBone, BeamEndEntity, -1, army, '/effects/emitters/build_beam_01_emit.bp' ) )
            BuildEffectsBag:Add( LOUDATTACHEMITTER( builder, BuildBone, army, '/effects/emitters/flashing_blue_glow_01_emit.bp' ) )
            
        end
        
    end

    -- Determine beam positioning on build cube, this should match sizes of CreateBuildCubeThread
    local ox = buildbp.SizeX or buildbp.Physics.MeshExtentsX or (buildbp.Footprint.SizeX * 1.02) 
    local oz = buildbp.SizeZ or buildbp.Physics.MeshExtentsZ or (buildbp.Footprint.SizeZ * 1.02) 
    local oy = buildbp.SizeY or buildbp.Physics.MeshExtentsY or ((0.5 + (ox + oz) * 0.1))

    ox = ox * 0.5
    oz = oz * 0.5

    -- Determine the the 2 closest edges of the build cube and use those for the location of laser
    local VectorExtentsList = { {x + ox, y + oy, z + oz}, {x + ox, y + oy, z - oz}, {x - ox, y + oy, z + oz}, {x - ox, y + oy, z - oz} }
    
    local builderPos = GetPosition(builder)
    
    -- originally housed in utils
    local function GetClosestVector()

        local cDist, retVec
    
        local dist = 99999999
    
        for kTo, vTo in VectorExtentsList do
    
            cDist = VDist3Sq( builderPos, vTo )
        
            if cDist < dist then
        
                dist = cDist
                retVec = vTo
            
            end 
        end
    
        return retVec
    end

    -- get the closest vector to the builder
    local endVec1 = GetClosestVector()

    -- remove the closest vector
    for k,v in VectorExtentsList do
    
        if(v == endVec1) then
            LOUDREMOVE(VectorExtentsList, k)
            break
        end
        
    end

    -- get the 2nd closest vector
    local endVec2 = GetClosestVector()
    
    VectorExtentsList = nil
    
    local cx1 = endVec1[1]
	local cy1 = endVec1[2]
	local cz1 = endVec1[3]
    local cx2 = endVec2[1]
	local cy2 = endVec2[2]
	local cz2 = endVec2[3]

    #-- Determine a the velocity of our projectile, used for the scanning effect
    local velX = 2 * ( cx2 - cx1 )
    local velY = 2 * ( cy2 - cy1 )
    local velZ = 2 * ( cz2 - cz1 )
    
    local vec = VectorCached

    if GetFractionComplete(unitBeingBuilt) == 0 then

        vec[1] = (cx1 + cx2) * 0.5
        vec[2] = (cy1 + cy2) * 0.5
        vec[3] = (cz1 + cz2) * 0.5
    
        LOUDWARP( BeamEndEntity, vec ) 
        
        WaitTicks(8)   
    end 

    local flipDirection = true

    #-- WARP our projectile back to the initial corner and lower based on build completeness
    while not BeenDestroyed(builder) and not BeenDestroyed(unitBeingBuilt) do
    
        if flipDirection then
        
            vec[1] = cx1
            vec[2] = cy1 - (oy * GetFractionComplete(unitBeingBuilt))
            vec[3] = cz1
        
            LOUDWARP( BeamEndEntity, vec )
            BeamEndEntity:SetVelocity( velX, velY, velZ )
            
            flipDirection = false
            
        else
            
            vec[1] = cx2
            vec[2] = cy2 - (oy * GetFractionComplete(unitBeingBuilt))
            vec[3] = cz2
        
            LOUDWARP( BeamEndEntity, vec )
            BeamEndEntity:SetVelocity( -velX, -velY, -velZ )
            
            flipDirection = true
        end
		
        WaitTicks(8)
    end
end

function CreateUEFCommanderBuildSliceBeams( builder, unitBeingBuilt, BuildEffectBones, BuildEffectsBag )

    local army = builder.Sync.army
    
    local BeamBuildEmtBp = '/effects/emitters/build_beam_01_emit.bp'
    
    local BeenDestroyed = moho.entity_methods.BeenDestroyed
    local LOUDWARP = Warp
    local WaitTicks = coroutine.yield
    
    local buildbp = ALLBPS[unitBeingBuilt.BlueprintID]

    local vec = VectorCached
	local pos = GetPosition(unitBeingBuilt)
    
	local x = pos[1]
	local y = pos[2]
	local z = pos[3]
    
    y = y + (buildbp.Physics.MeshExtentsOffsetY or 0)    

    -- Create a projectile for the end of build effect and WARP it to the unit
    local BeamEndEntity = unitBeingBuilt:CreateProjectile('/effects/entities/UEFBuild/UEFBuild01_proj.bp',0,0,0,nil,nil,nil)
    local BeamEndEntity2 = unitBeingBuilt:CreateProjectile('/effects/entities/UEFBuild/UEFBuild01_proj.bp',0,0,0,nil,nil,nil)
    
    BuildEffectsBag:Add( BeamEndEntity )
    BuildEffectsBag:Add( BeamEndEntity2 )
    
    -- Create build beams
    if BuildEffectBones != nil then

        for i, BuildBone in BuildEffectBones do
        
            BuildEffectsBag:Add( LOUDATTACHBEAMENTITY( builder, BuildBone, BeamEndEntity, -1, army, '/effects/emitters/build_beam_01_emit.bp' ) )
            BuildEffectsBag:Add( LOUDATTACHBEAMENTITY( builder, BuildBone, BeamEndEntity2, -1, army, '/effects/emitters/build_beam_01_emit.bp' ) )
            BuildEffectsBag:Add( LOUDATTACHEMITTER( builder, BuildBone, army, '/effects/emitters/flashing_blue_glow_01_emit.bp' ) )
            
        end
        
    end

    -- Determine beam positioning on build cube, this should match sizes of CreateBuildCubeThread
    local ox = buildbp.SizeX or buildbp.Physics.MeshExtentsX or (buildbp.Footprint.SizeX * 1.02)
    local oz = buildbp.SizeZ or buildbp.Physics.MeshExtentsZ or (buildbp.Footprint.SizeZ * 1.02)
    local oy = buildbp.SizeY or buildbp.Physics.MeshExtentsY or ((0.5 + (ox + oz) * 0.1))

    ox = ox * 0.5
    oz = oz * 0.5

    -- Determine the the 2 closest edges of the build cube and use those for the location of our laser
    local VectorExtentsList = { {x + ox, y + oy, z + oz}, {x + ox, y + oy, z - oz}, {x - ox, y + oy, z + oz}, {x - ox, y + oy, z - oz} }
    
    local builderPos = GetPosition(builder)
    
    -- originally housed in utils
    local function GetClosestVector()

        local cDist, retVec
    
        local dist = 99999999
    
        for kTo, vTo in VectorExtentsList do
    
            cDist = VDist3Sq( builderPos, vTo )
        
            if cDist < dist then
        
                dist = cDist
                retVec = vTo
            
            end 
        end
    
        return retVec
    end
    
    local endVec1 = GetClosestVector()

    for k,v in VectorExtentsList do
    
        if(v == endVec1) then
            LOUDREMOVE(VectorExtentsList, k)
            break
        end
        
    end

    local endVec2 = GetClosestVector()
    
    local cx1 = endVec1[1]
	local cy1 = endVec1[2]
	local cz1 = endVec1[3]
    local cx2 = endVec2[1]
	local cy2 = endVec2[2]
	local cz2 = endVec2[3]

    -- Determine a the velocity of our projectile, used for the scaning effect
    local velX = 2 * ( cx2 - cx1 )
    local velY = 2 * ( cy2 - cy1 )
    local velZ = 2 * ( cz2 - cz1 )

    if GetFractionComplete(unitBeingBuilt) == 0 then
    
        vec[1] = cx1
        vec[2] = cy1 - oy
        vec[3] = cz1
        
        LOUDWARP( BeamEndEntity, vec) 
        
        vec[1] = cx2
        vec[2] = cy2 - oy
        vec[3] = cz2
        
        LOUDWARP( BeamEndEntity2, vec )
        
        WaitTicks(8)   
    end    

    local flipDirection = true

    -- WARP our projectile back to the initial corner and lower based on build completeness
    while not BeenDestroyed(builder) and not BeenDestroyed(unitBeingBuilt) do
    
        local frac = GetFractionComplete(unitBeingBuilt)
        
        if flipDirection then
        
            vec[1] = cx1
            vec[2] = cy1 - (oy * frac)
            vec[3] = cz1
        
            LOUDWARP( BeamEndEntity, vec )
            BeamEndEntity:SetVelocity( velX, velY, velZ )
            
            vec[1] = cx2
            vec[2] = cy2 - (oy * frac)
            vec[3] = cz2
            
            LOUDWARP( BeamEndEntity2, vec )
            BeamEndEntity2:SetVelocity( -velX, -velY, -velZ )
            
            flipDirection = false
            
        else
            vec[1] = cx2
            vec[2] = cy2 - (oy * frac)
            vec[3] = cz2
            
            LOUDWARP( BeamEndEntity2, vec )
            BeamEndEntity2:SetVelocity( -velX, -velY, -velZ )
            
            vec[1] = cx1
            vec[2] = cy1 - (oy * frac)
            vec[3] = cz1
        
            LOUDWARP( BeamEndEntity, vec )
            BeamEndEntity:SetVelocity( velX, velY, velZ )

            flipDirection = true
        end
		
        WaitTicks(8)
    end
end


function CreateDefaultBuildBeams( builder, unitBeingBuilt, BuildEffectBones, BuildEffectsBag )

    local BeenDestroyed = BeenDestroyed
    local LOUDWARP = LOUDWARP
    local WaitTicks = coroutine.yield
    
	local pos = GetPosition(unitBeingBuilt)

    local army = builder.Sync.army
    
    local BeamEndEntity = Entity()

    TrashAdd( BuildEffectsBag, BeamEndEntity )
    
    LOUDWARP( BeamEndEntity, pos )

    -- Create build beams
    if BuildEffectBones != nil then
    
        local beamEffect = nil
		
        for i, BuildBone in BuildEffectBones do
        
            local beamEffect = LOUDATTACHBEAMENTITY(builder, BuildBone, BeamEndEntity, -1, army, '/effects/emitters/build_beam_01_emit.bp' )
            
            TrashAdd( BuildEffectsBag, beamEffect )
        end
        
    end    

    LOUDEMITONENTITY( BeamEndEntity, builder.Sync.army, '/effects/emitters/sparks_08_emit.bp')
	
    local waitTime = (1 + Random()) * 10    -- result 10 to 20
    
    local x,y,z

    local vec = VectorCached    -- reusable table
    
    while not BeenDestroyed(builder) and not BeenDestroyed(unitBeingBuilt) do
    
        x, y, z = builder.GetRandomOffset(unitBeingBuilt, 1 )
        
        vec[1] = pos[1]+x
        vec[2] = pos[2]+y
        vec[3] = pos[3]+z
        
        LOUDWARP( BeamEndEntity, vec )
        
        WaitTicks(waitTime)
    end
    
end

-- effects used when building structures
function CreateAeonBuildBaseThread( unitBeingBuilt, builder, EffectsBag )

    local BeenDestroyed = moho.entity_methods.BeenDestroyed
    local WaitTicks = coroutine.yield

	local army = builder.Sync.army
    local bp = ALLBPS[unitBeingBuilt.BlueprintID]

    WaitTicks(1)
    
    local vec = VectorCached
	local pos = GetPosition(unitBeingBuilt)

    -- Create a pool mercury that slowly draws into the build unit
    local BuildBaseEffect = CreateProjectile( unitBeingBuilt, '/effects/entities/AeonBuildEffect/AeonBuildEffect01_proj.bp', nil, 0, 0, nil, nil, nil )

    local sx = bp.Physics.MeshExtentsX or bp.SizeX or bp.Footprint.SizeX * 0.5
    local sz = bp.Physics.MeshExtentsZ or bp.SizeZ or bp.Footprint.SizeZ * 0.5
    local sy = bp.Physics.MeshExtentsY or bp.SizeY or sx + sz
	
	-- size the pool so that its slightly larger on the Y
    BuildBaseEffect:SetScale(sx, sy * 1.5, sz)
	
	vec[1] = pos[1]
	vec[2] = pos[2]
	vec[3] = pos[3]
	
    LOUDWARP( BuildBaseEffect, vec )
	
    BuildBaseEffect:SetOrientation(unitBeingBuilt:GetOrientation(), true)    
	
    TrashAdd( unitBeingBuilt.Trash, BuildBaseEffect)
	
    TrashAdd( EffectsBag, BuildBaseEffect)

    LOUDEMITONENTITY(BuildBaseEffect, army,'/effects/emitters/aeon_being_built_ambient_01_emit.bp'):SetEmitterCurveParam('X_POSITION_CURVE', 0, sx * 1.5):SetEmitterCurveParam('Z_POSITION_CURVE', 0, sz * 1.5)
    
    LOUDEMITONENTITY(BuildBaseEffect, army,'/effects/emitters/aeon_being_built_ambient_03_emit.bp'):ScaleEmitter( (sx + sz) * 0.3 )

    local slider = CreateSlider( unitBeingBuilt, 0 )
	
    slider:SetWorldUnits(true)
    slider:SetGoal(0, -sy, 0)
    slider:SetSpeed(-2)
    WaitFor(slider)
	
    slider:SetSpeed(0.25)

    -- while we are less than 95% complete, raise the model in small steps
    while not unitBeingBuilt.Dead and GetFractionComplete(unitBeingBuilt) < 0.95 do
    
		slider:SetGoal( 0, -sy + ( sy * GetFractionComplete(unitBeingBuilt)), 0 )
        WaitTicks(5)
        
    end
	
	slider:SetGoal( 0, 0, 0 )

    if not BuildBaseEffect:BeenDestroyed() then
	    BuildBaseEffect:SetScaleVelocity(-0.12, -0.12, -0.12)
	end    
	
    slider:SetSpeed(0.3)
	
	repeat
		WaitTicks(3)
	until unitBeingBuilt.Dead or GetFractionComplete(unitBeingBuilt) == 1
	
    slider:Destroy()
    BuildBaseEffect:Destroy()
end


function CreateCybranBuildBeams( builder, unitBeingBuilt, BuildEffectBones, BuildEffectsBag )

    local BeenDestroyed = moho.entity_methods.BeenDestroyed
    local LOUDWARP = LOUDWARP
    local WaitTicks = coroutine.yield

    if BuildEffectBones then
	
		WaitTicks(2)    -- this delay seems to be necessary so that the position of the unit is correct

        local vec = VectorCached    -- reusable table
        
		local pos = GetPosition(unitBeingBuilt)

		local army = builder.Sync.army
	
		local BeamEndEntities = {}
		local counter = 1
    
        for i, BuildBone in BuildEffectBones do
		
            local beamEnd = Entity()
			
            TrashAdd( builder.Trash, beamEnd )
			
            BeamEndEntities[counter] = beamEnd
			counter = counter + 1
			
            TrashAdd( BuildEffectsBag, beamEnd )
			
            LOUDWARP( beamEnd, pos )
			
            LOUDEMITONENTITY( beamEnd, army, CybranBuildSparks01 )
            LOUDEMITONENTITY( beamEnd, army, CybranBuildFlash01 )
			
            TrashAdd( BuildEffectsBag, LOUDATTACHBEAMENTITY( builder, BuildBone, beamEnd, -1, army, '/effects/emitters/build_beam_02_emit.bp' ) )
			
        end
		
        local x,y,z
        
		-- move the beams around every 16 ticks
		while not BeenDestroyed(builder) and not BeenDestroyed(unitBeingBuilt) do

			for k, v in BeamEndEntities do
		
				x, y, z = builder.GetRandomOffset(unitBeingBuilt, 1 )
                
                vec[1] = pos[1] + x
                vec[2] = pos[2] + y
                vec[3] = pos[3] + z
			
				if v and not BeenDestroyed(v) then
                
					LOUDWARP( v, vec )
                    
				end
			
			end
			
			WaitTicks(16)
		end
		
    end
	
end

function SpawnBuildBots( builder, unitBeingBuilt, numBots,  BuildEffectsBag )

    local army = builder.Sync.army
	
	local pos = GetPosition(builder)
    
	local x = pos[1]
	local y = pos[2]
	local z = pos[3]

	pos = builder:GetOrientation()
    
	local qx = pos[1]
	local qy = pos[2]
	local qz = pos[3]
	local qw = pos[4]

    local xVec = 0
    local yVec = ALLBPS[builder.BlueprintID].SizeY * 0.5
    local zVec = 0
	
    local BuilderUnits = {}
	local counter = 1
	
    local tunit = nil
    
    local LOUDCOS = math.cos
    local LOUDSIN = math.sin
    
    local LOUDPI = math.pi
    
    local angle = (2*LOUDPI) / numBots

    for i = 0, (numBots - 1) do
	
        xVec = LOUDSIN( 180 + (i*angle)) * 0.5
        zVec = LOUDCOS( 180 + (i*angle)) * 0.5
		
        tunit = CreateUnit('ura0001', army, x + xVec, y + yVec, z + zVec, qx, qy, qz, qw, 'Air' )

        -- Make build bots unkillable
        tunit:SetCanTakeDamage(false)
        tunit:SetCanBeKilled(false)
        
        BuilderUnits[counter] = tunit
		counter = counter + 1
		
        TrashAdd( BuildEffectsBag, tunit )
		
    end
	
    IssueGuard( BuilderUnits, unitBeingBuilt )
	
    return BuilderUnits
	
end

function CreateCybranEngineerBuildEffects( builder, BuildBones, BuildBots, BuildEffectsBag )

    -- Create constant build effect for each build bone defined
    if BuildBones then
	
        local army = builder.Sync.army
        local WaitTicks = coroutine.yield
		
        for _, vBone in BuildBones do
        
            for _, vEffect in CybranBuildUnitBlink01 do
                TrashAdd( BuildEffectsBag, LOUDATTACHEMITTER(builder,vBone,army,vEffect))
            end
            
            WaitTicks( (0.5 + (Random() * 0.6)) * 10 )
        end

        if BeenDestroyed(builder) then
            return
        end

        local i = 1
		
        for _, vBot in BuildBots do
        
            if not vBot or BeenDestroyed(vBot) then
                continue
            end
            
            TrashAdd( BuildEffectsBag, LOUDATTACHBEAMENTITY(builder, BuildBones[i], vBot, -1, army, '/effects/emitters/build_beam_03_emit.bp'))        
            i = i + 1
        end
    end
end

function CreateCybranFactoryBuildEffects( builder, unitBeingBuilt, BuildBones, BuildEffectsBag )
	
    local BuildEffects = { '/effects/emitters/sparks_03_emit.bp', '/effects/emitters/flashes_01_emit.bp', }
    local UnitBuildEffects = { '/effects/emitters/build_cybran_spark_flash_04_emit.bp', '/effects/emitters/build_sparks_blue_02_emit.bp', }
	
    local army = builder.Sync.army
    
    for _,vB in BuildBones.BuildEffectBones do
    
        for _, vE in BuildEffects do
            TrashAdd( BuildEffectsBag, LOUDATTACHEMITTER(builder,vB,army,vE) )
        end 
        
    end
    
    TrashAdd( BuildEffectsBag, LOUDATTACHEMITTER( builder, BuildBones.BuildAttachBone, army, '/effects/emitters/cybran_factory_build_01_emit.bp' ) )

    -- Add sparks to the collision box of the unit being built
    local sx, sy, sz = 0
    
    local GetFractionComplete = GetFractionComplete
	local WaitTicks = coroutine.yield

    while not unitBeingBuilt.Dead and GetFractionComplete(unitBeingBuilt) < 1 do
    
        sx, sy, sz = unitBeingBuilt:GetRandomOffset(1)
		
        for _, vE in UnitBuildEffects do
            LOUDEMITONENTITY(unitBeingBuilt,army,vE):OffsetEmitter(sx,sy,sz) 
        end
        
        WaitTicks( (0.6 + (Random() * 0.4)) * 10 )
    end 
end


function CreateAeonConstructionUnitBuildingEffects( builder, unitBeingBuilt, BuildEffectsBag )

    TrashAdd( BuildEffectsBag, LOUDEMITONENTITY(builder, builder.Sync.army,'/effects/emitters/aeon_build_01_emit.bp') )

    local beamEnd = Entity()
    
    TrashAdd( BuildEffectsBag, beamEnd )
    
    LOUDWARP( beamEnd, GetPosition(unitBeingBuilt) )
    
    local beamEffect

    for _, v in AeonBuildBeams01 do
    
		beamEffect = LOUDATTACHBEAMENTITY(builder, 0, beamEnd, -1, builder.Sync.army, v )
        
		beamEffect:SetEmitterParam( 'POSITION_Z', 0.45 )
        
		TrashAdd( BuildEffectsBag, beamEffect )
	end
end

function CreateAeonCommanderBuildingEffects( builder, unitBeingBuilt, BuildEffectBones, BuildEffectsBag )

    local beamEnd = Entity()
    
    TrashAdd( BuildEffectsBag, beamEnd )
    
    LOUDWARP( beamEnd, GetPosition(unitBeingBuilt) )
    
    local beamEffect

    for _, vBone in BuildEffectBones do
    
		TrashAdd( BuildEffectsBag, LOUDATTACHEMITTER( builder, vBone, builder.Sync.army, '/effects/emitters/aeon_build_02_emit.bp' ) )

    	for _, v in AeonBuildBeams01 do
        
			beamEffect = LOUDATTACHBEAMENTITY(builder, vBone, beamEnd, -1, builder.Sync.army, v )
            
			TrashAdd( BuildEffectsBag, beamEffect )
		end
	end
end

-- effects used by Factories building units
function CreateAeonFactoryBuildingEffects( builder, unitBeingBuilt, BuildEffectBones, BuildBone, EffectsBag )

    local bp = ALLBPS[unitBeingBuilt.BlueprintID]
    
    local army = builder.Sync.army
    
	local pos = table.copy(builder.CachePosition)
	
	local x = pos[1]
	local y = pos[2]
	local z = pos[3]

    local sx = bp.Physics.MeshExtentsX or bp.SizeX or bp.Footprint.SizeX
    local sz = bp.Physics.MeshExtentsZ or bp.SizeZ or bp.Footprint.SizeZ
    local sy = bp.Physics.MeshExtentsY or bp.SizeY or sx + sz

    for _, vBone in BuildEffectBones do
		
		if EffectsBag then
        
            local beamEffect
		
			TrashAdd( EffectsBag, LOUDATTACHEMITTER( builder, vBone, army, '/effects/emitters/aeon_build_03_emit.bp' ) )
		
			for _, vBeam in AeonBuildBeams02 do
			
				beamEffect = LOUDATTACHBEAMENTITY(builder, vBone, builder, BuildBone, army, vBeam )
				
				TrashAdd( EffectsBag, beamEffect )
				
			end
		end
	end

    repeat

	    WaitTicks(5)
		
	until unitBeingBuilt.Dead or GetFractionComplete(unitBeingBuilt) == 1

end


function CreateSeraphimUnitEngineerBuildingEffects( builder, unitBeingBuilt, BuildEffectBones, BuildEffectsBag )

	local army = builder.Sync.army

    for _, vBone in BuildEffectBones do
    
		TrashAdd( BuildEffectsBag, LOUDATTACHEMITTER( builder, vBone, army, '/effects/emitters/seraphim_build_01_emit.bp' ) )
        
        local beamEffect

    	for _, v in SeraphimBuildBeams01 do
        
			beamEffect = LOUDATTACHBEAMENTITY(builder, vBone, unitBeingBuilt, -1, army, v )
            
			TrashAdd( BuildEffectsBag, beamEffect )
		end
	end
end

function CreateSeraphimFactoryBuildingEffects( builder, unitBeingBuilt, BuildEffectBones, BuildBone, EffectsBag )

    local BeenDestroyed = moho.entity_methods.BeenDestroyed
    local WaitTicks = coroutine.yield

    local bp = ALLBPS[unitBeingBuilt.BlueprintID]
    local army = builder.Sync.army
    
	local pos = builder:GetPosition(BuildBone)
    
	local x = pos[1]
	local y = pos[2]
	local z = pos[3]

    local sx = bp.Physics.MeshExtentsX or bp.SizeX or bp.Footprint.SizeX
    local sz = bp.Physics.MeshExtentsZ or bp.SizeZ or bp.Footprint.SizeZ
    local sy = bp.Physics.MeshExtentsY or bp.SizeY or sx + sz

    -- Create a seraphim whispy cloud effect that swirls around the build unit
    local BuildBaseEffect = CreateProjectile( unitBeingBuilt, '/effects/entities/SeraphimBuildEffect01/SeraphimBuildEffect01_proj.bp', nil, 0, 0, nil, nil, nil )
	
    BuildBaseEffect:SetScale(sx, 1, sz)
    BuildBaseEffect:SetOrientation( unitBeingBuilt:GetOrientation(), true)
    
    LOUDWARP( BuildBaseEffect, pos )
    
    TrashAdd( unitBeingBuilt.Trash, BuildBaseEffect )
    
    TrashAdd( EffectsBag, BuildBaseEffect )

    for _, vBone in BuildEffectBones do
    
		TrashAdd( EffectsBag, LOUDATTACHEMITTER( builder, vBone, army, '/effects/emitters/seraphim_build_01_emit.bp' ) )
        
		for _, vBeam in SeraphimBuildBeams01 do
        
			TrashAdd( EffectsBag, LOUDATTACHBEAMENTITY(builder, vBone, unitBeingBuilt, -1, army, vBeam ))
			TrashAdd( EffectsBag, LOUDATTACHEMITTER( unitBeingBuilt, -1, army, '/effects/emitters/seraphim_being_built_ambient_02_emit.bp'))
			TrashAdd( EffectsBag, LOUDATTACHEMITTER( unitBeingBuilt, -1, army, '/effects/emitters/seraphim_being_built_ambient_03_emit.bp'))			
			TrashAdd( EffectsBag, LOUDATTACHEMITTER( unitBeingBuilt, -1, army, '/effects/emitters/seraphim_being_built_ambient_04_emit.bp'))						
			TrashAdd( EffectsBag, LOUDATTACHEMITTER( unitBeingBuilt, -1, army, '/effects/emitters/seraphim_being_built_ambient_05_emit.bp'))				
            
		end
	end

    local slider = CreateSlider( unitBeingBuilt, 0 )
	
    TrashAdd( unitBeingBuilt.Trash, slider )
	
    TrashAdd( EffectsBag, slider )
	
    slider:SetWorldUnits(true)
    slider:SetGoal(0, sy, 0)
    slider:SetSpeed(-1)
	
    WaitFor(slider)
	
    if not slider:BeenDestroyed() then 
        slider:SetGoal(0,0,0)
        slider:SetSpeed(.05)
    end

    -- Wait till we are 80% done building, then snap our slider to
    while not unitBeingBuilt.Dead and GetFractionComplete(unitBeingBuilt) < 0.8 do
        WaitTicks(10)
    end
    
    if not unitBeingBuilt.Dead then
	
        if not BuildBaseEffect:BeenDestroyed() then
	        BuildBaseEffect:SetScaleVelocity(-0.6, -0.6, -0.6)
	    end
		
    	if not slider:BeenDestroyed() then
            slider:SetSpeed(2)
        end            
		
	    WaitTicks(5)
	end
	
	if not slider:BeenDestroyed() then
        slider:Destroy()
    end
    
    if not BuildBaseEffect:BeenDestroyed() then
        BuildBaseEffect:Destroy()
    end
end

function CreateSeraphimBuildBaseThread( unitBeingBuilt, builder, EffectsBag )

    local WaitTicks = coroutine.yield
    
    local army = builder.Sync.army
    local bp = ALLBPS[unitBeingBuilt.BlueprintID]
    
    local vec = VectorCached
	local pos = unitBeingBuilt:GetPosition()
    
	local x = pos[1]
	local y = pos[2]
	local z = pos[3]

    local sx = bp.Physics.MeshExtentsX or bp.SizeX or bp.Footprint.SizeX * 0.5
    local sz = bp.Physics.MeshExtentsZ or bp.SizeZ or bp.Footprint.SizeZ * 0.5
    local sy = bp.Physics.MeshExtentsY or bp.SizeY or sx + sz

    WaitTicks(1)

    local BuildBaseEffect = CreateProjectile( unitBeingBuilt, '/effects/entities/SeraphimBuildEffect01/SeraphimBuildEffect01_proj.bp', nil, 0, 0, nil, nil, nil )
	
    BuildBaseEffect:SetScale(sx, 1, sz)
    BuildBaseEffect:SetOrientation( unitBeingBuilt:GetOrientation(), true)    
    
    LOUDWARP( BuildBaseEffect, pos )
    
    TrashAdd( unitBeingBuilt.Trash, BuildBaseEffect )
    
    TrashAdd( EffectsBag, BuildBaseEffect)

    local BuildEffectBaseEmitters = {'/effects/emitters/seraphim_being_built_ambient_01_emit.bp'}

    local BuildEffectsEmitters = {
        '/effects/emitters/seraphim_being_built_ambient_02_emit.bp',
        '/effects/emitters/seraphim_being_built_ambient_03_emit.bp',
        '/effects/emitters/seraphim_being_built_ambient_04_emit.bp', 
        '/effects/emitters/seraphim_being_built_ambient_05_emit.bp',       
    }
    
    local AdjustedEmitters = {}
    local count = 0
    
    local effect = nil
	
    for _, vEffect in BuildEffectsEmitters do
    
        effect = LOUDATTACHEMITTER( unitBeingBuilt, -1, army, vEffect)
        
        count = count + 1
        AdjustedEmitters[count] = effect
        
        TrashAdd( EffectsBag, effect )
    end

    for _, vEffect in BuildEffectBaseEmitters do
    
        effect = LOUDATTACHEMITTER( BuildBaseEffect, -1, army, vEffect)
        
        count = count + 1
        AdjustedEmitters[count] = effect
        
        TrashAdd( EffectsBag, effect )
    end

    -- Poll the unit being built every second to adjust the effects to match
    local fractionComplete = GetFractionComplete(unitBeingBuilt)
    local unitScaleMetric = unitBeingBuilt:GetFootPrintSize() * 0.65
	
    while not unitBeingBuilt.Dead and fractionComplete < 1.0 do
    
        WaitTicks(10)
        fractionComplete = GetFractionComplete(unitBeingBuilt)
		
        for _, vEffect in AdjustedEmitters do
            vEffect:ScaleEmitter( 1 + (unitScaleMetric * fractionComplete))	    
        end        
    end
	
    local unitsArmy = unitBeingBuilt.Sync.army
	local footprintsize = unitBeingBuilt:GetFootPrintSize()
    local focusArmy = GetFocusArmy()

    if focusArmy == -1 or IsAlly(unitsArmy,focusArmy) then
    
        CreateLightParticle( unitBeingBuilt, -1, unitsArmy, footprintsize * 7, 8, 'glow_02', 'ramp_blue_22' ) 
		
    elseif IsEnemy(unitsArmy,focusArmy) then
    
        local blip = unitBeingBuilt:GetBlip(focusArmy)
		
        if blip ~= nil and blip:IsSeenNow(focusArmy) then
            CreateLightParticle( unitBeingBuilt, -1, unitsArmy, footprintsize * 7, 8, 'glow_02', 'ramp_blue_22' ) 
        end
    end

    unitBeingBuilt:CreateTarmac(true, true, true, false, false)
    
    WaitTicks(5)
    
    BuildBaseEffect:Destroy()
end

function CreateSeraphimExperimentalBuildBaseThread( unitBeingBuilt, builder, EffectsBag )

    local bp = ALLBPS[unitBeingBuilt.BlueprintID]
    
	local pos = GetPosition(unitBeingBuilt)
    
	local x = pos[1]
	local y = pos[2]
	local z = pos[3]

    local sx = bp.Physics.MeshExtentsX or bp.Footprint.SizeX * 0.5
    local sz = bp.Physics.MeshExtentsZ or bp.Footprint.SizeZ * 0.5
    local sy = bp.Physics.MeshExtentsY or sx + sz

    WaitTicks(1)

    local BuildBaseEffect = CreateProjectile( unitBeingBuilt, '/effects/entities/SeraphimBuildEffect01/SeraphimBuildEffect01_proj.bp', nil, 0, 0, nil, nil, nil )
	
    BuildBaseEffect:SetScale(sx, 1, sz)
    BuildBaseEffect:SetOrientation( unitBeingBuilt:GetOrientation(), true)
    
    LOUDWARP( BuildBaseEffect, pos )
    
    TrashAdd( unitBeingBuilt.Trash, BuildBaseEffect )
    
    TrashAdd( EffectsBag, BuildBaseEffect )

    local BuildEffectBaseEmitters = {'/effects/emitters/seraphim_being_built_ambient_01_emit.bp'}

    local BuildEffectsEmitters = {
        '/effects/emitters/seraphim_being_built_ambient_02_emit.bp',
        '/effects/emitters/seraphim_being_built_ambient_03_emit.bp',
        '/effects/emitters/seraphim_being_built_ambient_04_emit.bp', 
        '/effects/emitters/seraphim_being_built_ambient_05_emit.bp',       
    }
    
    local AdjustedEmitters = {}
	local counter = 1
	
    local effect
	
    for _, vEffect in BuildEffectsEmitters do
    
        effect = LOUDATTACHEMITTER( unitBeingBuilt, -1, builder.Sync.army, vEffect ):ScaleEmitter(2)
        
        AdjustedEmitters[counter] = effect
		counter = counter + 1
        
        TrashAdd( EffectsBag, effect )
    end


    -- Poll the unit being built every second to adjust the effects to match
    local fractionComplete = GetFractionComplete(unitBeingBuilt)
    local unitScaleMetric = unitBeingBuilt:GetFootPrintSize() * 0.65
	
    while not unitBeingBuilt.Dead and fractionComplete < 1.0 do
	
        WaitTicks(10)
        fractionComplete = GetFractionComplete(unitBeingBuilt)
		
        for _, vEffect in AdjustedEmitters do
            vEffect:ScaleEmitter( 2 + (unitScaleMetric * fractionComplete) )	    
        end        
    end

    local unitsArmy = unitBeingBuilt.Sync.army
    
	local footprintsize = unitBeingBuilt:GetFootPrintSize()
    local focusArmy = GetFocusArmy()
	
    if focusArmy == -1 or IsAlly(unitsArmy,focusArmy) then
    
        CreateLightParticle( unitBeingBuilt, -1, unitsArmy, footprintsize  * 4, 6, 'glow_02', 'ramp_blue_22' ) 
		
    elseif IsEnemy(unitsArmy,focusArmy) then
    
        local blip = unitBeingBuilt:GetBlip(focusArmy)
        
        if blip ~= nil and blip:IsSeenNow(focusArmy) then
            CreateLightParticle( unitBeingBuilt, -1, unitsArmy, footprintsize * 4, 6, 'glow_02', 'ramp_blue_22' ) 
        end
    end

    WaitTicks(5)
    
    BuildBaseEffect:Destroy()
end

-- I modded this to reduce the number of entities created by the adjacency beams
-- only Sera effect remains untouched
-- At this time, I am considering just how pointless most of this is and that it's really just **BLING**
-- this detail is SO small that I'm considering replacing it with a simple beam between the two entities for ALL factions
-- and getting rid of all this complex calculation for position and intermediate nodes
function CreateAdjacencyBeams( unit, adjacentUnit )

	local LOUDINSERT = table.insert
	local LOUDATTACHEMITTER = CreateAttachedEmitter

	local info = { Unit = adjacentUnit.Sync.id, Trash = TrashBag(), }
    
    local army = unit.Sync.army
    local faction = __blueprints[unit.BlueprintID].General.FactionName

    -- Determine which effects we will be using	-- default to Cybran
    local beamEffect = '/effects/emitters/adjacency_cybran_beam_01_emit.bp'

    if faction == 'Aeon' then
    
        beamEffect = '/effects/emitters/adjacency_aeon_beam_01_emit.bp'
		
    elseif faction == 'UEF' then
    
        beamEffect = '/effects/emitters/adjacency_uef_beam_01_emit.bp'	

    end    

    if beamEffect then
    
        local beam = LOUDATTACHBEAMENTITY( unit, -1, adjacentUnit, -1, army, beamEffect )
        
        TrashAdd( info.Trash, beam )
        TrashAdd( unit.Trash, beam )
    end

	LOUDINSERT( unit.AdjacencyBeamsBag, info)

end


function PlaySacrificingEffects( unit, target_unit )

	local bp = ALLBPS[unit.BlueprintID]
	local faction = bp.General.FactionName

	if faction == 'Aeon' then
		for _, v in EffectTemplate.ASacrificeOfTheAeon01 do
			TrashAdd( unit.Trash, LOUDEMITONENTITY( unit, unit.Sync.army, v) )
		end
	end
end

function PlaySacrificeEffects( unit, target_unit )
	local army = unit.Sync.army
	local bp = ALLBPS[unit.BlueprintID]
	local faction = bp.General.FactionName

	if faction == 'Aeon' then
		for _, v in EffectTemplate.ASacrificeOfTheAeon02 do
			LOUDEMITATENTITY( target_unit, army, v)
		end
	end
end


function PlayReclaimEffects( reclaimer, reclaimed, BuildEffectBones, EffectsBag )

    local pos = reclaimed:GetPosition()

    local beamEnd = Entity()
    
    TrashAdd( EffectsBag,beamEnd )
    
    LOUDWARP( beamEnd, pos )
    
    local beamEffect

    for _, vBone in BuildEffectBones do
    
		for _, vEmit in ReclaimBeams do
        
			beamEffect = LOUDATTACHBEAMENTITY(reclaimer, vBone, beamEnd, -1, reclaimer.Sync.army, vEmit )
            
			TrashAdd( EffectsBag, beamEffect )
		end
	end
	
	for _, v in ReclaimObjectAOE do
	    TrashAdd( EffectsBag, LOUDEMITONENTITY( reclaimed, reclaimer.Sync.army, v ) )
	end
end

function PlayReclaimEndEffects( reclaimer, reclaimed )

    local army = -1
	
    if reclaimer then
        army = reclaimer.Sync.army
    end
    
	for _, v in ReclaimObjectEnd do
	    LOUDEMITATENTITY( reclaimed, army, v )
	end
	
	CreateLightParticleIntel( reclaimed, -1, army, 4, 6, 'glow_02', 'ramp_flare_02' )
end


function PlayCaptureEffects( capturer, captive, BuildEffectBones, EffectsBag )

	local army = capturer.Sync.army

    for _, vBone in BuildEffectBones do
    
		for _, vEmit in EffectTemplate.CaptureBeams do
			TrashAdd( EffectsBag, LOUDATTACHBEAMENTITY(capturer, vBone, captive, -1, army, vEmit ) )
		end
        
	end
end


function CreateCybranQuantumGateEffect( unit, bone1, bone2, EffectsBag, startwaitSeed )

    local BeenDestroyed = moho.entity_methods.BeenDestroyed

    -- Adding a quick wait here so that unit bone positions are correct
    WaitTicks( startwaitSeed * 10 )

    local BeenDestroyed = moho.entity_methods.BeenDestroyed
    local WaitTicks = coroutine.yield

    local pos1 = unit:GetPosition(bone1)
    local pos2 = unit:GetPosition(bone2)
    
    pos1[2] = pos1[2] - 0.72
    pos2[2] = pos2[2] - 0.72

    -- Create a projectile for the end of build effect and LOUDWARP it to the unit
    local BeamStartEntity = unit:CreateProjectile('/effects/entities/UEFBuild/UEFBuild01_proj.bp',0,0,0,nil,nil,nil)
    
    TrashBag:Add( BeamStartEntity )
    LOUDWARP( BeamStartEntity, pos1)
    
    local BeamEndEntity = unit:CreateProjectile('/effects/entities/UEFBuild/UEFBuild01_proj.bp',0,0,0,nil,nil,nil)
    
    TrashBag:Add( BeamEndEntity )
    LOUDWARP( BeamEndEntity, pos2)    

    -- Create beam effect
    TrashBag:Add(LOUDATTACHBEAMENTITY(BeamStartEntity, -1, BeamEndEntity, -1, unit.Sync.army, '/effects/emitters/cybran_gate_beam_01_emit.bp' ))

    -- Determine a the velocity of our projectile, used for the scaning effect
    local velY = 1
    BeamEndEntity:SetVelocity( 0, 1, 0 )

    local flipDirection = true

    -- LOUDWARP our projectile back to the initial corner and lower based on build completeness
    while not BeenDestroyed(unit) do

        if flipDirection then
            BeamStartEntity:SetVelocity( 0, velY, 0 )
            BeamEndEntity:SetVelocity( 0, velY, 0 )
            flipDirection = false
        else
            BeamStartEntity:SetVelocity( 0, -velY, 0 )
            BeamEndEntity:SetVelocity( 0, -velY, 0 )
            flipDirection = true
        end
        
        WaitTicks( 40 )
    end
end

function CreateEnhancementEffectAtBone( unit, bone, EffectsBag )

    for _, vEffect in EffectTemplate.UpgradeBoneAmbient do
	
        TrashAdd( EffectsBag, LOUDATTACHEMITTER( unit, bone, unit.Sync.army, vEffect ))
		
    end
	
end

function CreateEnhancementUnitAmbient( unit, bone, EffectsBag )

    for _, vEffect in EffectTemplate.UpgradeUnitAmbient do
	
        TrashAdd( EffectsBag, LOUDATTACHEMITTER( unit, bone, unit.Sync.army, vEffect ))
		
    end
	
end

function CleanupEffectBag( self, EffectBag )

	if self[EffectBag] then
	
		for _, v in self[EffectBag] do

			v:Destroy()
		end
		
	end
	
    self[EffectBag] = {}
	
end

function SeraphimRiftIn( unit )

	unit:HideBone(0, true)
	
	for _, v in EffectTemplate.SerRiftIn_Small do
		LOUDATTACHEMITTER ( unit, -1, unit.Sync.army, v )
	end
	
	WaitTicks (20)	
	CreateLightParticle( unit, -1, unit.Sync.army, 4, 15, 'glow_05', 'ramp_jammer_01' )	
	WaitTicks(1)	
	unit:ShowBone(0, true)	
	WaitTicks(2)
	
	for _, v in EffectTemplate.SerRiftIn_SmallFlash do
		LOUDATTACHEMITTER ( unit, -1, unit.Sync.army, v )
	end	
end

function SeraphimRiftInLarge( unit )

	unit:HideBone(0, true)
	
	for _, v in EffectTemplate.SerRiftIn_Large do
		LOUDATTACHEMITTER ( unit, -1, unit.Sync.army, v )
	end
	
	WaitTicks(20)	
	CreateLightParticle( unit, -1, unit.Sync.army, 25, 15, 'glow_05', 'ramp_jammer_01' )	
	WaitTicks(1)	
	unit:ShowBone(0, true)	
	WaitTicks(2)
	
	for _, v in EffectTemplate.SerRiftIn_LargeFlash do
		LOUDATTACHEMITTER ( unit, -1, unit.Sync.army, v )
	end	
end

function CybranBuildingInfection( unit )
	for k, v in EffectTemplate.CCivilianBuildingInfectionAmbient do
		LOUDATTACHEMITTER ( unit, -1, unit.Sync.army, v )
	end	
end

function CybranQaiShutdown( unit )
	for k, v in EffectTemplate.CQaiShutdown do
		LOUDATTACHEMITTER ( unit, -1, unit.Sync.army, v )
	end	
end

function AeonHackACU( unit )
	for k, v in EffectTemplate.AeonOpHackACU do
		LOUDATTACHEMITTER ( unit, -1, unit.Sync.army, v )
	end		
end

function PlayTeleportChargeEffects(self)

    local army = self.Sync.army
    local bp = ALLBPS[self.BlueprintID]

    self.TeleportChargeBag = {}
    local count = 0

    for k, v in EffectTemplate.GenericTeleportCharge01 do
    
        local fx = LOUDEMITATENTITY( self, army, v ):OffsetEmitter(0, ( bp.Physics.MeshExtentsY or 1 ) * 0.5, 0)
        
        TrashAdd( self.Trash, fx )
        
        count = count + 1
        self.TeleportChargeBag[count] = fx
    end

	-- from BO:U
    if not self.Dead and not self.EXPhaseEnabled == true then
		--EXTeleportChargeEffects(self)
    end		
end

function PlayTeleportInEffects(self)

    local army = self.Sync.army
    local bp = ALLBPS[self.BlueprintID]

    for k, v in EffectTemplate.GenericTeleportIn01 do
        LOUDEMITATENTITY( self, army, v ):OffsetEmitter(0, ( bp.Physics.MeshExtentsY or 1 ) * 0.5, 0)
    end

    if not self.Dead and self.EXPhaseEnabled then   
		EXTeleportCooldownEffects(self)
    end
end

function PlayTeleportOutEffects(self)

    local army = self.Sync.army
	
    for k, v in EffectTemplate.GenericTeleportOut01 do
        LOUDEMITATENTITY(self,army,v)
    end
end	

function CleanupTeleportChargeEffects(self)

    if self.TeleportChargeBag then
        for keys,values in self.TeleportChargeBag do
            values:Destroy()
        end
        self.TeleportChargeBag = {}
    end
end

function EXTeleportChargeEffects(self)

    if not self.Dead then

		local bpe = ALLBPS[self.BlueprintID].Economy

		self.EXPhaseEnabled = true
		self.EXPhaseCharge = 1
		self.EXPhaseShieldPercentage = 0

		if bpe then
			local mass = bpe.BuildCostMass * math.min(.1, bpe.TeleportMassMod or 0.01)
			local energy = bpe.BuildCostEnergy * math.min(.01, bpe.TeleportEnergyMod or 0.001)

			energyCost = mass + energy
			EXTeleTime = energyCost * (bpe.TeleportTimeMod or 0.0001)
			
			self.EXTeleTimeMod1 = (EXTeleTime * 10) * 0.2
			self.EXTeleTimeMod2 = self.EXTeleTimeMod1 * 2
			self.EXTeleTimeMod3 = (EXTeleTime * 10) - ((self.EXTeleTimeMod1 * 2) + self.EXTeleTimeMod2)
			self.EXTeleTimeMod4 = (self.EXTeleTimeMod3) - 7

			local bp = ALLBPS[self.BlueprintID]
			local bpDisplay = bp.Display

			if self.EXPhaseCharge == 1 then
				WaitTicks(self.EXTeleTimeMod1)
			end

			if self.EXPhaseCharge == 1 then
				self:SetMesh(bpDisplay.Phase1MeshBlueprint, true)
				self.EXPhaseShieldPercentage = 33
				WaitTicks(self.EXTeleTimeMod2)
			end

			if self.EXPhaseCharge == 1 then
				self.EXPhaseShieldPercentage = 66
				WaitTicks(self.EXTeleTimeMod1)
			end

			if self.EXPhaseCharge == 1 then
				self.EXPhaseShieldPercentage = 100
				if self.EXTeleTimeMod3 >= 7 then
					WaitTicks(self.EXTeleTimeMod4)
				end
			end
			
			if self.EXPhaseCharge == 1 then
				self:SetMesh(bpDisplay.Phase2MeshBlueprint, true)
			end
		end
    end
end

function EXTeleportCooldownEffects(self)

    if not self.Dead then

        local bp = ALLBPS[self.BlueprintID]
		local bpDisplay = bp.Display

		self.EXPhaseCharge = 0

		if self.EXPhaseCharge == 0 then
			self.EXPhaseShieldPercentage = 100
			WaitTicks(5)
		end

		if self.EXPhaseCharge == 0 then
			self.EXPhaseShieldPercentage = 100
			self:SetMesh(bpDisplay.Phase1MeshBlueprint, true)
			WaitTicks(8)
		end
		
		if self.EXPhaseCharge == 0 then
			self.EXPhaseShieldPercentage = 75
			self:SetMesh(bpDisplay.Phase1MeshBlueprint, true)
			WaitTicks(25)
		end

		if self.EXPhaseCharge == 0 then
			self.EXPhaseShieldPercentage = 50
			self:SetMesh(bpDisplay.MeshBlueprint, true)
			WaitTicks(10)
			self.EXPhaseShieldPercentage = 0
			self.EXPhaseEnabled = nil
		end
    end
end

function CreateUnitDestructionDebris( self, high, low, chassis )
--[[
    local HighDestructionParts = LOUDGETN(self.DestructionPartsHighToss)
    local LowDestructionParts = LOUDGETN(self.DestructionPartsLowToss)
    local ChassisDestructionParts = LOUDGETN(self.DestructionPartsChassisToss)

	local ShowBone = moho.unit_methods.ShowBone
	local CreateProjectileAtBone = moho.entity_methods.CreateProjectileAtBone
	local AttachBoneToEntityBone = moho.entity_methods.AttachBoneToEntityBone

    -- Create projectiles and accelerate them out and away from the unit
    if high and (HighDestructionParts > 0) then
        for i = 1, Random( 1, HighDestructionParts) do
            ShowBone( self, self.DestructionPartsHighToss[i], false )
            boneProj = CreateProjectileAtBone( self, '/effects/entities/DebrisBoneAttachHigh01/DebrisBoneAttachHigh01_proj.bp', self.DestructionPartsHighToss[i] )
            AttachBoneToEntityBone( self, self.DestructionPartsHighToss[i],boneProj, -1, false )
        end
    end

    if low and (LowDestructionParts > 0) then
        for i = 1, Random( 1, LowDestructionParts) do
            ShowBone( self, self.DestructionPartsLowToss[i], false )
            boneProj = CreateProjectileAtBone( self, '/effects/entities/DebrisBoneAttachLow01/DebrisBoneAttachLow01_proj.bp', self.DestructionPartsLowToss[i] )
            AttachBoneToEntityBone( self, self.DestructionPartsLowToss[i],boneProj, -1, false )
        end
    end
	
    if chassis and (ChassisDestructionParts > 0) then
        for i = 1, Random( 1, ChassisDestructionParts) do
            ShowBone( self, self.DestructionPartsChassisToss[i], false )
            boneProj = CreateProjectileAtBone( self, '/effects/entities/DebrisBoneAttachChassis01/DebrisBoneAttachChassis01_proj.bp', self.DestructionPartsChassisToss[i] )
            AttachBoneToEntityBone( self, self.DestructionPartsChassisToss[i],boneProj, -1, false )
        end
    end
--]]
end	
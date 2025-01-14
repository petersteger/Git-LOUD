
local UIUtil = import('/lua/ui/uiutil.lua')

local destructingUnits = {}
local controls = {}
local countdownThreads = {}

function ConfirmUnitDestruction()
    if import('/lua/ui/campaign/campaignmanager.lua').campaignMode and table.getn(EntityCategoryFilterDown(categories.COMMAND, GetSelectedUnits())) > 0 then
        UIUtil.QuickDialog(GetFrame(0), '<LOC confirm_0001>You cannot self destruct during an operation!', '<LOC _Ok>', nil, 
            nil,  nil, 
            nil, nil,
            true, {worldCover = false, enterButton = 1, escapeButton = 1})
    else
        local units = GetSelectedUnits()
        if units then
            local unitIds = {}
            for _, unit in units do
                table.insert(unitIds, unit:GetEntityId())
            end
            SimCallback({Func = 'ToggleSelfDestruct', Args = {units = unitIds, owner = GetFocusArmy()}})
        end
    end
end
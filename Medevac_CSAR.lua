-- MEDEVAC Script for DCS, By RagnarDa, DragonShadow & Shagrat & Ciribob 2013, 2014, 2015


medevac = {}

-- SETTINGS FOR MISSION DESIGNER vvvvvvvvvvvvvvvvvv
medevac.medevacunits = { "MEDEVAC #1", "MEDEVAC #2", "MEDEVAC #3", "MEDEVAC #4", "MEDEVAC #5", "MEDEVAC RED #1" } -- List of all the MEDEVAC _UNIT NAMES_ (the line where it says "Pilot" in the ME)!
medevac.bluemash = { "BlueMASH #1", "BlueMASH #2" } -- The unit that serves as MASH for the blue side
medevac.redmash = { "RedMASH #1", "RedMASH #2" } -- The unit that serves as MASH for the red side
medevac.bluesmokecolor = 4 -- Color of smokemarker for blue side, 0 is green, 1 is red, 2 is white, 3 is orange and 4 is blue
medevac.redsmokecolor = 1 -- Color of smokemarker for red side, 0 is green, 1 is red, 2 is white, 3 is orange and 4 is blue
medevac.requestdelay = 2 -- Time in seconds before the survivors will request Medevac
medevac.coordtype = 3 -- Use Lat/Long DDM (0), Lat/Long DMS (1), MGRS (2), Bullseye imperial (3) or Bullseye metric (4) for coordinates.
medevac.bluecrewsurvivepercent = 100 -- Percentage of blue crews that will make it out of their vehicles. 100 = all will survive.
medevac.redcrewsurvivepercent = 100 -- Percentage of red crews that will make it out of their vehicles. 100 = all will survive.
medevac.sar_pilots = true -- Set to true to allow for Search & Rescue missions of downed pilots
medevac.max_units = 6 -- Maximum number of groups in a single helicopter
medevac.immortalcrew = false -- Set to true to make wounded crew immortal
medevac.invisiblecrew = false -- Set to true to make wounded crew insvisible
medevac.crewholdfire = false -- Set tot true to have wounded crew hold fire
medevac.rpgsoldier = true -- Set to true to spawn one of the wounded as a RPG-carrying soldier
medevac.clonenewgroups = false -- Set to true to spawn in new units (clones) of the rescued unit once they're rescued back to the MASH.
medevac.maxbleedtimemultiplier = 1.2 -- Minimum time * multiplier = Maximum time that the wounded will bleed in the transport before dying
medevac.cruisespeed = 40 -- Used for calculating distance/speed = Minimum time from medevac point to reaching MASH.
-- Meters per second, 40 = ~150km/h which is a bit under the low end of the Huey cruise speed.
medevac.minbleedtime = 60 -- Minimum bleed time that's possible to get
medevac.minlandtime = 60 -- Minimum time * medevac.pilotperformance < medevac.minlandtime --> Pad to at least this much time allocated for landing
medevac.pilotperformance = 0.15 -- Multiplier on how much of the given time pilot is expected to have left when reaching the MASH (On average)
medevac.messageTime = 30 -- Time to show the intial wounded message for in seconds

medevac.movingMessage = "Be there in a jiffy!"
medevac.loadDistance = 25 -- configure distance for troops to get in helicopter in meters.
medevac.checkinDistance = 50 -- Distance in meters until the ground units check in again with the heli

-- If you set it less than 25 the troops might not move close enough

-- SETTINGS FOR MISSION DESIGNER ^^^^^^^^^^^^^^^^^^^*

-- Changelog v 6
-- Rewrite of major functionality for more stability

-- Changelog v 5 (beta)
-- - Merged changes by DragonShadow
-- Injection of existing units as medevac groups, calculating minimum for bleed time based on distance from MASH.
-- Added a function for calculating the direct flight distance between two points.
-- Added padding for minimum landing time after flying the distance.
-- Added possibility to trigger a function when a specificied group is rescued.
-- Now finds closest friendly MASH unit and uses their distance for calculating bleed time.
-- - Merged changes by Shagrat

-- Changelog v 4.2
-- - Verified compatibility with MiST 3.2+ and removed compatibility with SCT.

-- Changelog v 4.1
-- - Added so units will place new smoke if the medevac crashes (requested by Xillinx)

-- Changelog v 4 alexej21
-- - Added option for immortal wounded.
-- - Added option for spawning every third crew as an RPG soldier.

-- Changelog v 4
-- - Added option medevac.sar_pilots for those that want to turn off the search for downed pilot feature, which
-- is probably better done by other scripts.

-- Changelog v 3.2
-- - Added possibility for multiple MASH:es
-- - Added option to hide bleedout timer.

-- Changelog v 3.1
-- - Added check so that MASH is on right coalition.
-- - Removed option to use MiST-messaging as it is not working.
-- - Added option to change color of smoke for each side


-- Sanity checks of mission designer
assert(medevac.bluemash ~= nil, "\n\n** HEY MISSION-DESIGNER!**\n\nThere is no MASH for blue side!\n\nMake sure medevac.bluemash points to\na live units.\n")
for nr, x in pairs(medevac.bluemash) do
    assert(Unit.getByName(x) ~= nil, string.format("\n\n** HEY MISSION-DESIGNER!**\n\nThe blue MASH '%s' doesn't exist!\n\nMake sure medevac.bluemash contains the\nnames of live units.\n", x))
    assert((Group.getCoalition(Unit.getGroup(Unit.getByName(x))) == 2), string.format("\n\n** HEY MISSION-DESIGNER!**\n\nmedevac.bluemash has to be units on BLUE coalition only!\nUnit '%s' is not on correct side.", x))
end
assert(medevac.redmash ~= nil, "\n\n** HEY MISSION-DESIGNER! **\n\nThere is no MASH for red side!\n\nMake sure medevac.redmash points to\na live unit.\n")
for nr, x in pairs(medevac.redmash) do
    assert(Unit.getByName(x) ~= nil, string.format("\n\n** HEY MISSION-DESIGNER!**\n\nThe red MASH '%s' doesn't exist!\n\nMake sure medevac.redmash contains the\nnames of live units.\n", x))
    assert((Group.getCoalition(Unit.getGroup(Unit.getByName(x))) == 1), string.format("\n\n** HEY MISSION-DESIGNER!**\n\nmedevac.redmash has to be units on RED coalition only!\nUnit '%s' is not on correct side.", x))
end
assert(mist ~= nil, "\n\n** HEY MISSION-DESIGNER! **\n\nMiST has not been loaded!\n\nMake sure MiST 3.6 or higher is running\n*before* running this script!\n")

medevac.addedTo = {}
medevac.deadUnits = {}

medevac.downedPilotCounterRed = 0
medevac.downedPilotCounterBlue = 0

medevac.woundedGroups = {} -- contains the new group of units
medevac.inTransitGroups = {} -- contain a table for each SAR with all units he has with the
                             -- original name of the killed group

medevac.smokeMarkers = {} -- tracks smoke markers for groups
medevac.heliVisibleMessage = {} -- tracks if the first message has been sent of the heli being visible
medevac.woundedMoving = {} -- tracks if the wounded are on the move
medevac.woundedMovingMessage = {} -- tracks if the wounded moving message has been sent

medevac.heliCloseMessage = {} -- tracks heli close message  ie heli < 500m distance

medevac.sarEjected = {} -- tracks if the pilot has ejected. Units can still get into the helicopter with no pilot if this inst checked

-- Utility

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function unitsInHelicopterCount(_heliName)
   local count = 0
   if medevac.inTransitGroups[_heliName] then
      for _, _group in pairs(medevac.inTransitGroups[_heliName]) do
         count = count + _group.woundedCount
      end
   end
   return count
end

-- Handles all world events
medevac.eventHandler = {}
function medevac.eventHandler:onEvent(_event)
    local status, err = pcall(function(_event)

        if _event == nil or _event.initiator == nil then
            return false

        elseif _event.id == 15 then

            -- if its a sar heli, re-add check status script
            for _, _heliName in pairs(medevac.medevacunits) do

                if _heliName == _event.initiator:getName() then
                    -- add back the status script
                    for _woundedName, _groupInfo in pairs(medevac.woundedGroups) do

                        if _groupInfo.side == _event.initiator:getCoalition() then

                            --env.info(string.format("Schedule Respawn %s %s",_heliName,_woundedName))
                            -- queue up script
                            -- Schedule timer to check when to pop smoke
                            timer.scheduleFunction(medevac.checkWoundedGroupStatus, { _heliName, _woundedName }, timer.getTime() + 5)
                        end
                    end
                end
            end

            return true

        elseif (_event.id == 9 and medevac.sar_pilots == true) then
            -- Pilot dead
            trigger.action.outTextForCoalition(_event.initiator:getCoalition(), "MAYDAY MAYDAY! " .. _event.initiator:getTypeName() .. " shot down. No Chute!", 10)

            --remove status messages for each Heli?

            return

        elseif ((world.event.S_EVENT_EJECTION == _event.id and medevac.sar_pilots == true)) or (_event.id == 8) then

            env.info("Event unit - Pilot Ejected or Unit Dead")
            -- Check if event has been fired more than once
            --                if (medevac.tableContains(medevac.deadUnits, _event.initiator)) then
            --                    env.warning("Event already fired for this unit. Not Handling!.", false)
            --                    return false
            --                end

            local _isPilot = false

            local _unit = _event.initiator

            local _spawnedGroup

            if world.event.S_EVENT_EJECTION == _event.id then

                _isPilot = true
                _spawnedGroup = medevac.spawnGroup(_unit, _isPilot)

            elseif Object.hasAttribute(_unit, "Ground vehicles") then

                -- handle vehicle dead

                local _country = _unit:getCoalition()

                local _survivalPercent = medevac.redcrewsurvivepercent
                local _randPercent = math.random(1, 99)

                if (_country == 2) then
                    _survivalPercent = medevac.bluecrewsurvivepercent
                end

                if (_survivalPercent < _randPercent) then
                    env.info(string.format("Crew from %s didn't make it. %u/%u", _unit:getTypeName(), _randPercent, _survivalPercent))
                    return false
                end

                _spawnedGroup = medevac.spawnGroup(_unit, _isPilot)

            else
                -- not the right kind of unit
                return false
            end

            -- Add special options to group
            if _spawnedGroup ~= nil then
                medevac.addSpecialParametersToGroup(_spawnedGroup)

                --store the old group under the new group name
                medevac.woundedGroups[_spawnedGroup:getName()] = { originalGroup = _unit:getGroup():getName(), side = _spawnedGroup:getCoalition() }

                if _isPilot then
                    trigger.action.outTextForCoalition(_unit:getCoalition(), "MAYDAY MAYDAY! " .. _unit:getTypeName() .. " shot down. Chute Spotted!", 10)
                end

              
                medevac.initSARForGroup(_spawnedGroup, _isPilot)
            end

            --dont add until we're done processing...
            --table.insert(medevac.deadUnits, _event.initiator)
        end
    end, _event)
    if (not status) then
        env.error(string.format("Error while handling event %s", err), medevac.displayerrordialog)
    end
end

medevac.addSpecialParametersToGroup = function(_spawnedGroup)

    -- Immortal code for alexej21
    local _setImmortal = {
        id = 'SetImmortal',
        params = {
            value = true
        }
    }
    -- invisible to AI, Shagrat
    local _setInvisible = {
        id = 'SetInvisible',
        params = {
            value = true
        }
    }

    local _controller = _spawnedGroup:getController()

    if (medevac.immortalcrew) then
        Controller.setCommand(_controller, _setImmortal)
    end

    if (medevac.invisiblecrew) then
        Controller.setCommand(_controller, _setInvisible)
    end
end

function medevac.spawnGroup(_deadUnit, _isPilot)

    local _id = mist.getNextGroupId()

    local _groupName = "Wounded " .. _deadUnit:getTypeName() .. " Crew #" .. _id

    if _isPilot then
        _groupName = "Downed Pilot #" .. _id
    end

    local _side = _deadUnit:getCoalition()

    local _pos = _deadUnit:getPoint()

    local _group = {
        ["visible"] = false,
        ["taskSelected"] = true,
        ["groupId"] = _id,
        ["hidden"] = false,
        ["units"] = {},
        ["y"] = _pos.z,
        ["x"] = _pos.x,
        ["name"] = _groupName,
        ["start_time"] = 0,
        ["task"] = "Ground Nothing",
        ["route"] = {
            ["points"] =
            {
                [1] =
                {
                    ["alt"] = 41,
                    ["type"] = "Turning Point",
                    ["ETA"] = 0,
                    ["alt_type"] = "BARO",
                    ["formation_template"] = "",
                    ["y"] = _pos.z,
                    ["x"] = _pos.x,
                    ["ETA_locked"] = true,
                    ["speed"] = 5.5555555555556,
                    ["action"] = "Diamond",
                    ["task"] =
                    {
                        ["id"] = "ComboTask",
                        ["params"] =
                        {
                            ["tasks"] =
                            {}, -- end of ["tasks"]
                        }, -- end of ["params"]
                    }, -- end of ["task"]
                    ["speed_locked"] = false,
                }, -- end of [1]
                [2] =
                {
                    ["alt"] = 54,
                    ["type"] = "Turning Point",
                    ["ETA"] = 52.09716824195,
                    ["alt_type"] = "BARO",
                    ["formation_template"] = "",
                    ["y"] = _pos.z,
                    ["x"] = _pos.x,
                    ["ETA_locked"] = false,
                    ["speed"] = 5.5555555555556,
                    ["action"] = "Diamond",
                    ["task"] =
                    {
                        ["id"] = "ComboTask",
                        ["params"] =
                        {
                            ["tasks"] =
                            {}, -- end of ["tasks"]
                        }, -- end of ["params"]
                    }, -- end of ["task"]
                    ["speed_locked"] = false,
                }, -- end of [2]
            }, -- end of ["points"]
        }, -- end of ["route"]
    }

    local _radius = 50

    if _isPilot then

        if _side == 2 then
            _group.units[1] = medevac.createUnit(_pos.x + 50, _pos.z + 50, 120, "Soldier M4")
        else
            _group.units[1] = medevac.createUnit(_pos.x + 50, _pos.z + 50, 120, "Infantry AK")
        end

    else
        for _i = 1, 3 do
            local _angle = math.pi * 2 * (_i - 1) / 3
            local _xOffset = math.cos(_angle) * _radius
            local _yOffset = math.sin(_angle) * _radius

            local _unitType

            if _side == 2 then

                if medevac.rpgsoldier == true and _i == 3 then
                    _unitType = "Soldier RPG"
                else
                    _unitType = "Soldier M4"
                end

            else

                if medevac.rpgsoldier == true and _i == 3 then
                    _unitType = "Soldier RPG"
                else
                    _unitType = "Infantry AK"
                end
            end
            _group.units[_i] = medevac.createUnit(_pos.x + _xOffset, _pos.z + _yOffset, _angle, _unitType, _isPilot)
        end
    end

    return coalition.addGroup(_side, Group.Category.GROUND, _group)
end


function medevac.createUnit(_x, _y, _heading, _type, _isPilot)

    local _id = mist.getNextUnitId();

    local _name

    if _isPilot then
        _name = string.format("Wounded Pilot #%s", _id)
    else
        _name = string.format("Wounded crew #%s", _id)
    end

    local _newUnit = {
        ["y"] = _y,
        ["type"] = _type,
        ["name"] = _name,
        ["unitId"] = _id,
        ["heading"] = _heading,
        ["playerCanDrive"] = true,
        ["skill"] = "Excellent",
        ["x"] = _x,
    }

    return _newUnit
end

function medevac.initSARForGroup(_downedGroup, _pilot)

    local _leader = _downedGroup:getUnit(1)

    local _coordinatesText = medevac.getPositionOfWounded(_downedGroup)

    local _text

    if (_pilot) then
        _text = string.format("%s requests SAR at %s", _leader:getName(), _coordinatesText)
    else
        _text = string.format("%s requests medevac at %s", _downedGroup:getName(), _coordinatesText)
    end

    -- Loop through all the medevac units
    for x, _heliName in pairs(medevac.medevacunits) do
        local _status, _err = pcall(function(_args)
            local _unitName = _args[1]
            local _woundedSide = _args[2]
            local _medevacText = _args[3]
            local _leaderPos = _args[4]
            local _groupName = _args[5]
            local _group = _args[6]

            local _heli = medevac.getSARHeli(_unitName)

            -- queue up for all SAR, alive or dead, we dont know the side if they're dead or not spawned so check
            --coalition in scheduled smoke

            if _heli ~= nil then

                -- Check coalition side
                if (_woundedSide == _heli:getCoalition()) then
                    -- Display a delayed message
                    timer.scheduleFunction(medevac.delayedHelpMessage, { _unitName, _medevacText, _groupName }, timer.getTime() + medevac.requestdelay)

                    -- Schedule timer to check when to pop smoke
                    timer.scheduleFunction(medevac.checkWoundedGroupStatus, { _unitName, _groupName }, timer.getTime() + 1)
                end
            else
                --env.warning(string.format("Medevac unit %s not active", _heliName), false)

                -- Schedule timer for Dead unit so when the unit respawns he can still pickup units
                --timer.scheduleFunction(medevac.checkStatus, {_unitName,_groupName}, timer.getTime() + 5)
            end
        end, { _heliName, _leader:getCoalition(), _text, _leader:getPoint(), _downedGroup:getName(), _downedGroup })

        if (not _status) then
            env.warning(string.format("Error while checking with medevac-units %s", _err))
        end
    end
end

function medevac.checkWoundedGroupStatus(_argument)

    local _status, _err = pcall(function(_args)
        local _heliName = _args[1]
        local _woundedGroupName = _args[2]

        local _woundedGroup = medevac.getWoundedGroup(_woundedGroupName)
        local _heliUnit = medevac.getSARHeli(_heliName)

        -- if wounded group is not here then message alread been sent to SARs
        -- stop processing any further
        if medevac.woundedGroups[_woundedGroupName] == nil then
            return
        end

        if _heliUnit == nil then
            --env.info(string.format("Helicopter is dead."))
            -- stop wounded moving, head back to smoke as target heli is DEAD
            if #_woundedGroup > 0 then
                if medevac.woundedMoving[_woundedGroupName] ~= nil and medevac.woundedMoving[_woundedGroupName].heli == _heliName then

                    -- go back to the smoke
                    medevac.orderGroupToMoveToPoint(_woundedGroup[1], medevac.woundedMoving[_woundedGroupName].point)
                    medevac.woundedMoving[_woundedGroupName] = nil
                end
            end

            -- in transit cleanup
            medevac.inTransitGroups[_heliName][_woundedGroupName] = nil
            return
        end

        -- double check that this function hasnt been queued for the wrong side

        if medevac.woundedGroups[_woundedGroupName].side ~= _heliUnit:getCoalition() then
            return --wrong side!
        end

        if medevac.checkGroupNotKIA(_woundedGroup, _woundedGroupName, _heliUnit, _heliName) then

            local _woundedLeader = _woundedGroup[1]
            local _lookupKeyHeli = _heliUnit:getID() .. "_" .. _woundedLeader:getID() --lookup key for message state tracking

            local _distance = medevac.getDistance(_heliUnit:getPoint(), _woundedLeader:getPoint())

            if _distance < 3000 then

                if medevac.checkCloseWoundedGroup(_distance, _heliUnit, _heliName, _woundedGroup, _woundedGroupName) == true then
                    -- we're close, reschedule
                    timer.scheduleFunction(medevac.checkWoundedGroupStatus, _args, timer.getTime() + 1)
                end

            else
                medevac.heliVisibleMessage[_lookupKeyHeli] = nil

                --reschedule as units arent dead yet , schedule for a bit slower though as we're far away
                timer.scheduleFunction(medevac.checkWoundedGroupStatus, _args, timer.getTime() + 5)
            end
        end
    end, _argument)

    if not _status then

        env.error(string.format("error checkWoundedGroupStatus %s", _err))
    end
end

function medevac.popSmokeForGroup(_woundedGroupName, _woundedLeader)
    -- have we popped smoke already in the last 5 mins
    local _lastSmoke = medevac.smokeMarkers[_woundedGroupName]
    if _lastSmoke == nil or timer.getTime() > _lastSmoke then

        local _smokecolor
        if (_woundedLeader:getCoalition() == 2) then
            _smokecolor = medevac.bluesmokecolor
        else
            _smokecolor = medevac.redsmokecolor
        end
        trigger.action.smoke(_woundedLeader:getPoint(), _smokecolor)

        medevac.smokeMarkers[_woundedGroupName] = timer.getTime() + 300 -- next smoke time
    end
end


-- Helicopter is within 3km
function medevac.checkCloseWoundedGroup(_distance, _heliUnit, _heliName, _woundedGroup, _woundedGroupName)

    local _woundedLeader = _woundedGroup[1]
    local _lookupKeyHeli = _heliUnit:getID() .. "_" .. _woundedLeader:getID() --lookup key for message state tracking

    local _woundedCount = #_woundedGroup

    medevac.popSmokeForGroup(_woundedGroupName, _woundedLeader)

    if medevac.heliVisibleMessage[_lookupKeyHeli] == nil then

        if _woundedCount > 1 then
            medevac.displayMessageToSAR(_heliUnit, string.format("%s: %s. We hear you! Damn that thing is loud! Land by the smoke.", _heliName, _woundedGroupName), 30)
        else
            medevac.displayMessageToSAR(_heliUnit, string.format("%s: %s. I hear you! Damn that thing is loud! Land by the smoke.", _heliName, _woundedLeader:getName()), 30)
        end
        --mark as shown for THIS heli and THIS group
        medevac.heliVisibleMessage[_lookupKeyHeli] = true
    end

    if (_distance < 500) then

        if medevac.heliCloseMessage[_lookupKeyHeli] == nil then

            if _woundedCount > 1 then
                medevac.displayMessageToSAR(_heliUnit, string.format("%s: %s. You're close now! Land within 500m of the smoke and we'll move to you.", _heliName, _woundedGroupName), 10)
            else
                medevac.displayMessageToSAR(_heliUnit, string.format("%s: %s. You're close now! Land within 500m of the smoke and I'll move to you.", _heliName, _woundedLeader:getName()), 10)
            end

            --mark as shown for THIS heli and THIS group
            medevac.heliCloseMessage[_lookupKeyHeli] = true
        end

        -- have we landed close enough?
        if _heliUnit:inAir() == false then

            medevac.woundedShouldMoveToHeli(_woundedGroupName, _woundedGroup, _heliName, _heliUnit, _distance)

            -- if you land on them, doesnt matter if they were heading to someone else as you're closer, you win! :)
            if (_distance < medevac.loadDistance) then
                -- GET IN!
            local _heliName = _heliUnit:getName()
            local _groups = medevac.inTransitGroups[_heliName]
            local _unitsInHelicopter = unitsInHelicopterCount(_heliName)

            -- init table if there is none for this helicopter
            if not _groups then
               medevac.inTransitGroups[_heliName] = {}
               _groups = medevac.inTransitGroups[_heliName]
            end

            -- if the heli can't pick them up, show a message and return
            if  _unitsInHelicopter + _woundedCount > medevac.max_units then
                medevac.displayMessageToSAR(
                   _heliUnit, string.format(
                      "%s, %s. We're already crammed with %d guys! No chance to get the %d of you in, sorry!",
                      _woundedGroupName, _heliName, _unitsInHelicopter, _woundedCount),10)
                    return true
                end

                --remove from wounded groups to stop message about death
                medevac.woundedMoving[_woundedGroupName] = nil

                medevac.inTransitGroups[_heliName][_woundedGroupName] =
                   {originalGroup = medevac.woundedGroups[_woundedGroupName].originalGroup,
                    woundedGroup =_woundedGroupName,
                    woundedCount = _woundedCount, -- used in unitsInHelicopterCount()
                    side = _heliUnit:getCoalition()}

                Group.destroy(_woundedLeader:getGroup())

                local _bleedTime = medevac.getBleedTime(_heliUnit)

                --NO MASH
                if _bleedTime == -1 then
                    medevac.displayMessageToSAR(_heliUnit, string.format("%s: NO MASH! The casulties died of despair!", _heliName), 10)
                    return false
                end

                -- will have bled out after  timer.getTime() >_bleedTime + timer.getTime()
                if _woundedCount > 1 then
                    medevac.displayMessageToSAR(_heliUnit, string.format("%s: %s. We're in! Get to the MASH ASAP! You've got %s seconds tops!", _heliName, _woundedGroupName, _bleedTime), 10)
                else
                    medevac.displayMessageToSAR(_heliUnit, string.format("%s: %s I'm in! Get to the MASH ASAP! You've got %s seconds tops!", _heliName, _woundedLeader:getName(), _bleedTime), 10)
                end

                timer.scheduleFunction(medevac.scheduledSARFlight,
                                       {heliName = _heliUnit:getName(),
                                        bleedTime =_bleedTime + timer.getTime(),
                                        groupName = _woundedGroupName},
                                       timer.getTime() + 5)
                return false
            end

        else
            -- stop moving, head back to smoke if the target heli leaves
            if medevac.woundedMoving[_woundedGroupName] ~= nil and medevac.woundedMoving[_woundedGroupName].heli == _heliName then

                medevac.displayMessageToSAR(_heliUnit, string.format("%s: %s. Heading back to the smoke. Where are you going?!", _heliName, _woundedGroupName), 10)

                medevac.orderGroupToMoveToPoint(_woundedLeader, medevac.woundedMoving[_woundedGroupName].point)

                medevac.woundedMoving[_woundedGroupName] = nil
            end
        end
    end

    return true
end



function medevac.checkGroupNotKIA(_woundedGroup, _woundedGroupName, _heliUnit, _heliName)

    -- check if unit has died or been picked up
    if #_woundedGroup == 0 and _heliUnit ~= nil then

        local inTransit = false

        for _currentHeli, _groups in pairs(medevac.inTransitGroups) do

         if _groups[_woundedGroupName] then
            local _group = _groups[_woundedGroupName]
            if _group.side == _heliUnit:getCoalition() then
                    inTransit = true

                    medevac.displayToAllSAR(string.format("%s has been picked up by %s", _woundedGroupName, _currentHeli), _heliUnit:getCoalition(), _heliName)

                    break
                end
            end
        end


        --display to all sar
        if inTransit == false then
            --DEAD

            medevac.displayToAllSAR(string.format("%s is KIA ", _woundedGroupName), _heliUnit:getCoalition(), _heliName)
        end

        --     medevac.displayMessageToSAR(_heliUnit, string.format("%s: %s is dead", _heliName,_woundedGroupName ),10)

        --stops the message being displayed again
        medevac.woundedGroups[_woundedGroupName] = nil
        medevac.woundedMoving[_woundedGroupName] = nil

        return false
    end

    --continue
    return true
end

-- get the closest wounded group to the helicopter
function medevac.getClosetGroupName(_heli)

    local _side = _heli:getCoalition()

    local _closetGroup = nil
    local _shortestDistance = -1
    local _distance = 0

    for _woundedName, _groupInfo in pairs(medevac.woundedGroups) do

        if _groupInfo.side == _side then

            local _tempWounded = medevac.getWoundedGroup(_woundedName)

            -- check group exists and not moving to someone else
            if #_tempWounded > 0 and medevac.woundedMoving[_woundedName] == nil then
                _distance = medevac.getDistance(_heli:getPoint(), _tempWounded[1]:getPoint())

                if _distance ~= nil and (_shortestDistance == -1 or _distance < _shortestDistance) then

                    _shortestDistance = _distance
                    _closetGroup = _woundedName
                end
            end
        end
    end

    return _closetGroup
end

-- check if a wounded group should move to the current heli
-- if the current group is NOT the closet to the current Heli then
-- they shouldn't move as a closer group will
function medevac.woundedShouldMoveToHeli(_woundedGroupName, _woundedGroup, _heliName, _heliUnit, _distance)

    local _woundedLeader = _woundedGroup[1]

    -- make sure no other groups are moving to helicopter
    for _movingName, _details in pairs(medevac.woundedMoving) do

        if _details.heli == _heliName and _movingName ~= _woundedGroupName then

            medevac.orderGroupToMoveToPoint(_woundedLeader, _details.point)
            medevac.woundedMoving[_movingName] = nil
        end
    end


    if medevac.inTransitGroups[_heliUnit:getName()] ~= nil then

        -- dont move to this heli if its full!
        return
    end

    --on the move?
   local _alreadyMoving = medevac.woundedMoving[_woundedGroupName] ~= nil
   if not _alreadyMoving then

        local _closetGroup = medevac.getClosetGroupName(_heliUnit)

        if _closetGroup == nil or _woundedGroupName == _closetGroup then

            -- moving to you!
            medevac.orderGroupToMoveToPoint(_woundedLeader, _heliUnit:getPoint())

            --store point so we can send them back to the smoke
         medevac.woundedMoving[_woundedGroupName] = {point = _woundedLeader:getPoint(),
                                                     heli = _heliName,
                                                     lastCheckin = _distance}

        else
            --- a different group will move to you later on in the scheduled tasks that is closer

            --  if _closetGroup ~= nil then
            -- env.info("Group Not the closet".._woundedGroupName.." this one was ".._closetGroup)
            --  end
        end
    end

    --check they're not already moving to a different helicopter
    if medevac.woundedMoving[_woundedGroupName] ~= nil and medevac.woundedMoving[_woundedGroupName].heli == _heliName then

      local _lastCheckin = medevac.woundedMoving[_woundedGroupName].lastCheckin

      -- only message if the group just started moving or if it moved at least $checkinDistance meters
      if (not _alreadyMoving) or (_lastCheckin - _distance >= medevac.checkinDistance) then

         -- update last checkin
         medevac.woundedMoving[_woundedGroupName].lastCheckin = _distance

        --possible issue if another heli lands nearby? they are alread heading to a differnt one
         --possible issue if another heli lands nearby? they are alread heading to a differnt one
         medevac.displayMessageToSAR(
            _heliUnit,
            string.format("%s: We are %u meters away and moving towards you! %s",
                          _heliName, _distance, medevac.movingMessage ),5)
      end
    else

        if medevac.woundedMoving[_woundedGroupName] ~= nil then
            medevac.displayMessageToSAR(_heliUnit, string.format("%s: We are heading to %s, go and pick up another group!", _heliName, medevac.woundedMoving[_woundedGroupName].heli), 10)
        end
    end
end

function medevac.getBleedTime(_heli)

    -- DS: Make sure the pilot has a reasonable time to make it to the MASH, while providing a challenge.
    local _mashes = medevac.bluemash
    if _heli:getCoalition() then
        _mashes = medevac.redmash
    end

    local _mashDistance = medevac.getClosetMASH(_heli)

    --mash down!
    if _mashDistance == -1 then
        return -1
    end

    local _minBleedTime = medevac.getMinBleedTime(_mashDistance, medevac.cruisespeed, medevac.minbleedtime)

    -- DS: If estimated time left for landing is under medevac.minlandtime seconds, pad it to medevac.minlandtime seconds.
    local _estimatedLandingTime = _minBleedTime * medevac.pilotperformance
    if (_estimatedLandingTime < medevac.minlandtime) then
        _minBleedTime = math.ceil(_minBleedTime + (medevac.minlandtime - _estimatedLandingTime))
    end
    local _maxBleedTime = math.ceil(_minBleedTime * medevac.maxbleedtimemultiplier)

    -- DS: Set random time between _minbleedtime and _maxbleedtime

    return math.random(_minBleedTime, _maxBleedTime)
end

function medevac.getMinBleedTime(_distance, _metersPerSecond, _minBleedTime)
    -- DS: _distance comes out in meters due to DCS coordinate system.
    local _bleedTime = math.ceil(_distance / _metersPerSecond)
    if _bleedTime < _minBleedTime then
        _bleedTime = _minBleedTime
    end

    return _bleedTime
end



function medevac.scheduledSARFlight(_args)
    --env.info("Bleed timer.", false)
    local _status, _err = pcall(function(_args)

         local _heliUnit = medevac.getSARHeli(_args.heliName)
         local _bleedOutTime = _args.bleedTime
         local _lastMessage = _args.message -- only show message if its changed if countdown is disabled
         local _woundedGroupName = _args.groupName

        if (_heliUnit == nil) then

            --Crashed on route - caught by event handler
            medevac.inTransitGroups[_args[1]] = nil
            --TODO display message?


            return
        end

        local _timeLeft = math.floor(0 + (_bleedOutTime - timer.getTime()))

        if (_timeLeft < 1) then
            -- trigger.action.outTextForGroup(_medevacid, string.format("The wounded has bled out.", _timeleft), 20)
            local _txt = string.format("%s: We lost him! Damn it! Survivor died of his wounds.", _heliUnit:getName())

            -- delete only one group
            medevac.inTransitGroups[_heliUnit:getName()][_woundedGroupName] = nil

            medevac.displayMessageToSAR(_heliUnit, _txt, 10)

            return
        end

        local _dist = medevac.getClosetMASH(_heliUnit)

        if _dist == -1 then

            -- Mash Dead
            medevac.inTransitGroups[_heliUnit:getName()][_woundedGroupName] = nil

            medevac.displayMessageToSAR(_heliUnit, string.format("%s: NO MASH! The casulties died of despair!", _heliUnit:getName()), 10)

            return
        end

        if _dist < 200 and _heliUnit:inAir() == false then

            local _originalGroup =   medevac.inTransitGroups[_heliUnit:getName()][_woundedGroupName].originalGroup

            medevac.inTransitGroups[_heliUnit:getName()] = nil

            if medevac.clonenewgroups and _originalGroup ~= "" then

                local _txt = string.format("%s: The wounded have been taken to the\nmedical clinic. Good job!\n\nReinforcments have arrived.", _heliUnit:getName())

                medevac.displayMessageToSAR(_heliUnit, _txt, 10)

                mist.cloneGroup(_originalGroup, true)
                
            else

                local _txt = string.format("%s: The wounded have been taken to the\nmedical clinic. Good job!", _heliUnit:getName())

                medevac.displayMessageToSAR(_heliUnit, _txt, 10)
            end
            return
        end

        -- trigger.action.outTextForGroup(_medevacid, string.format("Bring them back to the MASH ASAP!\n\nThe wounded will bleed out in: %u seconds.", _timeleft), 2)
        local _message = "Ok, he is stable!"
        if (_timeLeft < 2400) then
            _message = "Seems he's ok for now... Get us back!"
        end
        if (_timeLeft < 1800) then
            _message = "He's doing fine, but we should go straight to a hospital!"
        end
        if (_timeLeft < 1200) then
            _message = "This doesn't look good. He's getting worse!"
        end
        if (_timeLeft < 900) then
            _message = "He's lost a lot of blood! Seems he's bleeding internally!"
        end
        if (_timeLeft < 600) then
            _message = "I can't stop the bleeding! He's getting worse by the minute!"
        end
        if (_timeLeft < 300) then
            _message = "He is going into shock! Step on it!"
        end
        if (_timeLeft < 180) then
            _message = "We're having to resuscitate! Can't this crate go faster!?"
        end
        if (_timeLeft < 60) then
            _message = "We're losing him!! Damn!!!"
        end

        local _txt

        -- if medevac.showbleedtimer == true then
        --     _txt = string.format("%s: %s\n\nThe wounded will bleed out in: %u seconds.", _heliUnit:getName(), _message, _timeLeft)
        --     medevac.displayMessageToSAR(_heliUnit, _txt, 5)
        -- else
            --only show message again if its changed so we don't hide other radio messages
        if _lastMessage ~= _message then
            _txt = string.format("%s: %s", _heliUnit:getName(), _message)
            medevac.displayMessageToSAR(_heliUnit, _txt, 10)
        end
        -- end
        --queue up
         timer.scheduleFunction(medevac.scheduledSARFlight,
                                {heliName = _heliUnit:getName(),
                                 bleedTime = _bleedOutTime,
                                 message = _message,
                                 groupName = _woundedGroupName},
                                timer.getTime() + 1)
    end, _args)
    if (not _status) then
        env.error(string.format("Error while BleedTime\n\n%s", _err))
    end
end

function medevac.getClosetMASH(_heli)

    local _mashes = medevac.bluemash

    if (_heli:getCoalition() == 1) then
        _mashes = medevac.redmash
    end

    local _shortestDistance = -1
    local _distance = 0

    for _, _mashName in pairs(_mashes) do

        local _mashUnit = Unit.getByName(_mashName)

        if _mashUnit ~= nil and _mashUnit:isActive() and _mashUnit:getLife() > 0 then

            _distance = medevac.getDistance(_heli:getPoint(), _mashUnit:getPoint())

            if _distance ~= nil and (_shortestDistance == -1 or _distance < _shortestDistance) then

                _shortestDistance = _distance
            end
        end
    end

    if _shortestDistance ~= -1 then
        return _shortestDistance
    else
        return -1
    end
end

function medevac.getSARHeli(_unitName)

    local _heli = Unit.getByName(_unitName)

    if _heli ~= nil and _heli:isActive() and _heli:getLife() > 0 then

        return _heli
    end

    return nil
end

function medevac.orderGroupToMoveToPoint(_leader, _destination)

    local _group = _leader:getGroup()

    local _mission = {
        id = 'Mission',
        params = {
            route = {
                points = {
                    [1] = {
                        action = 0,
                        x = _leader:getPoint().x,
                        y = _leader:getPoint().z,
                        speed = 25,
                        ETA = 100,
                        ETA_locked = false,
                        name = "Starting point",
                        task = nil
                    },
                    [2] = {
                        action = 0,
                        x = _destination.x,
                        y = _destination.z,
                        speed = 25,
                        ETA = 100,
                        ETA_locked = false,
                        name = "Pick-up",
                        task = nil
                    },
                }
            },
        }
    }
    local _controller = _group:getController();
    Controller.setOption(_controller, AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.GREEN)
    _controller:setTask(_mission)
end

-- Displays a request for medivac
function medevac.delayedHelpMessage(_args)
    local status, err = pcall(function(_args)
        local _heliName = _args[1]
        local _text = _args[2]
        local _injuredGroupName = _args[3]

        local _heli = medevac.getSARHeli(_heliName)

        if _heli ~= nil and #medevac.getWoundedGroup(_injuredGroupName) > 0 then
            medevac.displayMessageToSAR(_heli, _text, medevac.messageTime)
        else
            env.info("No Active Heli or Group DEAD")
        end
    end, _args)

    if (not status) then
        env.error(string.format("Error in delayedHelpMessage "))
    end

    return nil
end


function medevac.displayMessageToSAR(_unit, _text, _time)

    trigger.action.outTextForGroup(_unit:getGroup():getID(), _text, _time)
end

function medevac.getWoundedGroup(_groupName)
    local _status, _result = pcall(function(_groupName)

        local _woundedGroup = {}
        local _units = Group.getByName(_groupName):getUnits()

        for _, _unit in pairs(_units) do

            if _unit ~= nil and _unit:isActive() and _unit:getLife() > 0 then
                table.insert(_woundedGroup, _unit)
            end
        end

        return _woundedGroup
    end, _groupName)

    if (_status) then
        return _result
    else
        --env.warning(string.format("getWoundedGroup failed! Returning 0.%s",_result), false)
        return {} --return empty table
    end
end

-- allows manually added wounded troops or downed pilots
-- Make sure that if you set _isPilot to true, the group only has one soldier in it
function medevac.injectWoundedGroup(_groupName,_isPilot)

    local _spawnedGroup = Group.getByName(_groupName)

    if _spawnedGroup ~= nil and _spawnedGroup:isActive() then

        medevac.addSpecialParametersToGroup(_spawnedGroup)

        --Set original group to empty string so mist doesnt respawn them if that option is enabled
        medevac.woundedGroups[_spawnedGroup:getName()] = { originalGroup = "", side = _spawnedGroup:getCoalition() }

        medevac.initSARForGroup(_spawnedGroup, _isPilot)

    else

        trigger.action.outText( "MISSION ERROR - Could not find wounded group ".._groupName.." to add to wounded", 5 )
    end

end


function medevac.convertGroupToTable(_group)

    local _unitTable = {}

    for _, _unit in pairs(_group:getUnits()) do

        if _unit ~= nil and _unit:getLife() > 0 then
            table.insert(_unitTable, _unit:getName())
        end
    end

    return _unitTable
end

function medevac.getPositionOfWounded(_woundedGroup)

    local _woundedTable = medevac.convertGroupToTable(_woundedGroup)

    local _coordinatesText = ""
    if medevac.coordtype == 0 then -- Lat/Long DMTM
    _coordinatesText = string.format("%s", mist.getLLString({ units = _woundedTable, acc = 3, DMS = 0 }))

    elseif medevac.coordtype == 1 then -- Lat/Long DMS
    _coordinatesText = string.format("%s", mist.getLLString({ units = _woundedTable, acc = 3, DMS = 1 }))

    elseif medevac.coordtype == 2 then -- MGRS
    _coordinatesText = string.format("%s", mist.getMGRSString({ units = _woundedTable, acc = 3 }))

    elseif medevac.coordtype == 3 then -- Bullseye Imperial
    _coordinatesText = string.format("bullseye %s", mist.getBRString({ units = _woundedTable, ref = coalition.getMainRefPoint(_woundedGroup:getCoalition()), alt = 0 }))

    else -- Bullseye Metric --(medevac.coordtype == 4)
    _coordinatesText = string.format("bullseye %s", mist.getBRString({ units = _woundedTable, ref = coalition.getMainRefPoint(_woundedGroup:getCoalition()), alt = 0, metric = 1 }))
    end

    return _coordinatesText
end


-- Displays all active MEDEVACS/SAR
function medevac.displayActiveSAR(_unitName)
    local _msg = "Active MEDEVAC/SAR:"

    local _heli = medevac.getSARHeli(_unitName)

    if _heli == nil then
        return
    end

    local _heliSide = _heli:getCoalition()

    for _groupName, _value in pairs(medevac.woundedGroups) do

        local _woundedGroup = medevac.getWoundedGroup(_groupName)

        if #_woundedGroup > 0 and (_woundedGroup[1]:getCoalition() == _heliSide) then

            local _coordinatesText = medevac.getPositionOfWounded(_woundedGroup[1]:getGroup())

            _msg = string.format("%s\n%s at %s", _msg, _groupName, _coordinatesText)
        end
    end
   _msg = string.format("%s\nYou have %d from a maximum of %d wounded onboard",
                        _msg, unitsInHelicopterCount(_unitName), medevac.max_units)


    medevac.displayMessageToSAR(_heli, _msg, 20)
end

function medevac.displayToAllSAR(_message, _side, _ignore)

    for _, _unitName in pairs(medevac.medevacunits) do

        local _unit = medevac.getSARHeli(_unitName)

        if _unit ~= nil and _unit:getCoalition() == _side then

            if _ignore == nil or _ignore ~= _unitName then
                medevac.displayMessageToSAR(_unit, _message, 10)
            end
        else
            -- env.info(string.format("unit nil %s",_unitName))
        end
    end
end


-- Adds menuitem to all medevac units that are active
function addMedevacMenuItem()
    -- Loop through all Medevac units

    timer.scheduleFunction(addMedevacMenuItem, nil, timer.getTime() + 5)

    for _, _unitName in pairs(medevac.medevacunits) do

        local _unit = medevac.getSARHeli(_unitName)

        if _unit ~= nil then

            if medevac.addedTo[_unitName] == nil then

                missionCommands.addCommandForGroup(_unit:getGroup():getID(),
                    "Active MEDEVAC/SAR",
                    nil,
                    medevac.displayActiveSAR,
                    _unitName)

                --   env.info(string.format("Medevac event handler added %s",_unitName))

                medevac.addedTo[_unitName] = true
            end
        else
            -- env.info(string.format("unit nil %s",_unitName))
        end
    end

    return
end

--get distance in meters assuming a Flat world
function medevac.getDistance(_point1, _point2)

    local xUnit = _point1.x
    local yUnit = _point1.z
    local xZone = _point2.x
    local yZone = _point2.z

    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone

    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end


-- Schedule timer to add radio item
timer.scheduleFunction(addMedevacMenuItem, nil, timer.getTime() + 5)

world.addEventHandler(medevac.eventHandler)

env.info("Medevac event handler added")

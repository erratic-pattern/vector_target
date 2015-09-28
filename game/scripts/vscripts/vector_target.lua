--[[ 
    AUTHOR: Adam Curtis, Copyright 2015
    CONTACT: kallisti.dev@gmail.com
    WEBSITE: https://github.com/kallisti-dev/vector_target
    LICENSE: https://github.com/kallisti-dev/vector_target/blob/master/LICENSE 
    
    A library for HoN-like vector targeting in Lua abilities.
    
    Basic Setup Guide:
            
        * Call InitVectorTarget somewhere in your initialization code.
        
            VectorTarget:Init()
        
        * If you plan on using the default range finder particle, you need to call PrecacheVectorTarget in your Precache     
          function, like this:
        
            function Precache( context ) 
                VectorTarget:Precache( context )
            end
            
        * Finally, you need to include vector_target.js in the <scripts> of one of your panorama layouts. 
          The layout you choose to load the library in is mostly irrelevant, as long as you load it only once at a time before abilities can be casted.
          
            <scripts>
                <include src="file://{resources}/scripts/vector_target.js" />
            </scripts>
        
    KV usage:
    
        This library uses a KV file to specify ability vector-targeting behavior. The KV file uses the same structure as 
        npc_abilities_custom.txt, and by default this is the file we load KV data from. However, if you'd like to load vector         targeting information from another KV file, you can use the kv option when calling VectorTarget:Init
            
            VectorTarget:Init({ kv = "my_custom_kv_file.txt" })
            
        You can also pass a table as the kv option, which will use that table as though it were the table returned by the 
        LoadKeyValues API function.
            
        With that aside, we can talk about the KV file format. For default vector targeting behavior, all you need to do is 
        add a VectorTarget key to the ability's definition block.
        
            "my_ability"
            {
                "VectorTarget"      "1"
            }
            
        For fine-tuning of vector targeting options, you can pass a block with various option keys:
        
            "my_ability"
            {
                "VectorTarget"
                {
                    "ParticleName"  "particles/my_custom_particle.vpcf"  // Use a custom particle system 
                                                                         // (set to 0 for no particle)
                    
                    "ControlPoints" // use custom control points for the particle
                    {
                        "0": "initial"  // Set CP0 to the vector's initial point (the first location clicked)
                        "1": "terminal" // Set CP1 to the vector's terminal point (the second location clicked)
                    }
                    
                    "PointOfCast"   "midpoint"  // Determines what point the caster must actually turn towards in order to 
                                                // begin the cast animation. By default this is set to "initial", which means
                                                // the caster turns towards the first point that was clicked.
                                                // Setting it to "terminal" means the caster will face the second point that                                                 // was clicked. Here we use "midpoint", which means the point of cast will be
                                                // inbetween the initial and terminal points.
                                                
                    "MaxDistance"   "1000" // Sets the max distance of the vector. Currently this isn't enforced and we don't
                                           // do much with this parameter other than return it via GetMaxDistance,
                                           // but this will likely change in the future.
                                           
                    "MinDistance"   "500"  // Minimum vector distance, also not fully supported yet.
                }
            }
            
    Ability Logic:
    
        To get information about the input vector during cast, you have to write vector-targeted abilities as Lua abilities.
        The information is provided as methods that we attach to the ability's Lua table.
        
        Vector-target Ability Methods:
        
            :GetInitialPosition() - The initial position as a Vector
            
            :GetTerminalPosition() - The terminal cast location as a Vector
            
            :GetMidpointPosition() - midpoint betwen initial/terminal as a vector
            
            :GetTargetVector() - The actual vector composed from the initial and terminal positions of the cast.
                                 In other words, this is the "vector" in the word "vector targeting".
                                 
            :GetDirectionVector() - The normalized target vector, indicating the direction in which the line was drawn.
            
            :GetPointOfCast() - The point that the caster turned towards before beginning his cast animation, as a Vector.
            
            :GetMaxDistance() - The MaxDistance KV field. Currently unused by the library, but provided for ability logic.
            
            :GetMinDistance() - The MinDistance KV field. Also unsued currently.
        
        
    ExecuteOrderFilter:
    
        This library uses the ExecuteOrderFilter. If you have other code that needs to run during this filter, you'll need to
        add an option to VectorTarget:Init to disable the SetExecuteOrderFilter initialization, and then call the function
        yourself.
        
            VectorTarget:Init({ noOrderFilter = true })
            
            function MyExecuteOrderFilter(ctx, params)
                if not VectorTarget:OrderFilter(params) then
                    return false
                end
                --insert your order filter logic here
            end
            
            GameRules:GetGameModEntity():SetExecuteOrderFilter(MyExecuteOrderFilter, {})
            
        ( As an aside, I would be very interested in working with the modding community to create a standard system for
         overloading these filter functions in a composable manner. This would go a long way in making library mode
         more readily interoptable. )
         
         
    "Real World" Examples:
        A Macropyre-like ability with vector targeting:
            Ability KV: https://github.com/kallisti-dev/WarOfExalts/blob/4aaf3c5db5ab4febd3e9ef1bd05c6529c4ca1a8a/game/dota_addons/warofexalts/scripts/npc/abilities/flameshaper_lava_wake.txt
            Ability Lua: https://github.com/kallisti-dev/WarOfExalts/blob/6f62f8c5a21f0c837e9ac43bd34479230c10a76a/game/dota_addons/warofexalts/scripts/vscripts/heroes/flameshaper/flameshaper_lava_wake.lua
         
    Planned Improvements and to-do:
        * Support various combinations of unit-targeting and point-targeting, for example HoN's "Vector Entity" target type.
        * Add more built-in particles for area/cone abilities, and wide abilities.
        * Add more variables for the ControlPoints KV blocks.
        * Properly handling %variables from AbilitySpecial in VectorTarget KV block.
        * Enforce and fully support MaxDistance and MinDistance. Which includes:
            *Options for specifying the localization string for "invalid cast distance" error messages.
            *Add ControlPoint variables for range finders to properly show valid/invalid distances
            *Add level scaling format, i.e.  "MaxDistance"  "500 600 700 800"
          
         
    Feedback, and Suggestions, Contributions:
    
        I am very interested in hearing your ideas for improving this library. Plese contact me at the email mentioned above
        if you have an idea or suggestion, and please submit a pull request to our github repo if you have a modification
        that would improve the library.
    
--]]

VECTOR_TARGET_VERSION = 0.1;

DEFAULT_VECTOR_TARGET_PARTICLE = "particles/vector_target/vector_target_range_finder_line.vpcf"

reloaded = reloaded ~= nil
if VectorTarget == nil then
    VectorTarget = {
        inProgressOrders = { }, -- a table of vector orders currently in-progress, indexed by player ID
        abilityKeys = { }, -- data loaded from KV files, indexed by ability name
        castQueues = { }, -- table of cast queues indexed by castQueues[unit ID][ability ID]
    }
elseif VectorTarget.initializedOrderFilter then
    VectorTarget:InitOrderFilter()
end

local queue = class({})

-- call this in your Precache() function to precache vector targeting particles
function VectorTarget:Precache(context)
    if self.initializedPrecache then return end
    print("[VECTORTARGET] precaching assets")
    --PrecacheResource("particle", "particles/vector_target_ring.vpcf", context)
    PrecacheResource("particle", "particles/vector_target/vector_target_range_finder_line.vpcf", context)
    initializedPrecache = true
end


-- call this in your init function to initialize for default use-case behavior
function VectorTarget:Init(opts)
    print("[VECTORTARGET] initializing")
    if not self.initializedPrecache then
        print("[VECTORTARGET] warning: PrecacheVectorTargetLib was not called.")
    end
    opts = opts or { }
    if not opts.noEventListeners then
        self:InitEventListeners()
    end
    if not opts.noOrderFilter then
        self:InitOrderFilter()
    end
    if not opts.noLoadKV then
        self:LoadKV(opts.kv or "scripts/npc/npc_abilities_custom.txt")
    end
end

-- call this on a unit to add vector target functionality to its abilities
function VectorTarget:WrapUnit(unit)
    for i=0, unit:GetAbilityCount()-1 do
        local abil = unit:GetAbilityByIndex(i)
        if abil ~= nil then
            local keys = self.abilityKeys[abil:GetAbilityName()]
            if keys then
                self:WrapAbility(abil, keys)
            end
        end
    end
end


-- call this in your init function to start listening to events
function VectorTarget:InitEventListeners()
    if self.initializedEventListeners then return end
    print("[VECTORTARGET] registering event listeners")
    ListenToGameEvent("npc_spawned", function(ctx, keys)
            self:WrapUnit(EntIndexToHScript(keys.entindex))
    end, {})
    CustomGameEventManager:RegisterListener("vector_target_order_cancel", function(eventSource, keys)
        print("order cancel event")
        local inProgress = self.inProgressOrders[eventSource] 
        if inProgress ~= nil and inProgress.seqNum == keys.seqNum then
            print("canceling")
            self.inProgressOrders[eventSource - 1] = nil
        end
    end)
    CustomGameEventManager:RegisterListener("vector_target_queue_full", function(eventSource, keys)
        print("queue full")
        util.printTable(keys)
    end)
    self.initializedEventListeners = true
end

function VectorTarget:InitOrderFilter()
    print("[VECTORTARGET] registering ExecuteOrderFilter (use noOrderFilter option to prevent this)")
    local mode = GameRules:GetGameModeEntity()
    mode:ClearExecuteOrderFilter()
    mode:SetExecuteOrderFilter(function(_, data) return self:OrderFilter(data) end, {})
    self.initializedOrderFilter = true
end

-- Loads vector target KV values from a file, or a table with the same format as one returned by LoadKeyValues()
function VectorTarget:LoadKV(kv)
    print("[VECTORTARGET] loading KV data")
    if type(kv) == "string" then
        kv = LoadKeyValues(kv)
    elseif type(kv) ~= "table" then
        error("[VECTORTARGET] invalid input to LoadVectorTargetKV: " .. string(kv))
    end
    for name, keys in pairs(kv) do
        keys = keys["VectorTarget"]
        if keys and keys ~= "false" and keys ~= 0 then
            if type(keys) ~= "table" then
                keys = { }
            end
            self.abilityKeys[name] = keys
        end
    end        
end

-- get the cast queue for a given (unit, ability) pair
function VectorTarget.castQueues:get(unitId, abilId)
    local unitTable = self[unitId]
    if not unitTable then
        unitTable = { }
        self[unitId] = unitTable
    end
    local q = unitTable[abilId]
    if not q then
        q = queue()
        unitTable[abilId] = q
    end
    return q
end

-- given an array of unit ids, clear all cast queues associated with those units.
function VectorTarget.castQueues:clearQueuesForUnits(units)
    for _, unitId in pairs(units) do
        for _, q in pairs(self[unitId] or { }) do
            if q then
                q:clear()
            end
        end
    end
end

function VectorTarget.castQueues:getMaxSequenceNumber(unitId)
    local out = -1
    for _, q in pairs(self[unitId] or { }) do
        if q and q.last > out then
            out = q.last
        end
    end
    return out
end

function VectorTarget:OrderFilter(data)
    local playerId = data.issuer_player_id_const
    local abilId = data.entindex_ability
    local inProgress = self.inProgressOrders[playerId] -- retrieve any in-progress orders for this player
    local seqNum = data.sequence_number_const
    local units = { }
    local nUnits = 0
    for i, unitId in pairs(data.units) do
        if seqNum > self.castQueues:getMaxSequenceNumber(unitId) then
            units[i] = unitId
            nUnits = nUnits + 1
        end
    end
    if nUnits == 0 then
        return true
    end
    --print("seq num: ", seqNum, "order type: ", data.order_type, "queue: ", data.queue)
    if abilId ~= nil and abilId > 0 then
        local abil = EntIndexToHScript(abilId)
        if abil.isVectorTarget and data.order_type == DOTA_UNIT_ORDER_CAST_POSITION then
            local unitId = units["0"] or units[0]
            local targetPos = {x = data.position_x, y = data.position_y, z = data.position_z}
            if inProgress == nil or inProgress.abilId ~= abilId or inProgress.unitId ~= unitId then -- if no in-progress order, this order selects the initial point of a vector cast
                print("inProgress", playerId, abilId, unitId)
                local orderData = {
                    abilId = abilId,
                    orderType = data.order_type,
                    unitId = unitId,
                    initialPosition = targetPos,
                    shiftPressed = data.queue,
                    minDistance = abil:GetMinDistance(),
                    maxDistance = abil:GetMaxDistance(),
                    particleName = abil._vectorTargetKeys.particleName,
                    cpMap = abil._vectorTargetKeys.cpMap,
                    seqNum = seqNum,
                }
                self.inProgressOrders[playerId] = orderData --set this order as our player's current in-progress order
                CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "vector_target_order_start", orderData)
                return false
            else --in-progress order (initial point has been selected)
                if inProgress.shiftPressed == 1 then --make this order shift-queued if previous order was
                    data.queue = 1
                elseif data.queue == 0 then -- if not shift queued, clear cast queue before we add to it
                    self.castQueues:clearQueuesForUnits(units)
                end
                inProgress.terminalPosition = targetPos
                local p = VectorTarget._CalcPointOfCast(abil._vectorTargetKeys.pointOfCast, inProgress.initialPosition, inProgress.terminalPosition)
                data.position_x = p.x
                data.position_y = p.y
                data.position_z = p.z
                self.castQueues:get(unitId, abilId):push(inProgress, seqNum)
                self.inProgressOrders[playerId] = nil
                -- something in the inProgress table causes the event system to crash the game, so we need to make a new table and pick out
                -- only the important values.
                CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "vector_target_order_finish", {
                    --terminalPosition = inProgress.initialPosition,
                    --initialPosition = inProgress.terminalPosition,
                    unitId = inProgress.unitId,
                    abilId = inProgress.abilId,
                    seqNum = inProgress.seqNum,
                })
                return true -- exit early
            end
        end
    end
    if data.queue == 0 then -- if shift was not pressed, clear our cast queues for the unit(s) in question
        self.castQueues:clearQueuesForUnits(units)
    end
    if inProgress ~= nil then
        self.inProgressOrders[playerId] = nil
        CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "vector_target_order_cancel", inProgress)
    end
    return true
end

--wrapper applied to all vector targeted abilities during initialization
function VectorTarget:WrapAbility(abil, keys)
    local VectorTarget = self
    local abiName = abil:GetAbilityName()
    if "ability_lua" ~= abil:GetClassname() then
        print("[VECTORTARGET] warning: " .. abiName .. " is not a Lua ability and cannot be vector targeted.")
        return
    end
    if abil.isVectorTarget then
        return
    end
    
    --initialize members
    abil.isVectorTarget = true -- use this to test if an ability has vector targeting
    abil._vectorTargetKeys = {
        initialPosition = nil,                      -- initial position of vector input
        terminalPosition = nil,                     -- terminal position of vector input
        minDistance = keys.MinDistance,
        maxDistance = keys.MaxDistance,
        pointOfCast = keys.PointOfCast or "initial",
        particleName = keys.ParticleName or DEFAULT_VECTOR_TARGET_PARTICLE,
        cpMap = keys.ControlPoints
    }
    
    function abil:GetInitialPosition()
        return self._vectorTargetKeys.initialPosition
    end
    
    function abil:SetInitialPosition(v)
        if type(v) == "table" then
            v = Vector(v.x, v.y, v.z)
        end
        self._vectorTargetKeys.initialPosition = v
    end
    
    function abil:GetTerminalPosition()
        return self._vectorTargetKeys.terminalPosition
    end
    
    function abil:SetTerminalPosition(v)
        if type(v) == "table" then
            v = Vector(v.x, v.y, v.z)
        end
        self._vectorTargetKeys.terminalPosition = v
    end
    
    function abil:GetMidpointPosition()
        return VectorTarget._CalcMidPoint(self:GetInitialPosition(), self:GetTerminalPosition())
    end
    
    function abil:GetTargetVector()
        local i = self:GetInitialPosition()
        local j = self:GetTerminalPosition()
        return Vector(j.x - i.x, j.y - i.y, j.z - i.z)
    end
    
    
    function abil:GetDirectionVector()
        return self:GetTargetVector():Normalized()
    end
    
    if not abil.GetMinDistance then
        function abil:GetMinDistance()
            return self._vectorTargetKeys.minDistance
        end
    end
    
    if not abil.GetMaxDistance then
        function abil:GetMaxDistance()
            return self._vectorTargetKeys.maxDistance
        end
    end
    
    if not abil.GetPointOfCast then
        function abil:GetPointOfCast()
            return VectorTarget._CalcPointOfCast(abil._VectorTargetKeys.pointOfCast, abil:GetInitialPosition(), abil:GetTerminalPosition())
        end
    end
    
    if not abil.GetVectorTargetParticleName then
        function abil:GetVectorTargetParticleName()
            return self._vectorTargetKeys.particleName
        end
    end
    
    if not abil.GetVectorTargetControlPointMap then
        function abil:GetVectorTargetControlPointMap()
            return self._vectorTargetKeys.cpMap
        end
    end
    
    --override GetBehavior
    local _GetBehavior = abil.GetBehavior
    function abil:GetBehavior()
        local b = _GetBehavior(self)
        return bit.bor(b, DOTA_ABILITY_BEHAVIOR_POINT)
    end
    
    local _OnAbilityPhaseStart = abil.OnAbilityPhaseStart
    function abil:OnAbilityPhaseStart()
        local abilId = self:GetEntityIndex()
        local unitId = self:GetCaster():GetEntityIndex()
        --pop unit queue
        local data = VectorTarget.castQueues:get(unitId, abilId):popFirst()
        self:SetInitialPosition(data.initialPosition)
        self:SetTerminalPosition(data.terminalPosition)
        return _OnAbilityPhaseStart(self)
    end
end

function VectorTarget._CalcPointOfCast(mode, initial, terminal)
    if mode == "initial" then
        return initial
    elseif mode == "terminal" then
        return terminal
    elseif mode == "midpoint" then
        return VectorTarget._CalcMidPoint(initial, terminal)
    else
        error("[VECTORTARGET] invalid point-of-cast mode: " .. string(mode))
    end
end

function VectorTarget._CalcMidPoint(a, b)
    return Vector((a.x + b.x)/2, (a.y + b.y)/2, (a.z + b.z)/2)
end
-- a sparse queue implementation
function queue.constructor(q)
    q.first = 0
    q.last = -1
    q.len = 0
end

function queue.push(q, value, seqN)
    --print("push", q.first, q.last, q.len)
    --[[if q:length() >= MAX_ORDER_QUEUE then
        print("[VECTORTARGET] warning: order queue has reached limit of " .. MAX_ORDER_QUEUE)
        return
    end]]
    if seqN == nil then
        seqN = q.last + 1
    end
    q[seqN] = value
    q.len = q.len + 1
    if q.len == 1 then
        q.first = seqN
        q.last = seqN
    elseif seqN > q.last then
        q.last = seqN
    elseif seqN < q.first then
        q.first = seqN
    end
end

function queue.popLast(q)
    local last = q.last
    if q.first > last then error("queue is empty") end
    local value = q[last]
    q[last] = nil
    q.len = q.len - 1
    for i = last, q.first, -1 do --find new last index
        if q[i] ~= nil then
            q.last = i
            return value
        end
    end
    q.last = q.first - 1 --empty
    return value
end


function queue.popFirst(q)
    --print("pop", q.first, q.last, q.len)
    local first = q.first
    if first > q.last then error("queue is empty") end
    local value = q[first]
    q[first] = nil
    q.len = q.len - 1
    for i = first, q.last do --find new first index
        if q[i] ~= nil then
            q.first = i
            return value
        end
    end
    q.first = q.last + 1 --empty
    return value
end

function queue.clear(q)
    for i = q.first, q.last do
        q[i] = nil
    end
    q.first = 0
    q.last = -1
    q.len = 0
end

function queue.peekLast(q)
    return q[q.last]
end

function queue.peekFirst(q)
    return q[q.first]
end

function queue.length(q)
    return q.len
end

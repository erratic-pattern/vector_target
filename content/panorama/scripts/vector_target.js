/*  
    AUTHOR: Adam Curtis, Copyright 2015
    CONTACT: kallisti.dev@gmail.com
    WEBSITE: https://github.com/kallisti-dev/baregrills
    
    Client-side handlers to accompany the server-side vector_target.lua library. Aside from including this script,
    no other client-side initialization is currently necessary.
    
*/

VECTOR_TARGET_VERSION = 0.1;

'use strict';
(function() {
    //constants
    var UPDATE_RANGE_INDICATOR_RATE = 1/30;
    var DEFAULT_CONTROL_POINTS = {
        0 : "initial",
        1 : "initial",
        2 : "terminal"
    }
    //state variables
    var rangeFinderParticle;
    var eventKeys = { };
    
    GameEvents.Subscribe("vector_target_order_start", function(keys) {
        //$.Msg("vector_target_order_start event");
        //$.Msg(keys);
        if(Game.GetLocalPlayerID() != keys.playerId)
            return;
        //initialize local state
        eventKeys = keys;
        var p = keys.initialPosition;
        keys.initialPosition = [p.x, p.y, p.z];
        //set defaults
        keys.cpMap = keys.cpMap || DEFAULT_CONTROL_POINTS;
        
        showRangeFinder();
        Abilities.ExecuteAbility(keys.abilId, keys.unitId, false); //make ability our active ability so that a left-click will complete cast
    });
    
    function showRangeFinder() {
        if(!rangeFinderParticle && eventKeys.particleName) {
            rangeFinderParticle = Particles.CreateParticle(eventKeys.particleName, ParticleAttachment_t.PATTACH_WORLDORIGIN, eventKeys.unitId);
            mapToControlPoints({"initial": eventKeys.initialPosition});
        }
    }
    
    function hideRangeFinder() {
        if(rangeFinderParticle) {
            Particles.DestroyParticleEffect(rangeFinderParticle, false);
            Particles.ReleaseParticleIndex(rangeFinderParticle);
            rangeFinderParticle = undefined;
        }
    }
    
    function updateRangeFinder() {
        var activeAbil = Abilities.GetLocalPlayerActiveAbility();
        //$.Msg("active ability: ", Abilities.GetLocalPlayerActiveAbility());
        if(eventKeys.abilId === activeAbil) {
            showRangeFinder();
        }
        if(rangeFinderParticle) {
            if(eventKeys.abilId !== activeAbil) {
                hideRangeFinder();
            }
            else {
                var pos = GameUI.GetScreenWorldPosition(GameUI.GetCursorPosition());
                if(pos != null)
                    mapToControlPoints({"terminal" : pos}, true);
            }
        }
        if(activeAbil === -1) {
            cancelVectorTargetOrder()
        }
        $.Schedule(UPDATE_RANGE_INDICATOR_RATE, updateRangeFinder);
    }
    updateRangeFinder();
    
    function cancelVectorTargetOrder() {
        if(eventKeys.abilId === undefined) return;
        GameEvents.SendCustomGameEventToServer("vector_target_order_cancel", eventKeys);
        finalize();
    }
    
    
    function mapToControlPoints(keyMap, ignoreConst) {
        var cpMap = eventKeys.cpMap;
        for(var cp in cpMap) {
            var vector = cpMap[cp].split(" ");
            if(vector.length == 1) {
                vector = [vector[0], vector[0], vector[0]]
            }
            else if(vector.length != 3) {
                throw new Error("Vector for CP " + cp + " has " + vector.length + " components");
            }
            var shouldSet = !ignoreConst;
            for(var i in vector) {
                var val = vector[i];
                var out;
                if((out = keyMap[val]) !== undefined) { //check for string variables
                    vector[i] = out[i];
                    if(ignoreConst) shouldSet = true;
                }
                else if(!isNaN(out = parseInt(val))) { //is a number
                    vector[i] = out;
                }
                else {
                    shouldSet = false;
                }
            }
            if(shouldSet) {
                Particles.SetParticleControl(rangeFinderParticle, parseInt(cp), vector);
            }
        }
    }
    
    function finalize() {
        //$.Msg("finalizer called");
        hideRangeFinder();
        eventKeys = { };
    }
    
    GameEvents.Subscribe("vector_target_order_cancel", function(keys) {
        if(Game.GetLocalPlayerID() != keys.playerId)
            return;
        if(keys.abilId === eventKeys.abilId && keys.unitId === eventKeys.unitId) {
            finalize();
        }
    });

    GameEvents.Subscribe("dota_update_selected_unit", function(keys) {
        var selection = Players.GetSelectedEntities(Game.GetLocalPlayerID());
        if(selected[0] !== eventKeys.unitId) {
            cancelVectorTargetOrder();
        }
    });
})()

$.Msg("vector_target.js loaded");

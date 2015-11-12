/*  
    AUTHOR: Adam Curtis, Copyright 2015
    CONTACT: kallisti.dev@gmail.com
    WEBSITE: https://github.com/kallisti-dev/vector_target
    LICENSE: https://github.com/kallisti-dev/vector_target/blob/master/LICENSE 
    
    Client-side handlers to accompany the server-side vector_target.lua library. Aside from including this script,
    no other client-side initialization is currently necessary.
    
*/
'use strict';
var VECTOR_TARGET_VERSION = [0, 3, 0]; //version data

var VectorTarget = {} // public API

VectorTarget.SetFastClickDragMode = function(flag) {
    /* Enables fast click-drag mode, where releasing the mouse button will complete the cast. */
    VectorTarget.fastClickDragMode = flag;
};

VectorTarget.IsFastClickDragMode = function() {
    /* Checks whether or not we're in fast click-drag mode */
    return VectorTarget.fastClickDragMode;
};


(function() {
    //constants
    var UPDATE_RANGE_FINDER_RATE = 1/30; // rate in seconds to update range finder control points
    var INACTIVE_CANCEL_DELAY = 0.1 // number of seconds to wait before the UI senda the cancel order event (prevents some race conditons between client/server handling)
    //state variables
    var rangeFinderParticle;
    var eventKeys = { };
    var prevEventKeys = { };
    var inactiveTimer = Game.GetGameTime(); // amount of time that no ability has been active 
    
    GameEvents.Subscribe("vector_target_order_start", function(keys) {
        //$.Msg("vector_target_order_start event");
        //$.Msg(keys);
        //initialize local state
        eventKeys = keys;
        var p = keys.initialPosition;
        keys.initialPosition = [p.x, p.y, p.z];
        Abilities.ExecuteAbility(keys.abilId, keys.unitId, false); //make ability our active ability so that a left-click will complete cast
        showRangeFinder();
    });
    
    function showRangeFinder() {
        if(!rangeFinderParticle && eventKeys.particleName) {
            rangeFinderParticle = Particles.CreateParticle(eventKeys.particleName, ParticleAttachment_t.PATTACH_ABSORIGIN, eventKeys.unitId);
            mapToControlPoints({
                "initial": eventKeys.initialPosition,
                "terminal": [eventKeys.initialPosition[0] + 1, eventKeys.initialPosition[1], eventKeys.initialPosition[2]]
            });
        };
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
        if(eventKeys.abilId === activeAbil) {
            showRangeFinder();
        }
        if(rangeFinderParticle) {
            if(eventKeys.abilId !== activeAbil) {
                hideRangeFinder();
            }
            else {
                var pos = GameUI.GetScreenWorldPosition(GameUI.GetCursorPosition());
                if(pos != null) {
                    var start = eventKeys.initialPosition;
                    var keys = { }
                    if (pos[0] != start[0] || pos[1] != start[1] || pos[2] != start[2]) {
                        keys.terminal = pos;
                        keys.midpoint = vMidPoint(start, pos);
                        keys.maxdistancedelta = 
                        mapToControlPoints(keys, true);
                    }
                }
            }
        }
        if(eventKeys.abilId != null && activeAbil === -1) {
            var now = Game.GetGameTime();
            inactiveTimer = inactiveTimer || now;
            if (now - inactiveTimer >= INACTIVE_CANCEL_DELAY ) {
                cancelVectorTargetOrder()
            }
        }
        else {
            inactiveTimer = null;
        }
        $.Schedule(UPDATE_RANGE_FINDER_RATE, updateRangeFinder);
    }
    updateRangeFinder();
    
    function cancelVectorTargetOrder() {
        if(eventKeys.abilId === undefined) return;
        //$.Msg("Canceling ", eventKeys)
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
                //$.Msg(cp, vector)
                Particles.SetParticleControl(rangeFinderParticle, parseInt(cp), vector);
            }
        }
    }
    
    function finalize() {
        //$.Msg("finalizer called");
        hideRangeFinder();
        prevEventKeys = eventKeys;
        /*
        if(Abilities.GetLocalPlayerActiveAbility() == eventKeys.abilId) {
            $.Msg("re-execute");
            Abilities.ExecuteAbility(eventKeys.abilId, eventKeys.unitId, false);
        }
        */
        eventKeys = { };
    }
    
    GameEvents.Subscribe("vector_target_order_cancel", function(keys) {
        //$.Msg("canceling");
        if(keys.seqNum === eventKeys.seqNum && keys.abilId === eventKeys.abilId && keys.unitId === eventKeys.unitId) {
            finalize();
        }
    });
    
    GameEvents.Subscribe("vector_target_order_finish", function(keys) {
        //$.Msg("finished")
        if(keys.seqNum === eventKeys.seqNum && keys.abilId === eventKeys.abilId && keys.unitId === eventKeys.unitId) {
            finalize();
        }
    });

    GameEvents.Subscribe("dota_update_selected_unit", function(keys) {
        var selection = Players.GetSelectedEntities(Game.GetLocalPlayerID());
        //$.Msg("update selected unit")
        if(selection[0] !== eventKeys.unitId) {
            cancelVectorTargetOrder();
        }
    });
    
    GameEvents.Subscribe("dota_hud_error_message", function(keys) {
        if(keys.reason == 105) { // reason code for a full order queue
            GameEvents.SendCustomGameEventToServer("vector_target_queue_full", prevEventKeys);
        }
    });
    
    //fast click-drag handling
    GameUI.SetMouseCallback(function(eventName, button) {
        if (eventKeys.abilId && VectorTarget.IsFastClickDragMode() && eventName == "released" && button == 0) {
            Abilities.ExecuteAbility(eventKeys.abilId, eventKeys.unitId, true);
        }
    });
    
    //VectorTarget.SetFastClickDragMode(true);

    /* functional programming helpers */

    function zipWith(f, a, b) {
        return a.map(function(x, i) { return f(x, b[i]); });
    }

    /* vector math */

    function vMidPoint(a, b) {
        return zipWith(function(a,b) { return (a + b) / 2; }, a, b)
        //return [ (a[0] + b[0])/2, (a[1] + b[1])/2, (a[2] + b[2])/2 ];
    }

    function vLength(v) {
        return Math.sqrt(v.reduce(function(a,b) { return a + Math.pow(b, 2); }, 0));
        //return Math.sqrt(Math.pow(v[0], 2), Math.pow(v[1], 2), Math.pow(v[2], 2));
    }

    function vNormalize(v) {
        var d = vLength(v);
        return vScalarDiv(v, d);
        //return [v[0] / d, v[1] / d, v[2] / d];
    }

    function vScalarMul(v, s) {
        return v.map(function(x) { return x * s; });
        //return [v[0] * s, v[1] * s, v[2] * s];
    }

    function vScalarDiv(v, s) {
        return v.map(function(x) { return x / s; });
    }

    function vDiff(a, b) {
        return zipWith(function(a,b){return a-b;}, a, b);
    }
    
})();

$.Msg("vector_target.js loaded");
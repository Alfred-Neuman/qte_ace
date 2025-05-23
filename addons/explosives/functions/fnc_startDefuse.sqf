#include "\z\ace\addons\explosives\script_component.hpp"

params ["_unit", "_target"];
TRACE_2("params",_unit,_target);

_target = attachedTo (_target);

private _fnc_DefuseTime = {
    params ["_specialist", "_target"];
    TRACE_2("defuseTime",_specialist,_target);
    private _defuseTime = 5;
    if (isNumber(configFile >> "CfgAmmo" >> typeOf (_target) >> QGVAR(DefuseTime))) then {
        _defuseTime = getNumber(configFile >> "CfgAmmo" >> typeOf (_target) >> QGVAR(DefuseTime));
    };
    if (!_specialist && {GVAR(PunishNonSpecialists)}) then {
        _defuseTime = _defuseTime * 1.5;
    };
    _defuseTime
};
private _actionToPlay = "MedicOther";
if (stance _unit == "Prone") then {
    _actionToPlay = "PutDown";
};

if (ACE_player != _unit) then {
    // If the unit is a player, call the function on the player.
    if (isPlayer _unit) then {
        [QGVAR(startDefuse), [_unit, _target], _unit] call CBA_fnc_targetEvent;
    } else {
        [_unit, _actionToPlay] call EFUNC(common,doGesture);
        _unit disableAI "MOVE";
        _unit disableAI "TARGET";
        private _defuseTime = [[_unit] call EFUNC(Common,isEOD), _target] call _fnc_DefuseTime;
        [{
            params ["_unit", "_target"];
            TRACE_2("defuse finished",_unit,_target);
            [_unit, _target] call FUNC(defuseExplosive);
            _unit enableAI "MOVE";
            _unit enableAI "TARGET";
        }, [_unit, _target], _defuseTime] call CBA_fnc_waitAndExecute;
    };
} else {
    [_unit, _actionToPlay] call EFUNC(common,doGesture);
    private _isEOD = [_unit] call EFUNC(Common,isEOD);
    private _defuseTime = [_isEOD, _target] call _fnc_DefuseTime;
    if (_isEOD || {!GVAR(RequireSpecialist)}) then {
        private _sequence = floor (_defuseTime * qte_ace_explosives_difficulty) max 1;
        if (qte_ace_explosives_enable && {!cba_quicktime_qteShorten} && {_sequence <= qte_ace_main_maxLengthRounded}) then {
            _sequence = [_sequence, "explosives"] call qte_ace_main_fnc_generateWordsQTE;

            private _newSuccess = {
                params ["_args"];
                _args params ["", "", "_aceArgs", "", "", ""];
                _aceArgs call FUNC(defuseExplosive);
                true
            };

            private _newFailure = {
                params ["_args", "_elapsedTime"];
                if (_args isEqualTo false) exitWith {};
                _args params ["_maxTime", "", "_aceArgs", "", "", ""];
                if (!qte_ace_explosives_mustBeCompleted && {_maxTime > 0 && {_elapsedTime >= _maxTime}}) then {
                    _aceArgs call FUNC(defuseExplosive);
                    true
                } else {
                    // nothing happens in ace usually, but...
                    if (!qte_ace_main_escPressed && qte_ace_explosives_explodeOnFail) then {
                        _aceArgs params ["_unit", "_explosive"];
                        // Kaboom :D
                        [_unit, -1, [_explosive, 1], "#ExplodeOnDefuse"] call FUNC(detonateExplosive);
                        [QGVAR(explodeOnDefuse), [_explosive, _unit]] call CBA_fnc_globalEvent;
                    };
                    false
                };
            };

            if (qte_ace_explosives_noTimer) then {
                _defuseTime = 0;
            };

            [
                _sequence,
                _newSuccess,
                _newFailure,
                {true},
                _defuseTime,
                round qte_ace_explosives_tries,
                [_unit,_target],
                localize LSTRING(DefusingExplosive),
                qte_ace_explosives_resetUponIncorrectInput,
                ["isNotSwimming"],
                qte_ace_explosives_mustBeCompleted
            ] call qte_ace_main_fnc_runQTE;
        } else {
            [_defuseTime, [_unit,_target], {(_this select 0) call FUNC(defuseExplosive)}, {}, (localize LSTRING(DefusingExplosive)), {true}, ["isNotSwimming"]] call EFUNC(common,progressBar);
        };
    };
};

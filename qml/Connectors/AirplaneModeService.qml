/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick 2.0
import LuneOS.Service 1.0
import LunaNext.Common 0.1
import Connman 0.2

/*
 * Airplane mode for the whole shell.
 *
 * Two components have to be told about it, because they own different halves
 * of the radios:
 *
 *  - ConnMan owns WiFi, Bluetooth (BluetoothManager.powered is an alias onto
 *    a ConnMan bluetooth technology) and cellular data. Its Manager.OfflineMode
 *    powers every technology down, remembers which ones were enabled, brings
 *    exactly those back afterwards, and persists the flag itself, so it comes
 *    back up in airplane mode across a reboot with no help from us.
 *
 *  - webos-telephonyd owns Modem.Online, i.e. voice and SMS. It persists power
 *    state per SIM and reapplies it at startup, so the modem half has to be
 *    switched through telephonyd rather than through ConnMan's cellular
 *    technology - otherwise the two disagree after a reboot and the outcome
 *    depends on service start order.
 *
 * The state is therefore read back from ConnMan, never from the airplaneMode
 * preference: that preference is only a mirror kept for other clients.
 */
Item {
    id: airplaneModeService

    // Transition states, numerically identical to the ones the legacy status
    // bar used, so that SystemMenu.setAirplaneModeStatus() keeps its meaning.
    readonly property int modeStateOff: 0
    readonly property int modeStateTurningOn: 1
    readonly property int modeStateTurningOff: 2
    readonly property int modeStateOn: 3

    // True while the radios are off.
    readonly property bool active: networkManager.offlineMode

    // True while a transition is still being applied. The menus grey out the
    // per-radio entries while this is set, the way webOS did.
    readonly property bool inProgress: __connmanPending || __telephonyPending || __simsPending > 0

    readonly property int modeState: inProgress ? (__target ? modeStateTurningOn : modeStateTurningOff)
                                                : (active ? modeStateOn : modeStateOff)

    readonly property string modeText: {
        switch (modeState) {
        case modeStateTurningOn:  return "Turning on Airplane Mode";
        case modeStateTurningOff: return "Turning off Airplane Mode";
        case modeStateOn:         return "Turn off Airplane Mode";
        default:                  return "Turn on Airplane Mode";
        }
    }

    signal transitionFinished(bool enabled)

    function toggle() {
        setActive(!active);
    }

    function setActive(enabled) {
        if (inProgress) {
            console.log("AirplaneModeService: transition already in progress, ignoring");
            return;
        }

        __target = enabled;
        __settled = false;

        if (enabled)
            __simPowerBeforeAirplane = ({});

        /*
         * Claim both legs before issuing either call: a call that fails
         * outright answers on the spot, and settling the transition while the
         * other leg has not even been started yet would report it finished.
         */
        __connmanPending = true;
        __telephonyPending = true;

        watchdog.restart();

        __applyToConnman(enabled);
        __applyToTelephony(enabled);
    }

    //
    // private
    //

    property bool __target: false
    property bool __connmanPending: false
    // Set while simListQuery is still outstanding, so that a fast reply from
    // the connection manager cannot settle the transition before we even know
    // how many modems there are to switch.
    property bool __telephonyPending: false
    property int  __simsPending: 0
    property bool __settled: true

    /*
     * Fallback path only: per slot power state as it was just before airplane
     * mode was turned on, so that a slot the user had deliberately switched off
     * does not come back on when airplane mode is turned off again. Only lives
     * as long as the shell does. A telephonyd with airplaneModeSet keeps this
     * itself, and keeps it across a reboot.
     */
    property var __simPowerBeforeAirplane: ({})

    function __applyToConnman(enabled) {
        /*
         * Deliberately routed through the connection manager rather than
         * written straight to NetworkManager.offlineMode: the adapter tears
         * down WiFi tethering first, which ConnMan on its own does not.
         */
        /*
         * com.webos.service.connectionmanager, not the com.palm alias: the
         * adapter registers both, but only this one is mapped to an access
         * control group, so a call to the alias is refused for anything that
         * is not running as root.
         */
        connectionManager.call("luna://com.webos.service.connectionmanager/setstate",
                               JSON.stringify({"offlineMode": enabled ? "enabled" : "disabled"}),
                               __connmanFinished,
                               function (message) {
                                   console.log("AirplaneModeService: connectionmanager/setstate failed: " + message.payload);
                                   __connmanFinished(message);
                               });
    }

    function __connmanFinished(message) {
        __connmanPending = false;
        __settleIfDone();
    }

    function __applyToTelephony(enabled) {
        __telephonyPending = true;

        /*
         * telephonyd owns airplane mode as a flag layered over the per slot
         * power state, so it restores exactly the slots which were on before,
         * and reapplies the whole thing itself after a reboot. One call, and
         * no slot bookkeeping needed on this side.
         */
        telephony.call("luna://com.palm.telephony/airplaneModeSet",
                       JSON.stringify({"state": enabled ? "on" : "off"}),
                       __telephonyFinished,
                       __airplaneModeSetFailed);
    }

    function __telephonyFinished(message) {
        __telephonyPending = false;
        __settleIfDone();
    }

    /*
     * Only an older telephonyd that has never heard of airplaneModeSet is worth
     * falling back for. Any other failure has already touched the radios, and
     * running the fallback on top of it would just switch them twice.
     */
    function __airplaneModeSetFailed(message) {
        if (message.payload.indexOf("Unknown method") < 0) {
            console.log("AirplaneModeService: airplaneModeSet failed: " + message.payload);
            __telephonyFinished(message);
            return;
        }

        /*
         * One shot query rather than a subscription: the slot list is only
         * needed at the moment the user flips the switch, and holding another
         * subscription here would duplicate the one TelephonyService already
         * has.
         */
        telephony.call("luna://com.palm.telephony/simListQuery", "{}",
                       __applyToSims,
                       __applyToDefaultSim);
    }

    /*
     * simListQuery only exists in telephonyd builds that know about more than
     * one SIM. Older ones answer "Unknown method", so fall back to the original
     * powerSet, which has no simId and is routed to the default voice SIM. If
     * there is no telephonyd at all - a WiFi only device is a perfectly normal
     * case here - this call fails too and the leg simply finishes.
     */
    function __applyToDefaultSim(message) {
        console.log("AirplaneModeService: simListQuery unavailable (" + message.payload +
                    "), falling back to the single SIM powerSet");

        __simsPending++;

        telephony.call("luna://com.palm.telephony/powerSet",
                       JSON.stringify({"state": __target ? "off" : "on", "save": true}),
                       __simFinished,
                       function (errorMessage) {
                           console.log("AirplaneModeService: powerSet failed: " + errorMessage.payload);
                           __simFinished(errorMessage);
                       });

        // Cleared only after the count above went up, so that inProgress
        // cannot momentarily read false in between.
        __telephonyPending = false;
        __settleIfDone();
    }

    function __applyToSims(message) {
        var response = JSON.parse(message.payload);

        if (!response.returnValue || !response.sims || response.sims.length === 0) {
            __telephonyPending = false;
            __settleIfDone();
            return;
        }

        for (var i = 0; i < response.sims.length; i++) {
            var sim = response.sims[i];

            // powerSet answers "Backend not initialized" for a slot telephonyd
            // has not finished bringing up, so skip those rather than fail.
            if (!sim.ready)
                continue;

            var wanted;
            if (__target) {
                __simPowerBeforeAirplane[sim.simId] = sim.powered;
                wanted = false;
            }
            else {
                wanted = __simPowerBeforeAirplane.hasOwnProperty(sim.simId) ? __simPowerBeforeAirplane[sim.simId]
                                                                           : true;
            }

            if (sim.powered === wanted)
                continue;

            __simsPending++;

            telephony.call("luna://com.palm.telephony/powerSet",
                           JSON.stringify({"simId": sim.simId,
                                           "state": wanted ? "on" : "off",
                                           "save": true}),
                           __simFinished,
                           function (errorMessage) {
                               console.log("AirplaneModeService: powerSet failed: " + errorMessage.payload);
                               __simFinished(errorMessage);
                           });
        }

        // Every powerSet has been issued, so the count is now final.
        __telephonyPending = false;
        __settleIfDone();
    }

    function __simFinished(message) {
        if (__simsPending > 0)
            __simsPending--;
        __settleIfDone();
    }

    function __settleIfDone() {
        if (inProgress || __settled)
            return;

        __settled = true;
        watchdog.stop();

        /*
         * Mirror the outcome into the systemservice preference. Nothing in the
         * shell reads it back - ConnMan is the source of truth - but it is the
         * key the settings apps and first-use are expected to look at.
         */
        systemService.call("luna://com.webos.service.systemservice/setPreferences",
                           JSON.stringify({"airplaneMode": __target}),
                           function (message) { },
                           function (message) {
                               console.log("AirplaneModeService: failed to store airplaneMode preference: " + message.payload);
                           });

        transitionFinished(__target);
    }

    NetworkManager {
        id: networkManager
    }

    /*
     * ConnMan applies offline mode asynchronously and a modem can take a while
     * to go offline. If either leg never answers, release the UI rather than
     * leaving the menu stuck on "Turning on Airplane Mode".
     */
    Timer {
        id: watchdog
        interval: 20000
        repeat: false

        onTriggered: {
            if (!airplaneModeService.inProgress)
                return;

            console.log("AirplaneModeService: timed out waiting for the radios to settle");
            __connmanPending = false;
            __telephonyPending = false;
            __simsPending = 0;
            __settleIfDone();
        }
    }

    LunaService {
        id: connectionManager
        name: "com.webos.surfacemanager-cardshell"
    }

    LunaService {
        id: telephony
        name: "com.webos.surfacemanager-cardshell"
    }

    LunaService {
        id: systemService
        name: "com.webos.surfacemanager-cardshell"
    }
}

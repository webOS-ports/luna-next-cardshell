/*
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

/*
 * Hardware privacy switches, as the killswitch service reports them.
 *
 * Deliberately a list rather than a fixed set of properties: the devices that
 * have these do not agree on which ones exist. The FuriPhone FLX1s has three
 * (camera, cellular, microphone), while the PinePhone and PinePhone Pro carry
 * six DIP switches - front camera, rear camera, WiFi/BT, modem, microphone and
 * headphone. A machine contributes whatever it has and the UI follows.
 *
 * Each entry is { id, state, label }, where state is one of:
 *
 *   "blocked"  the switch is engaged, the hardware is off
 *   "open"     the switch is disengaged, the hardware is available
 *   "unknown"  there is a switch but its position cannot be read
 *
 * "unknown" is not a failure and must not be drawn as either of the others.
 * Some of these switches physically cut the line with no presence detection at
 * all - the FLX1s microphone switch drops the analogue level by 40 dB and
 * appears nowhere in sysfs, in the input layer or in any property. Reading it
 * would mean opening the microphone, which is the one thing the switch exists
 * to prevent, so the honest answer is that we do not know.
 */
Item {
    id: killSwitchService

    /* Every switch the service knows about, in its reported order. */
    property var switches: []

    /* Just those currently engaged - what the status bar draws. */
    property var blockedSwitches: []

    property bool serviceAvailable: false

    /* Emitted when a switch changes position, so the shell can flash an alert.
     * Not emitted for the first status after (re)connecting: that is the
     * current state, not a change the user just made. */
    signal switchChanged(string id, string state)

    property var _previousState: ({})
    property bool _hadFirstStatus: false

    function stateOf(id) {
        for (var i = 0; i < switches.length; i++)
            if (switches[i].id === id)
                return switches[i].state;
        return "unknown";
    }

    function isBlocked(id) {
        return stateOf(id) === "blocked";
    }

    LunaService {
        id: lunaService
        name: "com.webos.surfacemanager-cardshell"

        onInitialized: {
            lunaService.subscribe("luna://com.palm.bus/signal/registerServerStatus",
                                  JSON.stringify({"serviceName": "org.webosports.service.killswitch"}),
                                  handleServiceStatus, handleError);
        }
    }

    function handleServiceStatus(message) {
        var response = JSON.parse(message.payload);
        killSwitchService.serviceAvailable = response.connected === true;

        if (!killSwitchService.serviceAvailable) {
            /* Do not keep drawing stale indicators for a service that went
             * away - we no longer know anything about the hardware. */
            killSwitchService.switches = [];
            killSwitchService.blockedSwitches = [];
            killSwitchService._hadFirstStatus = false;
            killSwitchService._previousState = ({});
            return;
        }

        lunaService.subscribe("luna://org.webosports.service.killswitch/getStatus",
                              JSON.stringify({"subscribe": true}),
                              handleStatus, handleError);
    }

    function handleStatus(message) {
        var payload = JSON.parse(message.payload);
        if (!payload.hasOwnProperty("switches"))
            return;

        var list = payload.switches;
        var blocked = [];
        var current = ({});

        for (var i = 0; i < list.length; i++) {
            var entry = list[i];
            current[entry.id] = entry.state;
            if (entry.state === "blocked")
                blocked.push(entry);
        }

        killSwitchService.switches = list;
        killSwitchService.blockedSwitches = blocked;

        if (!killSwitchService._hadFirstStatus) {
            killSwitchService._hadFirstStatus = true;
            killSwitchService._previousState = current;
            return;
        }

        for (var id in current) {
            if (killSwitchService._previousState[id] !== current[id])
                killSwitchService.switchChanged(id, current[id]);
        }
        killSwitchService._previousState = current;
    }

    function handleError(message) {
        console.log("KillSwitchService: " + message.payload);
    }
}

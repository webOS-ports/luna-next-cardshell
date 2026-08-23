/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
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

Item {
    id: telephonyService

    // ---------------------------------------------------------------
    // State of the SIM that currently serves voice. These are the
    // properties the shell used before dual SIM support existed and
    // they keep meaning exactly the same thing for a single SIM device.
    // ---------------------------------------------------------------
    property bool powered: false
    property bool connected: false
    property string registration: "noservice"
    property int bars: 0
    property int rssi: 0

    // ---------------------------------------------------------------
    // Multi SIM state
    //
    // The slot list and everything that only makes sense against it lives in
    // MultiSimModel; this connector just keeps it fed and offers the calls
    // that change telephonyd state.
    // ---------------------------------------------------------------
    property alias sims: simsModel

    MultiSimModel {
        id: simsModel
    }

    ServiceStatus {
        serviceName: "com.palm.telephony"
        onConnected: {
            console.log("TelephonyService: service connected");
            subscribeTelephonyService();
        }
        onDisconnected: {
            console.log("TelephonyService: service disconnected");
            resetState();
        }
    }

    function subscribeTelephonyService() {
        // simListQuery carries the per slot state for every SIM and is
        // re-posted by telephonyd on every relevant change, so it is the only
        // subscription needed to keep the model up to date.
        simListQuery.subscribe(JSON.stringify({"subscribe": true}));

        // The legacy subscriptions have no simId, which telephonyd routes to
        // whichever SIM is the current voice default. Keeping them means the
        // aggregate properties above stay correct even on a single SIM device
        // where simListQuery may never report anything interesting.
        powerQuery.subscribe(JSON.stringify({"subscribe": true}));
        networkStatusQuery.subscribe(JSON.stringify({"subscribe": true}));
        signalStrengthQuery.subscribe(JSON.stringify({"subscribe": true}));
    }

    function resetState() {
        telephonyService.powered = false;
        telephonyService.connected = false;
        telephonyService.registration = "noservice";
        telephonyService.bars = 0;
        telephonyService.rssi = 0;
        simsModel.reset();
    }

    function handleCallError(errorMessage) {
        console.log("ERROR: com.palm.telephony call failed: " + errorMessage);
    }

    // role is one of "voice", "sms", "data"
    function setDefaultSim(role, simId) {
        var request = {};
        request[role] = simId;
        telephonyCall.call("luna://com.palm.telephony/defaultSimSet",
                           JSON.stringify(request), null, handleCallError);
    }

    function setSimName(simId, name) {
        telephonyCall.call("luna://com.palm.telephony/simNameSet",
                           JSON.stringify({"simId": simId, "name": name}), null, handleCallError);
    }

    // Turn the radio of a single slot on or off.
    function setSimPower(simId, on) {
        telephonyCall.call("luna://com.palm.telephony/powerSet",
                           JSON.stringify({"simId": simId, "state": on ? "on" : "off", "save": true}),
                           null, handleCallError);
    }

    LunaService {
        id: telephonyCall
        name: "com.webos.surfacemanager-cardshell"
    }

    LunaService {
        id: simListQuery
        name: "com.webos.surfacemanager-cardshell"
        service: "luna://com.palm.telephony"
        method: "simListQuery"

        onResponse: function (message) {
            var response = JSON.parse(message.payload);

            if (!response.returnValue)
                return;

            simsModel.update(response);
        }

        onError: function (errorMessage) {
            console.log("ERROR: could not subscribe with com.palm.telephony/simListQuery: " + errorMessage);
        }
    }

    LunaService {
        id: powerQuery
        name: "com.webos.surfacemanager-cardshell"
        service: "luna://com.palm.telephony"
        method: "powerQuery"

        onResponse: function (message) {
            var response = JSON.parse(message.payload);

            if (!response.returnValue) {
                telephonyService.powered = false;
                return;
            }

            if (response.extended.powerState)
                telephonyService.powered = (response.extended.powerState === "on");
        }

        onError: function (errorMessage) {
            console.log("ERROR: could not subscribe with com.palm.telephony/powerQuery: " + errorMessage);
        }
    }

    LunaService {
        id: networkStatusQuery
        name: "com.webos.surfacemanager-cardshell"
        service: "luna://com.palm.telephony"
        method: "networkStatusQuery"

        onResponse: function (message) {
            var response = JSON.parse(message.payload);

            if (!response.returnValue) {
                telephonyService.registration = "noservice";
                telephonyService.connected = false;
                return;
            }

            if (response.extended.state)
                telephonyService.connected = (response.extended.state === "service");

            if (response.extended.registration)
                telephonyService.registration = response.extended.registration;
        }

        onError: function (errorMessage) {
            console.log("ERROR: could not subscribe with com.palm.telephony/networkStatusQuery: " + errorMessage);
        }
    }

    LunaService {
        id: signalStrengthQuery
        name: "com.webos.surfacemanager-cardshell"
        service: "luna://com.palm.telephony"
        method: "signalStrengthQuery"

        onResponse: function (message) {
            var response = JSON.parse(message.payload);

            if (!response.returnValue) {
                telephonyService.bars = 0;
                telephonyService.rssi = 0;
                return;
            }

            if (response.extended.bars)
                telephonyService.bars = response.extended.bars;
            if (response.extended.rssi)
                telephonyService.rssi = response.extended.rssi;
        }

        onError: function (errorMessage) {
            console.log("ERROR: could not subscribe with com.palm.telephony/signalStrengthQuery: " + errorMessage);
        }
    }
}

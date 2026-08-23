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
import QOfono 0.2
import Connman 0.2

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
    // ---------------------------------------------------------------

    // one entry per SIM slot, see updateSimList() for the fields
    property alias sims: simsModel
    property int simCount: 0
    property int defaultVoiceSim: -1
    property int defaultSmsSim: -1
    property int defaultDataSim: -1

    // true once the device actually reports more than one slot; the UI uses
    // this to decide whether to show any SIM specific chrome at all
    readonly property bool multiSim: simCount > 1

    signal simListChanged()

    ListModel {
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
        simsModel.clear();
        telephonyService.simCount = 0;
        telephonyService.defaultVoiceSim = -1;
        telephonyService.defaultSmsSim = -1;
        telephonyService.defaultDataSim = -1;
        simListChanged();
    }

    // Look up the row index of a slot; -1 when the slot is not in the model.
    function indexOfSim(simId) {
        for (let i = 0; i < simsModel.count; i++) {
            if (simsModel.get(i).simId === simId)
                return i;
        }
        return -1;
    }

    function simAt(simId) {
        var index = indexOfSim(simId);
        return index >= 0 ? simsModel.get(index) : null;
    }

    // Human readable label for a slot, e.g. "Work" or the operator name.
    function labelForSim(simId) {
        var sim = simAt(simId);
        if (!sim)
            return "";
        if (sim.operatorName && sim.operatorName.length > 0 && sim.name.indexOf("SIM ") === 0)
            return sim.operatorName;
        return sim.name;
    }

    function updateSimList(response) {
        var sims = response.sims || [];

        // Rewrite in place rather than clear()+append() so that delegates
        // bound to a row are not torn down and rebuilt on every update.
        for (let i = 0; i < sims.length; i++) {
            let s = sims[i];
            let entry = {
                "simId": s.simId,
                "present": !!s.present,
                "name": s.name || ("SIM " + (s.simId + 1)),
                "iccid": s.iccid || "",
                "imsi": s.imsi || "",
                "msisdn": s.msisdn || "",
                "operatorName": s.operatorName || "",
                "simStatus": s.simStatus || "simnotfound",
                "powered": !!s.powered,
                "ready": !!s.ready,
                "bars": s.bars || 0,
                "state": s.state || "noservice",
                "registration": s.registration || "noservice",
                "networkRegistered": !!s.networkRegistered,
                "dataRegistered": !!s.dataRegistered,
                "defaultForVoice": !!s.defaultForVoice,
                "defaultForSms": !!s.defaultForSms,
                "defaultForData": !!s.defaultForData
            };

            if (i < simsModel.count)
                simsModel.set(i, entry);
            else
                simsModel.append(entry);
        }

        while (simsModel.count > sims.length)
            simsModel.remove(simsModel.count - 1);

        telephonyService.simCount = response.simCount !== undefined ? response.simCount : sims.length;

        if (response.defaultSim) {
            telephonyService.defaultVoiceSim = response.defaultSim.voice;
            telephonyService.defaultSmsSim = response.defaultSim.sms;
            telephonyService.defaultDataSim = response.defaultSim.data;
        }

        simListChanged();
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

            telephonyService.updateSimList(response);
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

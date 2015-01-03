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
import LunaNext.Common 0.1
import MeeGo.QOfono 0.2
import Connman 0.2

Item {
    id: telephonyService

    property bool powered: false
    property bool connected: false
    property string registration: "noservice"
    property int bars: 0
    property int rssi: 0

    Timer {
        id: resubscribeTimer
        interval: 500
        repeat: false
        running: false
        onTriggered: {
            probeTelephonyService();
        }
    }

    ServiceStatus {
        serviceName: "com.palm.telephony"
        onConnected: {
            console.log("TelephonyService: service connected");
            probeTelephonyService();
        }
        onDisconnected: {
            console.log("TelephonyService: service disconnected");
        }
    }

    function handleTelephonyServiceProbeResponse(message) {
        var response = JSON.parse(message.payload);

        if (!response.returnValue &&
             response.errorText === "Backend not initialized") {
            resubscribeTimer.start();
            return;
        }

        subscribeTelephonyService();
    }

    function probeTelephonyService() {
        powerQuery.call(JSON.stringify({}), handleTelephonyServiceProbeResponse, function (errorMessage) { });
    }

    function subscribeTelephonyService() {
        powerQuery.subscribe(JSON.stringify({"subscribe":true}));
        networkStatusQuery.subscribe(JSON.stringify({"subscribe":true}));
        signalStrengthQuery.subscribe(JSON.stringify({"subscribe":true}));
    }

    LunaService {
        id: powerQuery
        name: "org.webosports.luna"
        usePrivateBus: true
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
        name: "org.webosports.luna"
        usePrivateBus: true
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
        name: "org.webosports.luna"
        usePrivateBus: true
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

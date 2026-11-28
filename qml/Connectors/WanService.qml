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
import LuneOS.System 1.0
import LunaNext.Common 0.1

Item {
    id: wanService

    // Packet data is attached to the network, i.e. a bearer is up.
    property bool powered: false
    // The cellular technology is enabled in the connection manager.
    property bool online: false
    // Cellular is carrying the internet connection right now.
    property bool connected: false
    // Radio access technology telephonyd reports for the data SIM. This is
    // ofono's NetworkRegistration.Technology whenever no bearer is up, so it
    // is set as soon as the modem registers - it does not wait for a data
    // connection, which is what makes it usable as a status bar indicator.
    // One of: none, gprs, edge, umts, hsdpa, lte, 1x, evdo.
    property string technology: "none"
    // A cellular connection carries the internet: com.palm.wan reports the
    // network attached, data access usable, and an "internet" context active
    // (or dormant, on CDMA). The same test webOS 2.2.4's luna-systemui
    // (bar-assistant.js) and 3.0's LunaSysMgr (StatusBarServicesConnector)
    // put their network type icon behind.
    property bool internetConnected: false
    // Wi-Fi is connected and on the internet
    property bool wifiOnInternet: false
    // What the status bar shows the radio access technology for: a cellular
    // internet connection, and not while Wi-Fi carries the internet - with
    // mobile data off there is no network type to show, as on legacy webOS.
    readonly property bool showTechnology: internetConnected && !wifiOnInternet &&
                                           technology !== "none"
    // Data roaming is blocked. telephonyd words this the other way round
    // ("roamguard" enabled means roaming is guarded against), and so does the
    // menu entry that drives it.
    property bool roamGuard: true
    // com.palm.wan/set refuses with WAN_ERROR_NOT_AVAILABLE while telephonyd
    // has no data context to configure, so a write is not guaranteed to stick.
    // Nothing here is updated optimistically: the subscription below is the
    // only thing that moves roamGuard, so the menu never shows a value the
    // modem did not take.
    signal roamGuardSetFailed()

    // com.palm.wan/getstatus: is an internet context up on cellular
    function cellularInternet(status) {
        if (status.networkstatus !== "attached" || status.dataaccess !== "usable")
            return false;
        var services = status.connectedservices || [];
        for (var i = 0; i < services.length; i++) {
            if ((services[i].service || []).indexOf("internet") < 0)
                continue;
            return services[i].connectstatus === "active" ||
                   services[i].connectstatus === "dormant";
        }
        return false;
    }

    function setRoamGuard(enabled) {
        setWanConfig.call("luna://com.palm.wan/set",
                          JSON.stringify({"roamguard": enabled ? "enable" : "disable"}),
                          function (message) {
                              var response = JSON.parse(message.payload);
                              if (!response.returnValue)
                                  wanService.roamGuardSetFailed();
                          },
                          function (errorMessage) {
                              console.log("ERROR: com.palm.wan/set failed: " + errorMessage);
                              wanService.roamGuardSetFailed();
                          });
    }

    ServiceStatus {
        serviceName: "com.palm.connectionmanager"
        clientName: "com.webos.surfacemanager.cardshell"

        onAvailableChanged: available ? connected() : disconnected()

        function connected() {
            getConnMgrWanStatus.subscribe(JSON.stringify({"subscribe":true}));
        }

        function disconnected() {
            wanService.online = false;
            wanService.connected = false;
            wanService.wifiOnInternet = false;
        }
    }

    LunaService {
        id: getConnMgrWanStatus
        name: "com.webos.surfacemanager.cardshell"
        service: "luna://com.palm.connectionmanager"
        method: "getStatus"

        onResponse: function (message) {
            var response = JSON.parse(message.payload);

            if (!response.returnValue) {
                wanService.online = false;
                wanService.connected = false;
                wanService.wifiOnInternet = false;
                return;
            }

            // Both sections are optional: a build without cellular support
            // leaves them out entirely rather than reporting them disabled.
            wanService.online = !!(response.cellular && response.cellular.enabled);
            wanService.connected = !!(response.wan && response.wan.onInternet);
            wanService.wifiOnInternet = !!(response.wifi && response.wifi.state === "connected" &&
                                           response.wifi.onInternet === "yes");
        }

        onError: function (errorMessage) {
            console.log("ERROR: could not subscribe with com.palm.connectionmanager/getStatus: " + errorMessage);
        }
    }

    ServiceStatus {
        serviceName: "com.palm.wan"
        clientName: "com.webos.surfacemanager.cardshell"

        onAvailableChanged: available ? connected() : disconnected()

        function connected() {
            getWanStatus.subscribe(JSON.stringify({"subscribe":true}));
        }

        function disconnected() {
            wanService.powered = false;
            wanService.technology = "none";
            wanService.internetConnected = false;
        }
    }

    LunaService {
        id: setWanConfig
        name: "com.webos.surfacemanager.cardshell"
    }

    LunaService {
        id: getWanStatus
        name: "com.webos.surfacemanager.cardshell"
        service: "luna://com.palm.wan"
        method: "getstatus"

        onResponse: function (message) {
            var response = JSON.parse(message.payload);

            if (!response.returnValue) {
                wanService.powered = false;
                wanService.technology = "none";
                wanService.internetConnected = false;
                return;
            }

            // The first reply to a subscribe only acknowledges it; the status
            // itself arrives in the messages after it.
            if (response.networkstatus) {
                wanService.powered = (response.networkstatus === "attached");
                wanService.internetConnected = wanService.cellularInternet(response);
            }

            if (response.networktype)
                wanService.technology = response.networktype;

            if (response.roamguard)
                wanService.roamGuard = (response.roamguard === "enable");
        }

        onError: function (errorMessage) {
            console.log("ERROR: could not subscribe with com.palm.wan/getstatus: " + errorMessage);
        }
    }
}

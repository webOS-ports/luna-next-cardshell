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
        onConnected: {
            getConnMgrWanStatus.subscribe(JSON.stringify({"subscribe":true}));
        }
        onDisconnected: {
            wanService.online = false;
            wanService.connected = false;
        }
    }

    LunaService {
        id: getConnMgrWanStatus
        name: "com.webos.surfacemanager-cardshell"
        service: "luna://com.palm.connectionmanager"
        method: "getStatus"

        onResponse: function (message) {
            var response = JSON.parse(message.payload);

            if (!response.returnValue) {
                wanService.online = false;
                wanService.connected = false;
                return;
            }

            // Both sections are optional: a build without cellular support
            // leaves them out entirely rather than reporting them disabled.
            wanService.online = !!(response.cellular && response.cellular.enabled);
            wanService.connected = !!(response.wan && response.wan.onInternet);
        }

        onError: function (errorMessage) {
            console.log("ERROR: could not subscribe with com.palm.connectionmanager/getStatus: " + errorMessage);
        }
    }

    ServiceStatus {
        serviceName: "com.palm.wan"
        onConnected: {
            getWanStatus.subscribe(JSON.stringify({"subscribe":true}));
        }
        onDisconnected: {
            wanService.powered = false;
            wanService.technology = "none";
        }
    }

    LunaService {
        id: setWanConfig
        name: "com.webos.surfacemanager-cardshell"
    }

    LunaService {
        id: getWanStatus
        name: "com.webos.surfacemanager-cardshell"
        service: "luna://com.palm.wan"
        method: "getstatus"

        onResponse: function (message) {
            var response = JSON.parse(message.payload);

            if (!response.returnValue) {
                wanService.powered = false;
                wanService.technology = "none";
                return;
            }

            // The first reply to a subscribe only acknowledges it; the status
            // itself arrives in the messages after it.
            if (response.networkstatus)
                wanService.powered = (response.networkstatus === "attached");

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

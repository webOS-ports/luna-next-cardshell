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
    id: wanService

    property bool powered: false
    property bool online: false
    property bool connected: false
    property string technology: "none"

    ServiceStatus {
        serviceName: "com.palm.connectionmanager"
        onConnected: {
            getConnMgrWanStatus.subscribe(JSON.stringify({"subscribe":true}));
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

            if (response.cellular.onInternet)
                wanService.online = (response.cellular.onInternet === "yes");

            if (response.cellular.state)
                wanService.connected = (response.cellular.state === "connected");
        }
    }

    ServiceStatus {
        serviceName: "com.palm.wan"
        onConnected: {
            getWanStatus.subscribe(JSON.stringify({"subscribe":true}));
        }
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

            if (response.networkstatus)
                wanService.powered = (response.networkstatus === "attached");

            if (response.networktype)
                wanService.technology = response.networktype;
        }
    }
}

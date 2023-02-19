/*
 * Copyright (C) 2014 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2015 Herman van Hazendonk <github.com@herrie.org>
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
    id: serviceStatus

    property string serviceName: ""

    signal connected
    signal disconnected

    LunaService {
        id: registerServerStatus
        name: "com.webos.surfacemanager-cardshell"
        usePrivateBus: true
        service: "luna://com.palm.bus"
        method: "signal/registerServerStatus"

        onInitialized: {
            console.log("RegisterServerStatus");
            registerServerStatus.subscribe(JSON.stringify({"serviceName": serviceStatus.serviceName}));
        }

        onResponse: function (message) {
            var response = JSON.parse(message.payload);

            console.log("ServerStatus: " + message.payload);

            if (response.connected)
                connected();
            else
                disconnected();
        }
    }
}

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
import LuneOS.System 1.0

/*
 * The flashlight, as torchd reports it.
 *
 * torchd is not on every device and can start after the shell, so the
 * subscription is made whenever it appears on the bus. It posts on every
 * change, and the torch can go off without us asking: it does when the service
 * stops. So on stays what torchd last said, never what we asked for, and
 * "available" is false until torchd says otherwise. A device with no torch
 * shows no control rather than one that does nothing.
 */
Item {
    id: torchService

    property bool available: false
    property bool on: false

    //! The bus, a property so a test can stand in for it.
    property var bus: lunaService

    function toggle() {
        if (!torchService.available)
            return;
        torchService.bus.call("luna://org.webosports.service.torch/toggle", "{}",
                              function(message) { }, handleError);
    }

    LunaService {
        id: lunaService
        name: "com.webos.surfacemanager-cardshell"
    }

    ServiceStatus {
        id: torchStatus
        serviceName: "org.webosports.service.torch"
        clientName: "com.webos.surfacemanager-cardshell"
        onAvailableChanged: torchService.handleServiceStatus()
    }

    function handleServiceStatus() {
        if (!torchStatus.available) {
            torchService.available = false;
            torchService.on = false;
            return;
        }

        torchService.bus.subscribe("luna://org.webosports.service.torch/getStatus",
                                   JSON.stringify({"subscribe": true}),
                                   handleStatus, handleError);
    }

    function handleStatus(message) {
        var payload = JSON.parse(message.payload);
        if (payload.hasOwnProperty("available"))
            torchService.available = payload.available === true;
        if (payload.hasOwnProperty("on"))
            torchService.on = payload.on === true;
    }

    function handleError(message) {
        console.log("TorchService: " + message.payload);
    }
}

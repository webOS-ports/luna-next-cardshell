/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
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
import Connman 0.2

Item {
    id: btService

    property bool powered: bluetoothTech.powered
    property bool connected: bluetoothTech.connected
    property bool online: false
    property string connectionStatus: "off"

    property QtObject __currentService: null

    function updateFromCurrentService() {
        if (__currentService == null) {
            btService.connectionStatus = "off";
            btService.online = false;
            return;
        }

        btService.connectionStatus = "connected";
        btService.online = (__currentService.state === "online");
    }

    TechnologyModel {
        id: bluetoothTech
        name: "bluetooth"

        function updateCurrentService() {
            __currentService = null;

            if (!bluetoothTech.powered || !bluetoothTech.connected) {
                updateFromCurrentService();
                return;
            }

            for (var n = 0; n < bluetoothTech.count; n++) {
                var service = bluetoothTech.get(n);
                if (service.state === "ready" || service.state === "online") {
                    /* we can only have one connected bt service at the same time */
                    __currentService = service;

                    updateFromCurrentService();
                    //__currentService.strengthChanged.connect(updateFromCurrentService);
                    __currentService.stateChanged.connect(updateFromCurrentService);
                    break;
                }
            }
        }

        onPoweredChanged: updateCurrentService()
        onScanningChanged: updateCurrentService()
        onConnectedChanged: updateCurrentService()
    }
}

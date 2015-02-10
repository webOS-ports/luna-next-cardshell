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
import Connman 0.2

Item {
    id: wifiService

    property bool powered: wifiModel.powered
    property bool connected: wifiModel.connected
    property bool online: false
    property int signalBars: 0

    property QtObject __currentService: null

    function convertStrengthToBars(strength) {
        if (strength > 0 && strength < 34)
            return 1;
        else if (strength >= 34 && strength < 50)
            return 2;
        else if (strength >= 50)
            return 3;
        return 0;
    }

    function updateFromCurrentService() {
        if (__currentService == null) {
            wifiService.signalBars = 0;
            wifiService.online = false;
            return;
        }

        wifiService.signalBars = convertStrengthToBars(__currentService.strength);
        wifiService.online = (__currentService.state === "online");
    }

    TechnologyModel {
        id: wifiModel
        name: "wifi"

        function updateCurrentService() {
            __currentService = null;

            if (!wifiModel.powered || !wifiModel.connected) {
                updateFromCurrentService();
                return;
            }

            for (var n = 0; n < wifiModel.count; n++) {
                var service = wifiModel.get(n);
                if (service.state === "ready" || service.state === "online") {
                    /* we can only have one connected wifi service at the same time */
                    __currentService = service;

                    updateFromCurrentService();
                    __currentService.strengthChanged.connect(updateFromCurrentService);
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

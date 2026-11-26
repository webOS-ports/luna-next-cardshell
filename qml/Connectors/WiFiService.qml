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
import QtQml 2.2
import LuneOS.Service 1.0
import LunaNext.Common 0.1
import Connman 0.2

import "WifiSignal.js" as WifiSignal

Item {
    id: wifiService

    property bool powered: wifiModel.powered
    property bool connected: wifiModel.connected
    readonly property bool online: __currentService !== null && __currentService.state === "online"
    readonly property int signalBars: __currentService !== null ? WifiSignal.bars(__currentService.strength) : 0

    property QtObject __currentService: null

    /*
     * The connected network is whichever service is ready or online; there is
     * only ever one for wifi. This is looked up again whenever the list or a
     * service's state changes, not only when the technology's Connected does:
     * libconnman-qt emits connectedChanged before it has filled in the service
     * list, so with wifi already up when the shell starts the list was still
     * empty at that point, nothing ever looked again, and the indicator sat at
     * no bars while the system menu showed the network's real strength.
     */
    function updateCurrentService() {
        var found = null;

        if (wifiModel.powered) {
            for (var n = 0; n < wifiModel.count; n++) {
                var service = wifiModel.get(n);
                if (service && (service.state === "ready" || service.state === "online")) {
                    found = service;
                    break;
                }
            }
        }

        __currentService = found;
    }

    TechnologyModel {
        id: wifiModel
        name: "wifi"

        onPoweredChanged: wifiService.updateCurrentService()
        onConnectedChanged: wifiService.updateCurrentService()
        onCountChanged: wifiService.updateCurrentService()
        onRowsMoved: wifiService.updateCurrentService()
        onModelReset: wifiService.updateCurrentService()
    }

    // A service going ready or dropping back to idle without the list changing.
    Instantiator {
        model: wifiModel
        delegate: Connections {
            target: wifiModel.get(index) || null
            function onStateChanged() { wifiService.updateCurrentService(); }
        }
        onObjectAdded: wifiService.updateCurrentService()
        onObjectRemoved: wifiService.updateCurrentService()
    }

    Component.onCompleted: updateCurrentService()
}

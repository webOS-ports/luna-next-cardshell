/*
 * Copyright (C) 2015 Simon Busch <morphis@gravedo.de>
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
    id: dockMode

    property bool dockModeActive: false
    property Item windowManagerInstance

    visible: dockModeActive

    onDockModeActiveChanged: {
        console.log("DockMode changed to " + dockModeActive);
        if (dockModeActive) {
            clocksLoader.sourceComponent = clocksComponent;
            windowManagerInstance.addTapAction("deactivateDockMode", function() { dockMode.dockModeActive = false; }, null)
        }
        else {
            clocksLoader.sourceComponent = null;
        }
    }

    LunaService {
        id: service
        name: "org.webosports.luna"
        usePrivateBus: true
        onInitialized: {
            service.subscribe("luna://com.palm.display/control/lockStatus", "{\"subscribe\":true}", handleLockStatus, handleError);
        }

        function handleLockStatus(message) {
            console.log("DockMode: Got lock status " + message.payload);
            var response = JSON.parse(message.payload);

            windowManagerInstance.removeTapAction("deactivateDockMode"); // if any was registered, remove it
            dockModeActive = (response.lockState === "dockmode");
        }

        function handleError(message) {
            console.log("Service error: " + message);
        }
    }

    Loader {
        id: clocksLoader

        width: parent.width;
        height: parent.height;
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
    }

    Component {
        id: clocksComponent

        Clocks {
            id: clocks
            mainTimerRunning: dockModeActive
        }
    }
}


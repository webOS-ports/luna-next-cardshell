/*
 * Copyright (C) 2014 Simon Busch <morphis@gravedo.de>
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
    id: lockScreen

    visible: locked && !isFirstUse

    property bool isFirstUse: false
    property bool locked: false;

    property bool needKeyboard: pinPasswordLock.visible && deviceLockMode === "password"

    property string deviceLockMode: "none"

    function lockDisplay() {
        service.call("luna://com.palm.display/control/setLockStatus", "{\"status\":\"lock\"}", null, null);
    }

    function unlockDisplay() {
        service.call("luna://com.palm.display/control/setLockStatus", "{\"status\":\"unlock\"}", null, null);
    }

    function padUnlock() {
        // if we don't have a lock mode set directly unlock the display
        if (deviceLockMode === "none")
            unlockDisplay()
        else if (deviceLockMode === "pin" || deviceLockMode === "password")
            lockScreen.state = "pin-password";
        else {
            console.log("Invalid device lock mode '" + deviceLockMode + "'");
            lockDisplay();
        }
    }

    LunaService {
        id: service
        name: "org.webosports.luna"
        usePrivateBus: true
        onInitialized: {
            service.subscribe("luna://com.palm.systemmanager/getDeviceLockMode", "{\"subscribe\":true}", handleDeviceLockMode, handleError);
            service.subscribe("luna://com.palm.display/control/lockStatus", "{\"subscribe\":true}", handleLockStatus, handleError);
        }

        function handleLockStatus(message) {
            console.log("Got lock status " + message.payload);
            var response = JSON.parse(message.payload);

            if (response.lockState === "locked")
                lockScreen.state = "pad";
            else if (response.lockState === "unlocked")
                lockScreen.state = "none";
        }

        function handleDeviceLockMode(message) {
            console.log("Got device lock mode " + message.payload);

            var response = JSON.parse(message.payload);
            lockScreen.deviceLockMode = response.lockMode;
        }

        function handleError(message) {
            console.log("Service error: " + message);
        }
    }

    state: "none"
    states: [
        State {
            name: "none"
            PropertyChanges { target: lockScreen; locked: false }
        },
        State {
            name: "pad"
            PropertyChanges { target: lockScreen; locked: true }
        },
        State {
            name: "pin-password"
            PropertyChanges { target: lockScreen; locked: true }
        }
    ]

    PadLock {
        id: padLock

        visible: lockScreen.state === "pad"

        onUnlock: padUnlock()
    }

    PinPasswordLock {
        id: pinPasswordLock

        isPINEntry: deviceLockMode == "pin"

        visible: lockScreen.state === "pin-password"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: (Qt.inputMethod.keyboardRectangle.height/8)*-1

        onUnlock: unlockDisplay()
        onCanceled: {
            lockScreen.state = "pad";
        }
    }
}

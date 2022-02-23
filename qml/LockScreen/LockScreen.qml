/*
 * Copyright (C) 2014 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2016 Herman van Hazendonk <github.com@herrie.org>
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

import QtQuick 2.5
import LuneOS.Service 1.0
import LunaNext.Common 0.1

Item {
    id: lockScreen

    visible: locked

    property Item windowManagerInstance;

    property bool isFirstUse: false
    property bool locked: false;

    property bool needKeyboard: pinPasswordLock.visible && deviceLockMode === "password"

    property string deviceLockMode: "none"

    onLockedChanged: {
        if(!locked) {
            if( _stateBeforeLock === "dockmode" ) windowManagerInstance.switchToDockMode();
            else if( _stateBeforeLock === "minimize" ) windowManagerInstance.switchToMaximize(null);
            else if( _stateBeforeLock === "fullscreen" ) windowManagerInstance.switchToFullscreen(null);
            else if( _stateBeforeLock === "cardview" ) windowManagerInstance.switchToCardView();
            else if( _stateBeforeLock === "launcherview" ) windowManagerInstance.switchToLauncherView();
        }
        else {
            windowManagerInstance.switchToLockscreen();
        }
    }
    property string _stateBeforeLock: "cardview"
    Connections {
        target: windowManagerInstance
        function onSwitchToDockMode() {
            _stateBeforeLock = "dockmode";
        }
        function onSwitchToMaximize(window) {
            _stateBeforeLock = "minimize";
        }
        function onSwitchToFullscreen(window) {
            _stateBeforeLock = "fullscreen";
        }
        function onSwitchToCardView() {
            _stateBeforeLock = "cardview";
        }
        function onSwitchToLauncherView() {
            _stateBeforeLock = "launcherview";
        }
    }

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

    Clock
    {
        id: lockScreenClock
    }


    Image {
        anchors.top: parent.top
        source: "../images/lockscreen/screen-lock-wallpaper-mask-top.png"
        width: parent.width
        height: Units.gu(11.7)
        mipmap: true
        fillMode: Image.TileHorizontally
    }

    Image {
        anchors.bottom: parent.bottom
        source: "../images/lockscreen/screen-lock-wallpaper-mask-bottom.png"
        width: parent.width
        height: Units.gu(25)
        mipmap: true
        fillMode: Image.TileHorizontally
    }


    LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"
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
            else if (response.lockState === "unlocked" || response.lockState === "dockmode")
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
        anchors.verticalCenterOffset: (Qt.inputMethod.keyboardRectangle.height/2)*-1

        onUnlock: unlockDisplay()
        onCanceled: {
            lockScreen.state = "pad";
        }
    }
}

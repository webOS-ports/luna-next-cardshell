/* @@@LICENSE
*
*      Copyright (c) 2009-2013 LG Electronics, Inc.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* LICENSE@@@ */

import QtQuick 2.0
import LunaNext.Common 0.1
import LunaNext.Shell 0.1
import "../../Connectors"

Item {
    id: systemMenu
    property int  maxHeight: Units.gu(40)
    property int  headerIdent: Units.gu (1.4) 
    property int  subItemIdent: Units.gu (1.6) 
    property int  dividerWidthOffset: Units.gu(0.7)
    property int  itemIdent:     subItemIdent + headerIdent
    property int  edgeOffset: Units.gu(1.1) 
    property bool flickableOverride: false

    property bool airplaneModeInProgress: false

    width: Units.gu(40)
    height: maxHeight
    state: "hidden"

    function isVisible() {
        return state === "visible";
    }

    function toggleState() {
        if (state === "hidden")
            state = "visible";
        else if (state === "visible")
            state = "hidden";
    }

    // ------------------------------------------------------------
    // External interface to the System Menu is defined here:


    // ---- Signals ----
    signal showPowerMenu()
    signal closeSystemMenu()
    signal airplaneModeTriggered()
    signal rotationLockTriggered(bool isLocked)
    signal muteToggleTriggered(bool isMuted)

    function setRotationLockText(newText, showLocked) {
        if(!rotation.delayUpdate) {
            rotation.modeText      = newText;
            rotation.locked        = showLocked;
        } else {
            rotation.newText       = newText;
            rotation.newLockStatus = showLocked;
        }
    }

    function setMuteControlText(newText, showMuteOn) {
        if(!muteControl.delayUpdate) {
            muteControl.muteText      = newText;
            muteControl.mute          = showMuteOn;
        } else {
            muteControl.newText       = newText;
            muteControl.newMuteStatus = showMuteOn;
        }
    }

    function setAirplaneModeStatus(newText, state) {
        airplane.modeText = newText;
        airplane.airplaneOn = ((state === 2) || (state === 3));
        airplaneModeInProgress = ((state === 1) || (state === 2));

        if(airplaneModeInProgress) {
            wifi.close();
            vpn.close();
            bluetooth.close();
        }
    }

    function updateChangedFields() {
        if(rotation.delayUpdate) {
            rotation.delayUpdate   = false;
            rotation.modeText      = rotation.newText;
            rotation.locked        = rotation.newLockStatus;
        }

        if(muteControl.delayUpdate) {
            muteControl.delayUpdate   = false;
            muteControl.muteText      = muteControl.newText;
            muteControl.mute          = muteControl.newMuteStatus;
        }
    }

    // ------------------------------------------------------------


    BorderImage {
        source: "../../images/menu-dropdown-bg.png"
        width: parent.width;
        height: Math.min(systemMenu.height,  (mainMenu.height + clipRect.anchors.topMargin + clipRect.anchors.bottomMargin));
        border { left: 30; top: 10; right: 30; bottom: 30 }
    }

    Rectangle { // clipping rect inside the menu border
        id: clipRect
        anchors.fill: parent
        color: "transparent"
        clip: true
        anchors.leftMargin: Units.gu(0.7) 
        anchors.topMargin: 0
        // need to be in pixels due to border
        anchors.bottomMargin: 14
        anchors.rightMargin: Units.gu(0.7) 

        Flickable {
            id: flickableArea
            width: mainMenu.width;
            height: Math.min(systemMenu.height - clipRect.anchors.topMargin - clipRect.anchors.bottomMargin, mainMenu.height);
            contentWidth: mainMenu.width; contentHeight: mainMenu.height;
            interactive: !flickableOverride

            NumberAnimation on contentItem.y {
                id: viewAnimation;
                duration: 200;
                easing.type: Easing.InOutQuad
            }


            Column {
                id: mainMenu
                spacing: 0
                width: clipRect.width

                DateElement {
                    id: date
                    menuPosition: 1; // top
                    ident: headerIdent;
                }

                MenuDivider {widthOffset: dividerWidthOffset}

                BatteryElement {
                    id: battery
                    ident: headerIdent;
                }

                MenuDivider {
                    widthOffset: dividerWidthOffset
                    visible: battery.visible
                }

                BrightnessElement {
                    id: brightness
                    visible: Settings.hasBrightnessControl
                    margin: Units.gu(0.5); 
                    onFlickOverride: {
                        flickableOverride = override;
                    }
                }

                MenuDivider {
                    visible: brightness.visible
                    widthOffset: dividerWidthOffset
                }

                VolumeElement {
                    id: volume
                    visible: !Settings.hasVolumeButton
                    margin: Units.gu(0.5);
                    onFlickOverride: {
                        flickableOverride = override;
                    }
                }

                MenuDivider {
                    visible: volume.visible
                    widthOffset: dividerWidthOffset
                }

                WiFiElement {
                    id: wifi
                    objectName: "wifiMenu"
                    visible: true
                    ident: headerIdent;
                    internalIdent: subItemIdent;
                    active: !airplaneModeInProgress;
                    maxViewHeight : maxHeight - clipRect.anchors.topMargin - clipRect.anchors.bottomMargin;

                    onPrefsTriggered: {
                        launcherInstance.launchApplication("org.webosports.app.settings",{"page":"WiFi"});
                    }

                    onItemSelected: {
                        var target = {};
                        target["ssid"] = name;
                        target["securityType"] = securityType;
                        target["connectState"] = connState;
                        if (securityType.length <= 0) {
                            wifi.joinWifi(name);
                        } else {
                            launcherInstance.launchApplication("org.webosports.app.settings",{"target":target});
                        }
                    }

                    onMenuCloseRequest: {
                        closeMenuTimer.interval = delayMs;
                        closeMenuTimer.start();
                    }

                    onRequestViewAdjustment: {
                        // this is not working correctly in QML right now.
                        viewAnimation.to = flickableArea.contentItem.y - offset;
                        viewAnimation.start();
                    }
                }

                MenuDivider {visible: wifi.visible; widthOffset: dividerWidthOffset}

                VpnElement {
                    id: vpn
                    objectName: "vpnMenu"
                    visible: false
                    ident:         headerIdent;
                    internalIdent: subItemIdent;
                    active: !airplaneModeInProgress;
                    maxViewHeight : maxHeight - clipRect.anchors.topMargin - clipRect.anchors.bottomMargin;

                    onMenuCloseRequest: {
                        closeMenuTimer.interval = delayMs;
                        closeMenuTimer.start();
                    }

                    onRequestViewAdjustment: {
                        // this is not working correctly in QML right now.
//                        viewAnimation.to = flickableArea.contentItem.y - offset;
//                        viewAnimation.start();
                    }
                }

                MenuDivider {visible: vpn.visible; widthOffset: dividerWidthOffset}

                BluetoothElement {
                    id: bluetooth
                    objectName: "bluetoothMenu"
                    visible: true
                    ident:         headerIdent;
                    internalIdent: subItemIdent;
                    active: !airplaneModeInProgress;
                    maxViewHeight : maxHeight - clipRect.anchors.topMargin - clipRect.anchors.bottomMargin;
                    property string pendingDevAddress: "";
                    property int pendingCod: 0;

                    Connections {
                        target: BluetoothService

                        onClearBtList: {
                            bluetooth.clearBluetoothList();
                        }

                        onAddBtEntry: {
                            bluetooth.addBluetoothEntry(name,address,cod,connStatus,connected);
                        }

                        onSetBtState:{
                            bluetooth.setBluetoothState(isOn, turningOn, state);
                        }

                        onUpdateBtEntry: {
                            if (!connected && BluetoothService.powered && bluetooth.pendingDevAddress !== "") {
                                BluetoothService.connectBtDevice(bluetooth.pendingDevAddress, bluetooth.pendingCod);
                                bluetooth.pendingDevAddress = "";
                                bluetooth.pendingCod = 0;
                            }

                            for (var x = 0; x < bluetooth.trustedDevices.count; x++) {
                                if(bluetooth.trustedDevices.get(x).deviceAddress === address) {
                                    var entry = bluetooth.trustedDevices.get(x);
                                    bluetooth.updateBluetoothEntry(entry.deviceName, entry.deviceAddress, entry.deviceCod, connStatus, connected);
                                }
                            }
                        }
                    }


                    onPrefsTriggered: {
                        //TODO needs page in Settings
                        launcherInstance.launchApplication("org.webosports.app.settings",{"page":"Bluetooth"});
                    }

                    onOnOffTriggered: {
                        if (isBluetoothOn) {
                            BluetoothService.setPowered(false);
                        }
                        else {
                            if (!btTurningOn)
                                BluetoothService.setPowered(true);
                        }
                    }

                    onItemSelected: {
                        var item = trustedDevices.get(index);
                        var x = 0;
                        var entry;

                        if (item.connectionStatus === "connected") {
                            // Device is connected so disconnect all profiles it is connected on
                            BluetoothService.disconnectAllBtMenuProfiles(item.deviceAddress);
                        } else if (item.connectionStatus === "connecting") {
                            // Is this device waiting to connect?
                            if (item.deviceAddress === pendingDevAddress) {
                                // There is no longer a pending connection attempt to this device
                                pendingDevAddress = "";
                                pendingCod = 0;
                            }
                            else {
                                // Abort the connection attempt on the supported profiles
                                BluetoothService.disconnectAllBtMenuProfiles(item.deviceAddress);
                            }
                        } else if (item.connectionStatus === "disconnected") {
                            // Is there a pending connection attempt to another device?
                            if ((pendingDevAddress) && (pendingDevAddress !== item.deviceAddress)) {
                                // A connection to the previously pending device is no longer desired

                                // Update the UI to reflect that there is no longer a pending connection attempt to the old device
                                // Iterate through the list array to find out the index
                                for (x = 0; x < trustedDevices.count; x++) {
                                    if (trustedDevices.get(x).deviceAddress !== pendingDevAddress) {
                                        entry = trustedDevices.get(x);
                                        updateBluetoothEntry(entry.deviceName, entry.deviceAddress, entry.deviceCod, "disconnected", entry.isConnected);
                                    }
                                }
                                pendingDevAddress = "";
                                pendingCod = 0;
                            }

                            // Iterate through the list and disconnect the audio profiles
                            for (x = 0; x < trustedDevices.count; x++) {
                                if (trustedDevices.get(x).connectionStatus !== "disconnected") {
                                    entry = trustedDevices.get(x);
                                    BluetoothService.disconnectAllBtMenuProfiles(entry.deviceAddress);
                                    pendingDevAddress = item.deviceAddress;
                                    pendingCod = item.deviceCod;
                                }
                            }

                            // The device the user tapped on must show "connecting"
                            updateBluetoothEntry(item.deviceName, item.deviceAddress, item.deviceCod, "connecting", item.isConnected);

                            // If the connection isn't pending then connect now
                            if (pendingDevAddress === "")
                                BluetoothService.connectBtDevice(item.deviceAddress, item.deviceCod);
                        }
                    }

                    onMenuCloseRequest: {
                        closeMenuTimer.interval = delayMs;
                        closeMenuTimer.start();
                    }

                    onRequestViewAdjustment: {
                        // this is not working correctly in QML right now.
//                        viewAnimation.to = flickableArea.contentItem.y - offset;
//                        viewAnimation.start();
                    }
                }

                MenuDivider {visible: bluetooth.visible; widthOffset: dividerWidthOffset}

                AirplaneModeElement {
                    id: airplane
                    visible:    true
                    ident:      headerIdent;
                    objectName: "airplaneMode"
                    selectable: !airplaneModeInProgress;

                    onAction: {

                        if (airplaneOn) {
                            setAirplaneModeStatus("Turn on Airplane Mode", 0);
                            preferences.airplaneMode = false;
                        } else {
                            setAirplaneModeStatus("Turn off Airplane Mode", 3);
                            preferences.airplaneMode = true;
                        }

                        airplaneModeTriggered()

                        closeMenuTimer.interval = 250;
                        closeMenuTimer.start();
                    }
                }

                MenuDivider {visible: airplane.visible; widthOffset: dividerWidthOffset}

                RotationLockElement {
                    id: rotation
                    visible: true
                    ident:         headerIdent;

                    Component.onCompleted: {rotation.locked = preferences.rotationLock;}

                    Connections {
                        target: preferences

                        onRotationLockAngleChanged: {
                            if (preferences.rotationLock) {
                                setRotationLockText("Turn off Rotation Lock", true);
                                orientationHelper.__lockedRotationAngle = preferences.rotationLockAngle;
                            } else {
                                setRotationLockText("Turn on Rotation Lock", false);
                            }
                        }
                    }

                    onAction: {
                        if (rotation.delayUpdate)
                            return;
                        rotation.delayUpdate = true;

                        if (rotation.locked) {
                            preferences.rotationLockAngle = preferences.rotationInvalid;
                        } else {
                            preferences.rotationLockAngle = orientationHelper.orientationAngle;
                        }

                        rotationLockTriggered(rotation.locked)

                        closeMenuTimer.interval = 250;
                        closeMenuTimer.start();
                    }
                }

                MenuDivider {visible: rotation.visible; widthOffset: dividerWidthOffset}

                MuteElement {
                    id: muteControl
                    visible: true
                    menuPosition: 2;
                    ident:         headerIdent;

                    Component.onCompleted: {muteControl.mute = preferences.muteSound;}

                    Connections {
                        target: preferences

                        onMuteSoundChanged: {
                            if (!preferences.muteSound) {
                                setMuteControlText("Mute Sound", false);
                                volumeControl.setMute(false);
                            } else {
                                setMuteControlText("Unmute Sound", true);
                                volumeControl.setMute(true);
                            }
                        }
                    }

                    onAction: {
                        if (muteControl.delayUpdate)
                            return;
                        muteControl.delayUpdate = true;

                        if (muteControl.mute) {
                            preferences.muteSound = false;
                        } else {
                            preferences.muteSound = true;
                        }

                        muteToggleTriggered(muteControl.mute)

                        closeMenuTimer.interval = 250;
                        closeMenuTimer.start();
                    }
                }

                MenuDivider {
                    visible: !Settings.hasPowerButton
                }

                PowerElement {
                    id: power
                    visible: !Settings.hasPowerButton
                    menuPosition: 3
                    ident: headerIdent

                    onAction: {
                        showPowerMenu();
                    }
                }

            }

        }
    }

    Item {
        id: maskTop
        z:10
        // 10 + 10 -- transparent pixels on left and right side of image
        // + 2 -- minimal offset(like on legacy)
        width: parent.width - 22
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        opacity: !flickableArea.atYBeginning ? 1.0 : 0.0

        BorderImage {
            width: parent.width
            height: Units.gu(3)
            source: "../../images/menu-dropdown-scrollfade-top.png"
            border { left: 20; top: 0; right: 20; bottom: 0 }
        }

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            y:0
            width: Units.gu(2.1)
            height: Units.gu(2.1)
            source: "../../images/menu-arrow-up.png"
        }

        Behavior on opacity { NumberAnimation{ duration: 70} }
    }

    Item {
        id: maskBottom
        z:10
        // 10 + 10 -- transparent pixels on left and right side of image
        // + 2 -- minimal offset(like on legacy)
        width: parent.width - 22
        anchors.horizontalCenter: parent.horizontalCenter
        y: flickableArea.height - scrollfadeBottom.height + 1
        opacity: !flickableArea.atYEnd ? 1.0 : 0.0

        BorderImage {
            id: scrollfadeBottom
            width: parent.width
            height: Units.gu(3)
            source: "../../images/menu-dropdown-scrollfade-bottom.png"
            border { left: 20; top: 0; right: 20; bottom: 0 }
        }

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Units.gu(0.9)
            width: Units.gu(2.1)
            height: Units.gu(2.1)
            source: "../../images/menu-arrow-down.png"
        }

        Behavior on opacity { NumberAnimation{ duration: 70} }
    }

    InverseMouseArea {
        width: mainMenu.width;
        height: Math.min(systemMenu.height - clipRect.anchors.topMargin - clipRect.anchors.bottomMargin, mainMenu.height);
        sensingArea: root
        onClicked: {
            resetMenu()
            toggleState()
        }
    }

    Timer{
        id      : closeMenuTimer
        repeat  : false;
        running : false;

        onTriggered: closeSystemMenu()
    }


    property bool resetWhenInvisible: false;

    onVisibleChanged: {
        if(resetWhenInvisible) {
            resetMenu();
            resetWhenInvisible = false;
        }

        if(!visible) {
            updateChangedFields();
        }
    }

    function flagMenuReset() {
        resetWhenInvisible = true;
    }

    function resetMenu () {
        wifi.close();
        bluetooth.close();
        vpn.close();
    }

    states: [
        State { name: "hidden" },
        State { name: "visible" }
    ]

    transitions: [
        Transition {
            from: "hidden"
            to: "visible"
            ScriptAction { script: systemMenu.visible = true }
            NumberAnimation { target: systemMenu; property: "opacity"; from: 0; to: 1; duration: 300 }
        },
        Transition {
            from: "visible"
            to: "hidden"
            NumberAnimation { target: systemMenu; property: "opacity"; from: 1; to: 0; duration: 300 }
            ScriptAction { script: systemMenu.visible = false }
        }
    ]
}

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
        airplane.airplaneOn = ((state == 2) || (state == 3));
        airplaneModeInProgress = ((state == 1) || (state == 2));

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

                MenuDivider {widthOffset: dividerWidthOffset}

                BrightnessElement {
                    id: brightness
                    visible:    true
                    margin: Units.gu(0.5); 
                    onFlickOverride: {
                        flickableOverride = override;
                    }
                }

                MenuDivider {widthOffset: dividerWidthOffset}

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

                    onAction: {
                        rotation.delayUpdate = true;

                        if (rotation.locked) {
                            setRotationLockText("Turn on Rotation Lock", false);
                            preferences.rotationLock = false;
                        } else {
                            setRotationLockText("Turn off Rotation Lock", true);
                            preferences.rotationLock = true;
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
                    menuPosition: 2; // bottom
                    ident:         headerIdent;

                    onAction: {
                        muteControl.delayUpdate = true;

                        if (muteControl.mute) {
                            setMuteControlText("Mute Sound", false);
                            volumeControl.setMute(false);
                            preferences.muteSound = false;
                        } else {
                            setMuteControlText("Unmute Sound", true);
                            volumeControl.setMute(true);
                            preferences.muteSound = true;
                        }

                        muteToggleTriggered(muteControl.mute)

                        closeMenuTimer.interval = 250;
                        closeMenuTimer.start();
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

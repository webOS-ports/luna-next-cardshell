/*
 * Copyright (C) 2013-2014 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2014-2015 Herman van Hazendonk <github.com@herrie.org>
 * Copyright (C) 2015 Alan Stice <alan@alanstice.com>
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
import LuneOS.Components 1.0

import "../Utils"
import "../AppTweaks"

import "SystemMenu"


/// The status bar can be divided in three main regions: app menu, title, system indicators/system menu
/// [-- app menu -- / -- (custom) carrier name -- |   --- title ---    |  -- indicators --]
Item {
    id: statusBar

    property Item windowManagerInstance
    property Item gestureHandlerInstance
    property bool fullLauncherVisible: false
    property bool justTypeLauncherActive: false
    property Item batteryService
    property Item wifiService

    property string carrierName: "LuneOS"
    property string defaultColor: "#FF515558"
    property real fontSize: carrierText.font.pixelSize

    // blackMode: statusBar is black and nonsensitive to mouse events
    property bool blackMode: windowManagerInstance.state==="firstuse" || state==="dockmode"
    property QtObject compositorInstance

    signal showPowerMenu()

    function probeNetworkStatus()
    {
        networkStatusQuery.subscribe(
                    "luna://com.palm.telephony/networkStatusQuery",
                    "{\"subscribe\":true}",
                    onNetworkStatusChanged, onError)
    }

    function onNetworkStatusChanged(message) {
        var response = JSON.parse(message.payload)

        if (!response.returnValue &&
              response.errorText === "Backend not initialized") {
            resubscribeTimer.start();
            return;
        }
        else if(response.extended.state==="noservice")
            return;
        else if (response.extended.registration && response.extended.state !== "noservice") {
            carrierName = response.extended.networkName
            carrierText.text = carrierName
        }
    }

    function onError(message) {
        console.log("Failed to call networkStatus service: " + message)
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: (!Settings.tabletUi || statusBar.blackMode)?"black":"transparent";

        Rectangle {
            anchors.fill: parent
            color: statusBar.defaultColor
            opacity: (statusBar.state==="application-visible")||(statusBar.state==="launcher-visible")
            Behavior on opacity { NumberAnimation {duration: 300} }
            visible: Settings.tabletUi && !statusBar.blackMode
        }

        Image {
            source: "../images/statusbar/status-bar-background.png"
            fillMode: Image.TileHorizontally
            verticalAlignment: Image.AlignLeft
            anchors.fill: parent
            visible: Settings.tabletUi && !statusBar.blackMode
        }

        Text {
            id: titleTextDate
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            visible: statusBar.state === "lockscreen"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: "white"
            font.family: Settings.fontStatusBar
            font.pixelSize: statusBar.fontSize
            font.bold: true

            function updateClock() {
                titleTextDate.text = Qt.formatDateTime(new Date(), "M/d/yy")
            }

            text: Qt.formatDateTime(new Date(), "M/d/yy")
        }

        Component {
            id: tweaksClock
            TweaksClock {
                visible: statusBar.state!=="lockscreen"
                fontSize: statusBar.fontSize
                onTriggered: titleTextDate.updateClock()
            }
        }

        Loader {
            id: phoneTweaksClock
            anchors.fill: parent
            sourceComponent: !Settings.tabletUi? tweaksClock : undefined;
        }

        Item {
            id: carrierString
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.topMargin: parent.height * 0.25
            anchors.bottomMargin: parent.height * 0.25
            anchors.leftMargin: parent.height * 0.25
            width: (background.width / 2) - Units.gu(3)
            visible: !appMenu.visible

            LunaService {
                id: networkStatusQuery

                name: "org.webosports.luna"
                usePrivateBus: true

                onInitialized: {
                    probeNetworkStatus()
                }

            }

            Text {
                id: carrierText
                anchors.fill: parent
                horizontalAlignment: Text.AlignHLeft
                verticalAlignment: Text.AlignVCenter
                color: "white"
                font.family: Settings.fontStatusBar
                font.pixelSize: parent.height
                font.bold: true
                text: carrierName
                width: parent.width
                elide: Text.ElideRight

                Connections {
                    target: AppTweaks
                    onEnableCustomCarrierStringValueChanged: updateCarrierString()
                    onCustomCarrierStringValueChanged: updateCarrierString()
                    function updateCarrierString() {
                        if (AppTweaks.enableCustomCarrierStringValue === true) {
                            //Only show custom carrier text in case we have the option enabled in Tweaks
                            carrierText.text = AppTweaks.customCarrierStringValue
                        } else {
                            //Otherwise show the regular "Carrier"
                            carrierText.text = carrierName
                        }
                    }
                }
            }
        }

        AppMenu {
            id: appMenu
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
        }

        Loader {
            id: notificationAreaInstance
            anchors.top: parent.top
            height: parent.height
            anchors.right: systemIndicators.left
            enabled: !statusBar.blackMode
            visible: !lockScreen.visible
            active: Settings.tabletUi

            Component.onCompleted: {
                notificationAreaInstance.setSource("../Notifications/NotificationAreaTablet.qml",
                {
                    "windowManagerInstance": statusBar.windowManagerInstance,
                    "compositorInstance": statusBar.compositorInstance,
                    "maxDashboardWindowHeight": windowManagerInstance.screenheight*0.67,
                    "blackMode": statusBar.blackMode,
                });
            }
        }

        BorderImage {
            id: systemMenuOpenBg
            visible: Settings.tabletUi && systemMenu.visible && statusBar.state!=="dockmode"
            source: "../images/statusbar/status-bar-menu-dropdown-tab.png"
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            width: parent.width-systemIndicators.x+19
            x: systemIndicatorsBoundingRect.x-9
            smooth: false
            border.left: 11
            border.right: 11
            border.top: 2
        }

        Item {
            id: systemIndicatorsBoundingRect
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: systemIndicators.width+2*systemIndicators.anchors.margins-systemIndicators.spacing
        }

        Row {
            id: systemIndicators
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: Units.gu(1) / 2
            spacing: Units.gu(1) / 2

            Image {
                id: statusBarSeparator
                source: "../images/statusbar/status-bar-separator.png"
                anchors.verticalCenter: parent.verticalCenter
                height: statusBar.height
                width: 2
                mipmap: true
                opacity: Settings.tabletUi && !systemMenu.visible
                visible: statusBar.state!=="lockscreen"
            }

            SystemIndicators {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                spacing: parent.spacing
            }

            Loader {
                id: tabletTweaksClock
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                sourceComponent: Settings.tabletUi? tweaksClock : undefined;
            }

            Image {
                id: systemMenuArrow
                source: "../images/statusbar/menu-arrow.png"
                anchors.verticalCenter: parent.verticalCenter
                height: Units.gu(2.6)
                width: Units.gu(1.5)
                mipmap: true
                visible: !statusBar.blackMode && !(statusBar.state==="lockscreen")
            }
        }

        MouseArea {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: systemIndicators.width
            onClicked: {
                if (!lockScreen.locked && !dockMode.visible && windowManagerInstance.state === "normal")
                    systemMenu.toggleState()
            }
        }

        Connections {
            target: lockScreen
            onLockedChanged: {
                if (lockScreen.locked) {
                    systemMenu.visibleBeforeLock = systemMenu.isVisible();
                    systemMenu.visible = false;
                }
                else {
                    systemMenu.visible = systemMenu.visibleBeforeLock;
                }
            }
        }

        Connections {
            target: gestureHandlerInstance
            onScreenEdgeFlickEdgeTop: {
                if (!timeout && windowManagerInstance.gesturesEnabled === true) {
                    if (appMenu.contains(mapToItem(appMenu, pos.x, pos.y)))
                        appMenu.toggleState()
                    else if (!statusBar.blackMode) {
                        if (!Settings.tabletUi && systemMenu.contains(mapToItem(systemMenu, pos.x, systemMenu.y)))
                            systemMenu.toggleState()
                        else if (Settings.tabletUi && systemIndicatorsBoundingRect.contains(mapToItem(systemIndicatorsBoundingRect, pos.x, pos.y)))
                            systemMenu.toggleState()
                        else if ((notificationAreaInstance.status === Loader.Ready) && notificationAreaInstance.item.boundingRect.contains(mapToItem(notificationAreaInstance.item.boundingRect, pos.x, pos.y)))
                            notificationAreaInstance.item.clicked()
                    }
                }
            }
        }

        SystemMenu {
            id: systemMenu
            anchors.top: parent.bottom
            visible: false
            enabled: !statusBar.blackMode
            x: parent.width - systemMenu.width + systemMenu.edgeOffset
            property bool visibleBeforeLock: false

            onCloseSystemMenu: {
                systemMenu.resetMenu()
                systemMenu.toggleState()
            }

            onShowPowerMenu: statusBar.showPowerMenu();
        }

        Timer {
                id: resubscribeTimer
                interval: 500
                repeat: false
                running: false
                onTriggered: {
                    probeNetworkStatus();
                }
            }
    }

    state: "default"

    states: [
        State {
            name: "hidden"
            PropertyChanges { target: statusBar; visible: false }
            PropertyChanges { target: appMenu; state: "hidden" }
        },
        State {
            name: "default"
            PropertyChanges { target: statusBar; visible: true }
            PropertyChanges { target: appMenu; state: "hidden" }
        },
        State {
            name: "dockmode"
            PropertyChanges { target: statusBar; visible: true }
            PropertyChanges { target: appMenu; state: "dockmode" }
        },
        State {
            name: "application-visible"
            PropertyChanges { target: statusBar; visible: true }
            PropertyChanges { target: appMenu; state: "appmenu" }
        },
        State {
            name: "launcher-visible"
            PropertyChanges { target: statusBar; visible: true }
            PropertyChanges { target: carrierText; text: "Launcher"}
            PropertyChanges { target: appMenu; state: "hidden" }
        },
        State {
            name: "lockscreen"
            PropertyChanges { target: statusBar; visible: true }
            PropertyChanges { target: appMenu; state: "hidden" }
        }
    ]

    Connections {
        target: windowManagerInstance
        onSwitchToLockscreen: {
            state = "lockscreen"
        }
        onSwitchToDockMode: {
            state = "dockmode"
        }
        onSwitchToMaximize: {
            state = "application-visible"
        }
        onSwitchToFullscreen: {
            state = "hidden"
        }
        onSwitchToCardView: {
            state = "default"
        }
        onSwitchToLauncherView: {
            state = "launcher-visible"
            if (systemMenu.isVisible())
                systemMenu.toggleState()
        }
    }
}

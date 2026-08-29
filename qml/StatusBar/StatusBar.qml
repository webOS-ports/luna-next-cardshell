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
    // operator reported for the default voice SIM, and the combined list when
    // more than one SIM is up; updateCarrierName() picks between them
    property string singleSimCarrierName: "LuneOS"
    property string multiSimCarrierName: ""
    property string defaultColor: "#FF515558"
    property real fontSize: carrierText.font.pixelSize

    // blackMode: statusBar is black and nonsensitive to mouse events
    property bool blackMode: windowManagerInstance.state==="firstuse" || state==="dockmode"
    property QtObject compositorInstance

    // The classic tree-based system menu and the tabbed "New Device
    // Menu" implement the same external interface; the tweak picks
    // which one gets loaded into systemMenuLoader.
    property Item systemMenu: systemMenuLoader.item

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
            singleSimCarrierName = response.extended.networkName
            updateCarrierName()
        }
    }

    function onError(message) {
        console.log("Failed to call networkStatus service: " + message)
    }

    function probeSimList()
    {
        simListQuery.subscribe(
                    "luna://com.palm.telephony/simListQuery",
                    "{\"subscribe\":true}",
                    onSimListChanged, onSimListError)
    }

    /*
     * With two SIMs a single operator name hides half of what the device is
     * connected to, so the carrier area lists them all, e.g. "Vodafone | KPN".
     */
    function onSimListChanged(message) {
        var response = JSON.parse(message.payload)

        if (!response.returnValue || !response.sims) {
            multiSimCarrierName = ""
            updateCarrierName()
            return;
        }

        var names = []

        if (response.simCount >= 2) {
            for (let i = 0; i < response.sims.length; i++) {
                let sim = response.sims[i]

                if (!sim.present || !sim.powered)
                    continue;

                names.push(sim.operatorName && sim.operatorName.length > 0 ? sim.operatorName
                                                                          : sim.name)
            }
        }

        multiSimCarrierName = names.length > 0 ? names.join(" | ") : ""
        updateCarrierName()
    }

    /*
     * The carrier area has three possible sources, in order of precedence: a
     * custom string from Tweaks, the combined operator list when more than one
     * SIM is up, and the single operator reported by networkStatusQuery.
     * Both subscriptions funnel through here so that whichever answers last
     * cannot clobber the other.
     */
    function updateCarrierName() {
        carrierName = multiSimCarrierName.length > 0 ? multiSimCarrierName
                                                     : singleSimCarrierName

        if (AppTweaks.enableCustomCarrierStringValue === true)
            carrierText.text = AppTweaks.customCarrierStringValue
        else
            carrierText.text = carrierName
    }

    function onSimListError(message) {
        console.log("Failed to call simListQuery service: " + message)
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

                name: "com.webos.surfacemanager-cardshell"

                onInitialized: {
                    probeNetworkStatus()
                }

            }

            LunaService {
                id: simListQuery

                name: "com.webos.surfacemanager-cardshell"

                onInitialized: {
                    probeSimList()
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
                    function onEnableCustomCarrierStringValueChanged() {
                        updateCarrierString()
                    }
                    function onCustomCarrierStringValueChanged() {
                        updateCarrierString()
                    }
                    function updateCarrierString() {
                        // single place that decides what the carrier area shows
                        statusBar.updateCarrierName()
                    }
                }
            }
        }

        AppMenu {
            id: appMenu
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            fontSize: statusBar.fontSize
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
                    "maxDashboardWindowHeight": Qt.binding(() => {return windowManagerInstance.height*0.67;}),
                    "blackMode": statusBar.blackMode,
                });
            }
        }

        BorderImage {
            id: systemMenuOpenBg
            visible: Settings.tabletUi && systemMenu && systemMenu.visible && !systemMenu.centered && statusBar.state!=="dockmode"
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
                opacity: Settings.tabletUi && !(systemMenu && systemMenu.visible)
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
                visible: statusBar.state!=="lockscreen"
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
                if (systemMenu && !lockScreen.locked && !dockMode.visible && windowManagerInstance.state === "normal")
                    systemMenu.toggleState()
            }
        }

        Connections {
            target: lockScreen
            function onLockedChanged() {
                if (!systemMenu)
                    return;
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
            function onScreenEdgeFlickEdgeTop(timeout, pos) {
                if (!timeout && windowManagerInstance.gesturesEnabled === true) {
                    if (appMenu.contains(mapToItem(appMenu, pos.x, pos.y)))
                        appMenu.toggleState()
                    else if (!statusBar.blackMode && systemMenu) {
                        if (!Settings.tabletUi && systemMenuLoader.contains(mapToItem(systemMenuLoader, pos.x, systemMenuLoader.y)))
                            systemMenu.toggleState()
                        else if (Settings.tabletUi && systemIndicatorsBoundingRect.contains(mapToItem(systemIndicatorsBoundingRect, pos.x, pos.y)))
                            systemMenu.toggleState()
                        else if ((notificationAreaInstance.status === Loader.Ready) && notificationAreaInstance.item.boundingRect.contains(mapToItem(notificationAreaInstance.item.boundingRect, pos.x, pos.y)))
                            notificationAreaInstance.item.clicked()
                    }
                }
            }
        }

        Loader {
            id: systemMenuLoader
            anchors.top: parent.bottom
            enabled: !statusBar.blackMode
            x: (item && item.centered) ? Math.round((parent.width - width) / 2)
                                       : parent.width - width + (item ? item.edgeOffset : 0)
            source: AppTweaks.newDeviceMenuTweakValue ? "SystemMenu/NewDeviceMenu.qml" : "SystemMenu/SystemMenu.qml"

            onLoaded: item.visible = false

            Connections {
                target: systemMenuLoader.item
                function onCloseSystemMenu() {
                    systemMenu.resetMenu()
                    systemMenu.toggleState()
                }
                function onShowPowerMenu() {
                    statusBar.showPowerMenu();
                }
            }
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
        function onSwitchToLockscreen () {
            state = "lockscreen"
        }
        function onSwitchToDockMode () {
            state = "dockmode"
        }
        function onSwitchToMaximize (window) {
            state = "application-visible"
        }
        function onSwitchToFullscreen (window) {
            state = "hidden"
        }
        function onSwitchToCardView () {
            state = "default"
        }
        function onSwitchToLauncherView () {
            state = "launcher-visible"
            if (systemMenu && systemMenu.isVisible())
                systemMenu.toggleState()
        }
    }
}

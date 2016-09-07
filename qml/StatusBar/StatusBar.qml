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

import QtQuick 2.0
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
    property string timeFormat: "HH24"

    property string carrierName: "LuneOS"

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

    function probeTimeFormat()
    {
        timeFormatQuery.subscribe(
                    "luna://com.palm.systemservice/getPreferences",
                    JSON.stringify({"subscribe":true, "keys":["timeFormat"]}),
                    onTimeFormatChanged, onTimeFormatError)
    }

    function onTimeFormatChanged(message) {
		var response = JSON.parse(message.payload)
        timeFormat = response.timeFormat
    }

    function onTimeFormatError(message) {
        console.log("Failed to call timeFormat service: " + message)
    }
	

    Rectangle {
        id: background
        anchors.fill: parent
        color: "black"

        Item {
            id: title
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: parent.height * 0.2
            anchors.bottomMargin: parent.height * 0.2
            implicitWidth: titleText.contentWidth

			LunaService {
                id: timeFormatQuery

                name: "org.webosports.luna"
                usePrivateBus: true

                onInitialized: {
                    probeTimeFormat()
                }

            }

			
            Text {
                id: titleText
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                color: "white"
                font.family: Settings.fontStatusBar
                font.pixelSize: parent.height
                font.bold: true

                //Set the default to Time in case no Tweaks option has been set yet.
                Timer {
                    id: clockTimer
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: titleText.updateClock()
                }

                function updateClock() {
                    if (AppTweaks.dateTimeTweakValue === "dateTime")
                        titleText.text = timeFormat === "HH24" ? Qt.formatDateTime(new Date(),
                                                           "dd-MMM-yyyy h:mm") : Qt.formatDateTime(new Date(),
                                                           "dd-MMM-yyyy h:mm AP")
                    else if (AppTweaks.dateTimeTweakValue === "timeOnly")
                        titleText.text = timeFormat === "HH24" ? Qt.formatTime(new Date(), "h:mm") : Qt.formatTime(new Date(), "h:mm AP")
                    else if (AppTweaks.dateTimeTweakValue === "dateOnly")
                        titleText.text = Qt.formatDate(new Date(),
                                                           "dd-MMM-yyyy") 
                }

                text: timeFormat === "HH24" ? Qt.formatDateTime(new Date(), "h:mm") : Qt.formatDateTime(new Date(), "h:mm AP")
            }
        }

        Item {
            id: carrierString
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.topMargin: parent.height * 0.2
            anchors.bottomMargin: parent.height * 0.2
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

        SystemIndicators {
            id: systemIndicators
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
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
                if (systemMenu.isVisible())
                    systemMenu.toggleState()
            }
        }

        Connections {
            target: gestureHandlerInstance
            onScreenEdgeFlickEdgeTop: {
                if (!timeout && windowManagerInstance.gesturesEnabled === true) {
                    if (appMenu.contains(mapToItem(appMenu, pos.x, pos.y)))
                        appMenu.toggleState()
                    else if (systemMenu.contains(mapToItem(systemMenu, pos.x, systemMenu.y)))
                        systemMenu.toggleState()
                }
            }
        }

        SystemMenu {
            id: systemMenu
            anchors.top: parent.bottom
            visible: false
            x: parent.width - systemMenu.width + systemMenu.edgeOffset

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
        }
    ]

    Connections {
        target: windowManagerInstance
        onSwitchToLockscreen: {
            state = "default"
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
            state = "default"
            if (systemMenu.isVisible())
                systemMenu.toggleState()
        }
    }
}

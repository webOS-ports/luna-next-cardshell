/*
 * Copyright (C) 2013-2014 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2014 Herman van Hazendonk <github.com@herrie.org>
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

import "../Utils"

import "SystemMenu"


/// The status bar can be divided in three main regions: app menu, title, system indicators/system menu
/// [-- app menu -- / -- (custom) carrier name -- |   --- title ---    |  -- indicators --]
Item {
    id: statusBar

    property Item windowManagerInstance
    property bool fullLauncherVisible: false
    property bool justTypeLauncherActive: false
    property Item batteryService
    property Item wifiService
    property Item lockScreen
    property Item dockMode

    property string carrierName: "LuneOS"

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
        {
            resubscribeTimer.start();
            return;
        }
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
        color: "black"

        Item {
            id: title
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: parent.height * 0.2
            anchors.bottomMargin: parent.height * 0.2
            implicitWidth: titleText.contentWidth

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
                    interval: 100
                    running: true
                    repeat: true
                    onTriggered: titleText.updateClock()
                }

                function updateClock() {
                    if (dateTimeTweak.value === "dateTime")
                        titleText.text = Qt.formatDateTime(new Date(),
                                                           "dd-MMM-yyyy h:mm")
                    else if (dateTimeTweak.value === "timeOnly")
                        titleText.text = Qt.formatDateTime(new Date(), "h:mm")
                    else if (dateTimeTweak.value === "dateOnly")
                        titleText.text = Qt.formatDateTime(new Date(),
                                                           "dd-MMM-yyyy")
                }

                text: Qt.formatDateTime(new Date(), "h:mm")
                //FIXME Still necessary to adjust based on regional settings later for date and time.
                Tweak {
                    id: dateTimeTweak
                    owner: "luna-next-cardshell"
                    key: "showDateTime"
                    defaultValue: "timeOnly"
                }
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

                Tweak {
                    id: enableCustomCarrierString
                    owner: "luna-next-cardshell"
                    key: "useCustomCarrierString"
                    defaultValue: "false"
                    onValueChanged: updateCustomCarrierString()

                    function updateCustomCarrierString() {
                        if (enableCustomCarrierString.value === true) {
                            //Only show custom carrier text in case we have the option enabled in Tweaks
                            carrierText.text = customCarrierString.value
                        } else {
                            //Otherwise show the regular "Carrier"
                            carrierText.text = carrierName
                        }
                    }
                }
                Tweak {
                    id: customCarrierString
                    owner: "luna-next-cardshell"
                    key: "carrierString"
                    defaultValue: "Custom Carrier String"
                    onValueChanged: updateCarrierString()

                    function updateCarrierString() {
                        if (enableCustomCarrierString.value === true) {
                            //Only show custom carrier text in case we have the option enabled in Tweaks
                            carrierText.text = customCarrierString.value
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
            anchors.topMargin: parent.height * 0.2
            anchors.bottomMargin: parent.height * 0.2
            state: statusBar.state === "application-visible" || dockMode.visible ? "visible" : "hidden"
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
            width: 100
            onClicked: {
                if (!lockScreen.locked)
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

        SystemMenu {
            id: systemMenu
            anchors.top: parent.bottom
            visible: false
            x: parent.width - systemMenu.width + systemMenu.edgeOffset

            onCloseSystemMenu: systemMenu.toggleState()
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
            PropertyChanges {
                target: statusBar
                visible: false
            }
        },
        State {
            name: "default"
            PropertyChanges {
                target: statusBar
                visible: true
            }
        },
        State {
            name: "application-visible"
            PropertyChanges {
                target: statusBar
                visible: true
            }
            PropertyChanges {
                target: carrierString
                visible: false
            }
        }
    ]

    Connections {
        target: windowManagerInstance
        onSwitchToDashboard: {
            state = "default"
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

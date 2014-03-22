/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
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
import LunaNext 0.1

// this should be a plugin import
import "../WindowManager/WindowManagerServices.js" as WindowManagerServices
import "../Utils"

FakeWindowBase {
    id: dummyWindow

    appId: "org.webosports.tests.dummyWindow"
    windowType: WindowType.Card

    height: 200
    width: 600

    property alias scale: windowFlickable.scale

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "grey" }
            GradientStop { position: 1.0; color: "black" }
        }
    }

    Flickable {
        id: windowFlickable
        anchors.fill: parent
        flickableDirection: Flickable.VerticalFlick

        contentHeight: contentColumn.height
        clip: true

        Column {
            id: contentColumn

            anchors.centerIn: parent
            width: parent.width
            spacing: 20

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Test Window App " + winId
                font.pointSize: 20
                color: "white"
            }

            ActionButton {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width / 2
                height: 50

                caption: "Current mode: " + (dummyWindow.userData ? dummyWindow.userData.windowState : -1)

                onAction: {
                    if( dummyWindow.userData ) {
                        var currentState = dummyWindow.userData.windowState;
                        // switch to the next state
                        currentState = (currentState+1) % 4;

                        // Skip Invisible state
                        if (currentState === 0)
                            currentState = WindowState.Carded;

                        dummyWindow.userData.windowState = currentState;
                    }
                }
            }
            ActionButton {
                anchors.horizontalCenter: parent.horizontalCenter
                caption: "Add notification"
                width: parent.width / 2
                height: 50

                onAction: {
                    lunaNextLS2Service.call("luna://com.palm.applicationManager/createNotification",
                                            JSON.stringify({"type": "dashboard",
                                                            "appId": "org.webosports.tests.fakeJustTypeLauncher",
                                                            "appIcon": "../images/glow.png"}),
                                            undefined, undefined)
                }
            }
            ActionButton {
                anchors.horizontalCenter: parent.horizontalCenter
                negative: true
                caption: "Kill me"
                width: parent.width / 2
                height: 50

                onAction: {
                    // commit suicide
                    dummyWindow.destroy();
                }
            }

            TextInput {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "try me !"
            }
        }
    }
}

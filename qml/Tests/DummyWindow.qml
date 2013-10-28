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

FakeWindowBase {
    id: dummyWindow

    appId: "org.webosports.tests.dummyWindow"
    windowType: WindowType.Card

    height: 200
    width: 600

    property alias scale: windowRectangle.scale

    Rectangle {
        id: windowRectangle

        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "grey" }
            GradientStop { position: 1.0; color: "black" }
        }

        Column {
            anchors.centerIn: parent
            spacing: 20

            Text {
                text: "Test Window App"
                font.pointSize: 20
                color: "white"
            }

            Text {
                text: "Current mode: " + WindowManagerServices.getWindowState(dummyWindow)
                font.pointSize: 20
                font.underline: true
                color: "white"

                MouseArea {
                    anchors.fill: parent;

                    onClicked: {
                        var currentState = WindowManagerServices.getWindowState(dummyWindow);
                        // switch to the next state
                        currentState = (currentState+1) % 4;

                        // Skip Invisible state
                        if (currentState === 0)
                            currentState = WindowState.Carded;

                        WindowManagerServices.setWindowState(dummyWindow, currentState);
                    }
                }
            }
            Text {
                text: "Add notification"
                font.pointSize: 20
                font.underline: true
                color: "white"

                MouseArea {
                    anchors.fill: parent;

                    onClicked: {
                        lunaNextLS2Service.call("luna://com.palm.applicationManager/createNotification",
                                                JSON.stringify({"type": "dashboard",
                                                                "appId": "org.webosports.tests.fakeJustTypeLauncher",
                                                                "appIcon": "../images/glow.png"}),
                                                undefined, undefined)
                    }
                }
            }
            Text {
                text: "Kill me"
                font.pointSize: 20
                font.underline: true
                color: "white"

                MouseArea {
                    anchors.fill: parent;

                    onClicked: {
                        // commit suicide
                        dummyWindow.destroy();
                    }
                }
            }

            TextInput {
                text: "try me !"
            }
        }
    }
}

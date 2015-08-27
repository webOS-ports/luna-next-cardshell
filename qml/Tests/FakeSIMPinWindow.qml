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
import QtQuick.Controls 1.0
import LunaNext.Compositor 0.1

FakeWindowBase {
    id: fakeSIMPinWindow

    appId: "org.webosports.tests.fakeSimPinWindow"
    windowType: WindowType.Pin


    Rectangle {
        id: windowRectangle

        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "lightgrey" }
            GradientStop { position: 1.0; color: "lightblue" }
        }

        Row {
            anchors.centerIn: parent

            Button {
                text: "Hide me"
                onClicked: {
                    fakeSIMPinWindow.visible = false;
                    showTimer.start();
                }

                Timer {
                    id: showTimer
                    interval: 3000
                    onTriggered: fakeSIMPinWindow.visible = true
                }
            }
            Button {
                text: "Key"
                checkable: true
            }
        }
    }
}

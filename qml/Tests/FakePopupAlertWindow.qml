/*
 * Copyright (C) 2014 Christophe Chapuis <chris.chapuis@gmail.com>
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
    id: fakePopupAlertWindow

    appId: "org.webosports.tests.fakePopupAlertWindow"
    windowType: WindowType.PopupAlert

    height: 50 + Math.random()*50

    property alias scale: windowRectangle.scale

    Rectangle {
        id: windowRectangle

        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "grey" }
            GradientStop { position: 1.0; color: "red" }
        }

        Row {
            anchors.centerIn: parent

            Button {
                text: "OK"
                onClicked: fakePopupAlertWindow.destroy()
            }
            Button {
                text: "Cancel"
                checkable: true
            }
        }
    }
}

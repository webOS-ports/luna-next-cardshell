/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
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
import Qt5Compat.GraphicalEffects
import LunaNext.Common 0.1

Item {
    id: launchableAppIcon

    property string appIcon
    property string appTitle
    property string appId
    property var appParams: ({})
    property bool showTitle: false

    property real iconSize: 64
    property bool glow: false

    signal startLaunchApplication(string appId, var appParams)

    height: appIconColumn.height

    Column {
        id: appIconColumn

        width: parent.width

        Image {
            id: appIconImage
            width: iconSize
            height: iconSize
            anchors.horizontalCenter: parent.horizontalCenter

            fillMode: Image.PreserveAspectFit

            sourceSize.height: height
            sourceSize.width: width
            source: launchableAppIcon.appIcon

            visible: !glow
        }
        Glow {
            id: glowingIcon
            width: iconSize
            height: iconSize
            anchors.horizontalCenter: parent.horizontalCenter
            visible: glow
            radius: 4
            color: "white"
            transparentBorder: true
            source: appIconImage

            SequentialAnimation on radius {
                running: glow
                loops: Animation.Infinite
                NumberAnimation {
                    from: 4; to: 20
                    duration: 500
                }
                NumberAnimation {
                    from: 20; to: 4
                    duration: 500
                }
            }
        }

        Text {
            width: parent.width
            visible: launchableAppIcon.showTitle
            anchors.horizontalCenter: parent.horizontalCenter
            color: "white"
            text: launchableAppIcon.appTitle
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            font.pixelSize: Units.gu(1.4)
            font.bold: true
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: appIconColumn
        onClicked:  startLaunchApplication(launchableAppIcon.appId, launchableAppIcon.appParams);
    }
}

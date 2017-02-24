/*
 * Copyright (C) 2015-2016 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2016 Herman van Hazendonk <github.com@herrie.org>
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
import LunaNext.Common 0.1

Item {
    id: notification

    property string title: "(no title)"
    property string body: "(no summary)"
    property url iconUrl: Qt.resolvedUrl("../images/default-app-icon.png");
    property string bgColor: Settings.tabletUi? "transparent" : "#393939";

    Rectangle {
        id: iconBox
        width: Units.gu(6)
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: bgColor
        radius: 8

        Image {
            id: notificationIcon
            anchors.fill: parent
            anchors.margins: Units.gu(0.5)
            anchors.centerIn: parent
            source: iconUrl
            fillMode: Image.PreserveAspectFit
            layer.mipmap: true
        }
    }

    Rectangle {
        id: mainContent
        anchors.left: iconBox.right
        anchors.leftMargin: Units.gu(1) / 2
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: bgColor
        radius: 8

        Text {
            id: summaryText
            font.bold: true
            font.pixelSize: FontUtils.sizeToPixels("medium")
            color: "white"
            text: notification.title
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 3
            anchors.leftMargin: 10
            anchors.bottomMargin: 5
        }

        Text {
            id: bodyText
            font.pixelSize: FontUtils.sizeToPixels("small")
            font.bold: false
            color: "white"
            text: notification.body
            anchors.top: summaryText.bottom
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10
            anchors.bottomMargin: 3
        }
    }
}

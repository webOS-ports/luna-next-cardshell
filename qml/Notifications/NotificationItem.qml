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

    /*
     * Legacy webOS's dashboard look: the shared bar, the icon sitting on it, a
     * bold white title over a regular white summary. The tablet ui keeps the
     * transparent background it has always had.
     */
    NotificationBar {
        id: bar
        anchors.fill: parent
        visible: !Settings.tabletUi
    }

    Image {
        id: notificationIcon
        anchors.left: parent.left
        anchors.leftMargin: parent.height * 0.2
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height * 0.62
        width: height
        source: iconUrl
        fillMode: Image.PreserveAspectFit
        layer.mipmap: true
    }

    Column {
        id: textColumn
        anchors.left: notificationIcon.right
        anchors.leftMargin: parent.height * 0.35
        anchors.right: parent.right
        anchors.rightMargin: parent.height * 0.2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
            id: summaryText
            width: parent.width
            font.bold: true
            font.pixelSize: FontUtils.sizeToPixels("medium")
            color: "white"
            elide: Text.ElideRight
            text: notification.title
        }

        Text {
            id: bodyText
            width: parent.width
            font.pixelSize: FontUtils.sizeToPixels("medium")
            font.bold: false
            color: "white"
            elide: Text.ElideRight
            text: notification.body
        }
    }
}

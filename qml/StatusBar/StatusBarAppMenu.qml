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

Item {
    id: appMenuItem

    width: appMenuBgImageLeft.width + appMenuBgImageCenter.width + appMenuBgImageRight.width

    Image {
        id: appMenuBgImageLeft

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        fillMode: Image.PreserveAspectFit
        smooth: true

        source: "../images/statusbar/appname-background-left.png"
    }
    Image {
        id: appMenuBgImageCenter

        anchors.left: appMenuBgImageLeft.right
        width: appMenuText.contentWidth
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        smooth: true

        source: "../images/statusbar/appname-background-center.png"
    }
    Image {
        id: appMenuBgImageRight

        anchors.left: appMenuBgImageCenter.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        fillMode: Image.PreserveAspectFit
        smooth: true

        source: "../images/statusbar/appname-background-right.png"
    }
    Text {
        id: appMenuText

        anchors.left: appMenuBgImageCenter.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        color: "white"
        font.family: Settings.fontStatusBar
        font.pointSize: 20
        fontSizeMode: Text.VerticalFit
        text: "App menu"
    }
}

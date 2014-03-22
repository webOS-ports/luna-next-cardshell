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

Item {
    property real cornerRadius

    Image {
        anchors.top: parent.top
        anchors.left: parent.left
        width: cornerRadius
        height: cornerRadius
        source: "../images/wm-corner-top-left.png"
        sourceSize.width: cornerRadius
        sourceSize.height: 0 // ratio will be kept (see Image documentation)
    }
    Image {
        anchors.top: parent.top
        anchors.right: parent.right
        width: cornerRadius
        height: cornerRadius
        source: "../images/wm-corner-top-right.png"
        sourceSize.width: cornerRadius
        sourceSize.height: 0 // ratio will be kept (see Image documentation)
    }
    Image {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: cornerRadius
        height: cornerRadius
        source: "../images/wm-corner-bottom-left.png"
        sourceSize.width: cornerRadius
        sourceSize.height: 0 // ratio will be kept (see Image documentation)
    }
    Image {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: cornerRadius
        height: cornerRadius
        source: "../images/wm-corner-bottom-right.png"
        sourceSize.width: cornerRadius
        sourceSize.height: 0 // ratio will be kept (see Image documentation)
    }
}

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
import LunaNext.Shell 0.1

import "../Utils"

Item {
    id: gestureAreaItem

    signal tapGesture
    signal swipeUpGesture(int modifiers)
    signal swipeDownGesture(int modifiers)
    signal swipeLeftGesture(int modifiers)
    signal swipeRightGesture(int modifiers)

    focus: true

    // Black rectangle behind, and a glowing image in front
    Rectangle {
        anchors.fill: parent
        color: "black"
    }
    Image {
        id: glowImage
        anchors.centerIn: parent
        height: parent.height*0.5
        width: parent.width*0.7
        source: "../images/glow.png"
        smooth: true
        fillMode: Image.PreserveAspectFit
    }
    Image {
        id: glowImageMask
        visible: false
        y: glowImage.y
        height: glowImage.height
        width: glowImage.width
        source: "../images/glowMask.png"
        smooth: true
        fillMode: Image.Stretch
    }

    SequentialAnimation {
        id: glowRightToLeft
        PropertyAction { target: glowImageMask; property: "x"; value: glowImage.x + glowImage.width }
        PropertyAction { target: glowImageMask; property: "visible"; value: true }
        NumberAnimation { target: glowImageMask; property: "x"; to: glowImage.x - glowImage.width; duration: 500 }
        PropertyAction { target: glowImageMask; property: "visible"; value: false }
    }
    SequentialAnimation {
        id: glowLeftToRight
        PropertyAction { target: glowImageMask; property: "x"; value: glowImage.x - glowImage.width }
        PropertyAction { target: glowImageMask; property: "visible"; value: true }
        NumberAnimation { target: glowImageMask; property: "x"; to: glowImage.x + glowImage.width; duration: 500 }
        PropertyAction { target: glowImageMask; property: "visible"; value: false }
    }

    DeviceKeyHandler {
        onHomePressed: {
            console.log("Key: Home");
            tapGesture();
        }
        onEndPressed: {
            console.log("Key: End");
            swipeUpGesture(0);
        }
        onEscapePressed: {
            console.log("Key: Escape");
            swipeLeftGesture(0);
        }
    }

    SwipeArea {
        id: gestureAreaInput
        anchors.fill: parent

        onSwipeRightGesture: {
            glowLeftToRight.start();
            gestureAreaItem.swipeRightGesture(modifiers);
        }
        onSwipeLeftGesture: {
            glowRightToLeft.start();
            gestureAreaItem.swipeLeftGesture(modifiers);
        }
        onSwipeUpGesture: gestureAreaItem.swipeUpGesture(modifiers);
        onSwipeDownGesture: gestureAreaItem.swipeDownGesture(modifiers);

        onClicked: gestureAreaItem.tapGesture();
    }
}

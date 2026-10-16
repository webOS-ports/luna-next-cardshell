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
    property bool enableGestureArea: true

    /*
     * What the card view and the launcher act on. They only hear a gesture the
     * shell has not already dealt with through shellFirst, so raise them with
     * tap(), swipeUp() and so on rather than emitting them directly.
     */
    signal tapGesture
    signal swipeUpGesture(int modifiers)
    signal swipeDownGesture(int modifiers)
    signal swipeLeftGesture(int modifiers)
    signal swipeRightGesture(int modifiers)

    /*!
     * Asked first, with "tap", "up", "down", "back" or "forward", before a
     * gesture is passed on; returning true means the shell took it.
     *
     * Legacy checked its own overlays before anything else got a gesture key
     * (SystemUiController::handleKeyEvent): an open notification list or system
     * menu closes, and for some gestures that is all the gesture does. Several
     * Connections on one signal cannot stop each other, so that decision has to
     * be made here, before the signal goes out.
     */
    property var shellFirst: null

    function _shellTook(gesture) {
        return shellFirst !== null && shellFirst(gesture) === true;
    }

    //! Key_CoreNavi_Home
    function tap() {
        if (!_shellTook("tap"))
            tapGesture();
    }

    //! Key_CoreNavi_Launcher
    function swipeUp(modifiers) {
        if (!_shellTook("up"))
            swipeUpGesture(modifiers);
    }

    //! Key_CoreNavi_SwipeDown: a drag from the screen into the area
    function swipeDown(modifiers) {
        if (!_shellTook("down"))
            swipeDownGesture(modifiers);
    }

    //! Key_CoreNavi_Back
    function back(modifiers) {
        if (!_shellTook("back"))
            swipeLeftGesture(modifiers);
    }

    //! Key_CoreNavi_Menu, legacy's forward
    function forward(modifiers) {
        if (!_shellTook("forward"))
            swipeRightGesture(modifiers);
    }

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
        layer.mipmap: true
        fillMode: Image.PreserveAspectFit
    }
    Image {
        id: glowImageMask
        visible: false
        y: glowImage.y
        height: glowImage.height
        width: glowImage.width
        source: "../images/glowMask.png"
        layer.mipmap: true
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

    SwipeArea {
        id: gestureAreaInput
        anchors.fill: parent

        onSwipeRightGesture: (modifiers) => {
            glowLeftToRight.start();
            gestureAreaItem.forward(modifiers);
        }
        onSwipeLeftGesture: (modifiers) => {
            glowRightToLeft.start();
            gestureAreaItem.back(modifiers);
        }
        onSwipeUpGesture: (modifiers) => { gestureAreaItem.swipeUp(modifiers); }

        onTapped: gestureAreaItem.tap();
    }
}

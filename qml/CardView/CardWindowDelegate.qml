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

import LunaNext.Common 0.1
import LunaNext.Compositor 0.1

import "../Utils"

Item {
    id: cardDelegateContainer

    // this is the window model wrapping the window
    property CardWindowWrapper windowUserData
    property bool anchorWindowUserData: windowUserData && !windowUserData.Drag.active

    // this defines the sizes the card should have, depending on the state of the window
    property real cardHeight
    property real cardWidth
    property real cardY
    property real fullWidth
    property real maximizedY
    property real maximizedHeight
    property real fullscreenY
    property real fullscreenHeight

    property bool isCurrentCard

    property real cornerRadius: 20
    property real animationDuration: 100

    /* Advertise the wrapped window that the screen size has changed */
    onFullscreenHeightChanged:  if( windowUserData ) windowUserData.syncClientWindowSize();
    onFullWidthChanged: if( windowUserData ) windowUserData.syncClientWindowSize();

    Component.onCompleted: {
        y = Qt.binding( function() { return cardY; } );
        height = Qt.binding( function() { return cardHeight; } );
        width = Qt.binding( function() { return cardWidth; } );
    }

    onAnchorWindowUserDataChanged: {
        if( anchorWindowUserData ) {
            windowUserData.parent = cardWindowWrapper;
            windowUserData.anchors.fill = cardWindowWrapper;
            windowUserData.visible = true;
        }
    }

    Connections {
        target: windowUserData
        onStateChanged: {
            if( windowUserData.state === "card" )
            {
                toMaximizeAnimation.stop();
                toFullscreenAnimation.stop();
                toCardAnimation.start();
            }
            else if( windowUserData.state === "maximized" )
            {
                toCardAnimation.stop();
                toFullscreenAnimation.stop();
                toMaximizeAnimation.start();
            }
            else if( windowUserData.state === "fullscreen" )
            {
                toCardAnimation.stop();
                toMaximizeAnimation.stop();
                toFullscreenAnimation.start();
            }
        }
    }

    SequentialAnimation {
        id: toCardAnimation
        running: false

        PropertyAction { targets: [windowUserData]; property: "useShaderCorner"; value: true }
        PropertyAction { targets: [cardShadow]; property: "visible"; value: true }
        ParallelAnimation {
            PropertyAnimation { target: cardDelegateContainer; property: "y"; to: cardY; duration: animationDuration }
            PropertyAnimation { target: cardDelegateContainer; property: "height"; to: cardHeight; duration: animationDuration }
            PropertyAnimation { target: cardDelegateContainer; property: "width"; to: cardWidth; duration: animationDuration }
        }
        onStopped: {
            // set bindings properly
            y = Qt.binding( function() { return cardY; } );
            height = Qt.binding( function() { return cardHeight; } );
            width = Qt.binding( function() { return cardWidth; } );
            windowUserData.syncClientWindowSize();
        }
    }
    SequentialAnimation {
        id: toMaximizeAnimation
        running: false
        ParallelAnimation {
            PropertyAnimation { target: cardDelegateContainer; property: "y"; to: maximizedY; duration: animationDuration }
            PropertyAnimation { target: cardDelegateContainer; property: "height"; to: maximizedHeight; duration: animationDuration }
            PropertyAnimation { target: cardDelegateContainer; property: "width"; to: fullWidth; duration: animationDuration }
        }
        PropertyAction { targets: [cardShadow]; property: "visible"; value: false }
        PropertyAction { targets: [windowUserData]; property: "useShaderCorner"; value: false }
        onStopped: {
            // set bindings properly
            y = Qt.binding( function() { return maximizedY; } );
            height = Qt.binding( function() { return maximizedHeight; } );
            width = Qt.binding( function() { return fullWidth; } );
            windowUserData.syncClientWindowSize();
        }
    }
    SequentialAnimation {
        id: toFullscreenAnimation
        running: false
        SequentialAnimation {
            PropertyAnimation { target: cardDelegateContainer; property: "y"; to: fullscreenY; duration: animationDuration }
            PropertyAnimation { target: cardDelegateContainer; property: "height"; to: fullscreenHeight; duration: animationDuration }
            PropertyAnimation { target: cardDelegateContainer; property: "width"; to: fullWidth; duration: animationDuration }
        }
        PropertyAction { targets: [cardShadow]; property: "visible"; value: false }
        PropertyAction { targets: [windowUserData]; property: "useShaderCorner"; value: false }
        onStopped: {
            // set bindings properly
            y = Qt.binding( function() { return fullscreenY; } );
            height = Qt.binding( function() { return fullscreenHeight; } );
            width = Qt.binding( function() { return fullWidth; } );
            windowUserData.syncClientWindowSize();
        }
    }

    Behavior on scale  { NumberAnimation { duration: 100 } }


    BorderImage {
        id: cardShadow
        source: Qt.resolvedUrl("../images/card-shadow-tile.png");

        anchors.centerIn: cardWindowWrapper
        width: cardWindowWrapper.width+2*30
        height: cardWindowWrapper.height+2*30

        border { left: 30; top: 30; right: 30; bottom: 30 }
        horizontalTileMode: BorderImage.Stretch
        verticalTileMode: BorderImage.Stretch
    }

    Item {
        id: cardWindowWrapper

        anchors.fill: parent

        Component.onCompleted: {
            if( anchorWindowUserData ) {
                windowUserData.parent = cardWindowWrapper;
                windowUserData.anchors.fill = cardWindowWrapper;
                windowUserData.visible = true;
            }
        }
        Component.onDestruction: {
            if( windowUserData && windowUserData.parent === cardWindowWrapper )
            {
                windowUserData.parent = null;
                windowUserData.visible = false;
                windowUserData.anchors.fill = undefined;
            }
        }
    }
}

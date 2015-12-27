/*
 * Copyright (C) 2015 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2015 Herman van Hazendonk <github.com@herrie.org>
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
import QtQuick.Window 2.0
import "LunaSysAPI"



Item {
    Preferences {
        id: preferences
    }

    id: orientationHelperItem
    x: 0; y: 0
    height: parent.height; width: parent.width

    property real __lockedRotationAngle: 0
    property bool automaticOrientation: false
    property int orientationAngle: !preferences.rotationLock ? Screen.angleBetween(Screen.primaryOrientation, Screen.orientation) : __lockedRotationAngle;
    property bool transitionEnabled: false

    property real rotationCenterX: parent.width/2;
    property real rotationCenterY: parent.height/2;

    transform: Rotation { origin.x: rotationCenterX; origin.y: rotationCenterY; angle: -orientationAngle}
    Behavior on orientationAngle { RotationAnimation { duration: 500; direction: RotationAnimation.Shortest}}

    Connections { target: preferences; onRotationLockChanged: if( preferences.rotationLock ) __lockedRotationAngle = orientationAngle; }

    states: [
        State {
            name: "normal"
            when: orientationAngle === 0 || orientationAngle === 180
            PropertyChanges {
                target: orientationHelperItem
                height: parent.height
                width: parent.width
                rotationCenterX: parent.width/2;
                rotationCenterY: parent.height/2;
            }
        },
        State {
            name: "rotated"
            when: orientationAngle === 90
            PropertyChanges {
                target: orientationHelperItem
                height: parent.width
                width: parent.height
                rotationCenterX: parent.height/2;
                rotationCenterY: parent.height/2;
            }
        },
        State {
            name: "rotatedInversed"
            when: orientationAngle === 270
            PropertyChanges {
                target: orientationHelperItem
                height: parent.width
                width: parent.height
                rotationCenterX: parent.width/2;
                rotationCenterY: parent.width/2;
            }
        }
    ]

    Component.onCompleted: {
        Screen.orientationUpdateMask = Qt.LandscapeOrientation | Qt.PortraitOrientation |
                                       Qt.InvertedLandscapeOrientation | Qt.InvertedPortraitOrientation;
    }

    function setOrientation(angle) {
        if (preferences.rotationLock) return;
        orientationAngle = angle;
    }
}

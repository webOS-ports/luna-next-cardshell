/*
 * Copyright (C) 2014 Simon Busch <morphis@gravedo.de>
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
    id: padLock

    signal unlock

    anchors.fill: parent

    Image {
        id: targetScrim
        source: "../images/screen-lock-target-scrim.png"
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        visible: pad.moving
    }

    DropArea {
        x: 75; y: 75
        width: 50; height: 50

        Rectangle {
            anchors.fill: parent
            color: "green"

            visible: parent.containsDrag
        }
    }

    Image {
        id: pad
        source: pad.on ? "../images/screen-lock-padlock-on.png" : "../images/screen-lock-padlock-off.png"

        property bool on: false

        property int _basePositionX: parent.width / 2 - (pad.sourceSize.width / 2)
        property int _basePositionY: parent.height - pad.sourceSize.height - Units.gu(1)

        x: _basePositionX
        y: _basePositionY

        function resetPosition() {
            pad.x = _basePositionX;
            pad.y = _basePositionY;
        }

        function checkForUnlockPosition() {
            if ((pad.x < targetScrim.x || pad.x > targetScrim.x + targetScrim.width) ||
                (pad.y < targetScrim.y || pad.y > targetScrim.y + targetScrim.height))
                padLock.unlock();
        }

        property bool moving: padDragArea.drag.active

        Drag.active: padDragArea.drag.active
        Drag.hotSpot.x: 10
        Drag.hotSpot.y: 10

        MouseArea {
            id: padDragArea
            anchors.fill: parent
            drag.target: parent

            onReleased: {
                pad.checkForUnlockPosition();
                pad.resetPosition();
            }
        }
    }
}

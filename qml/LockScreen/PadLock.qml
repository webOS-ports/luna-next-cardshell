/*
 * Copyright (C) 2014 Simon Busch <morphis@gravedo.de>
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

import QtQuick 2.5
import LunaNext.Common 0.1

Item {
    id: padLock

    signal unlock

    anchors.fill: parent

    Image {
        id: targetScrim
        source: "../images/screen-lock-target-scrim.png"
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Settings.tabletUi ? Units.gu(10) : Units.gu(1)
        anchors.horizontalCenter: parent.horizontalCenter
        visible: pad.moving
        mipmap: true
	width: Units.gu(50)
	height: Units.gu(30)
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

    Text
    {
        id: unlockText
        text: "Drag up to unlock"
        font.pixelSize: FontUtils.sizeToPixels("large")
        color: "white"
        font.bold: true
        anchors.verticalCenter: targetScrim.verticalCenter
        anchors.horizontalCenter: targetScrim.horizontalCenter
        visible: false
    }



    Image {
        id: pad
        source: pad.on ? "../images/screen-lock-padlock-on.png" : "../images/screen-lock-padlock-off.png"
		height: Units.gu(12)
		width: Units.gu(12)
        mipmap: true

        property bool on: false

        property int _basePositionX: parent.width / 2 - (pad.width / 2)
        property int _basePositionY: Settings.tabletUi ? (parent.height - pad.height - Units.gu(10)) : (parent.height - pad.height - Units.gu(1))

        x: _basePositionX
        y: _basePositionY

        function resetPosition() {
            pad.x = Qt.binding( function() { return _basePositionX; } );
            pad.y =  Qt.binding( function() { return _basePositionY; } );
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
		pad.on = false;
                unlockText.visible = false;
            }
            onPressed: {
                pad.on = true;
                unlockText.visible = true;
            }
        }
    }
}

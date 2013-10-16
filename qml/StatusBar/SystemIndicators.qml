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

Row {
    id: indicatorsRow

    // Utility animation when an indicator must be hidden
    SequentialAnimation {
        id: hideIndicatorAnimation

        ParallelAnimation {
            NumberAnimation { target: hideIndicatorAnimation.target; properties: "opacity"; to: 0; duration: 200 }
            NumberAnimation { target: hideIndicatorAnimation.target; properties: "width"; to: 0; duration: 400 }
        }
        PropertyAction { target: hideIndicatorAnimation.target; properties: "visible"; value: false }

        function hideItem(itemToHide) {
            target = itemToHide;
            start();
        }

        property Item target
    }

    Image {
        id: indicatorSeparator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        width: 8
        fillMode: Image.TileHorizontally

        source: "../images/statusbar/status-bar-separator.png"
    }

    BatteryIndicator {
        id: batteryIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        batteryLevel: 0
    }
}

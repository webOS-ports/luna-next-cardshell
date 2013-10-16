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

    // Utility animations when an indicator must be hidden or shown
    SequentialAnimation {
        id: hideIndicatorAnimation

        ParallelAnimation {
            NumberAnimation { target: hideIndicatorAnimation.__target; properties: "opacity"; to: 0; duration: 200 }
            NumberAnimation { target: hideIndicatorAnimation.__target; properties: "width"; to: 0; duration: 400 }
        }
        PropertyAction { target: hideIndicatorAnimation.__target; properties: "visible"; value: false }

        function hideItem(itemToHide) {
            __target = itemToHide;
            if( __target )
                start();
        }

        property Item __target
    }

    SequentialAnimation {
        id: showIndicatorAnimation

        PropertyAction { target: showIndicatorAnimation.__target; properties: "visible"; value: true }
        ParallelAnimation {
            NumberAnimation { target: showIndicatorAnimation.__target; properties: "opacity"; to: 1; duration: 200 }
            NumberAnimation { target: showIndicatorAnimation.__target; properties: "width"; to: showIndicatorAnimation.__targetWidth; duration: 400 }
        }

        function showItem(itemToShow) {
            __target = itemToShow;
            __targetWidth = itemToShow.originalWidth;
            if( __target )
                start();
        }

        property Item __target
        property real __targetWidth
    }

    Image {
        id: indicatorSeparator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        width: 8
        fillMode: Image.TileHorizontally

        source: "../images/statusbar/status-bar-separator.png"
    }

    WifiIndicator {
        id: wifiIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        signalLevel: -1
        enabled: false

        width: 0

        onEnabledChanged: {
            if( enabled ) {
                showIndicatorAnimation.showItem(wifiIndicator);
            }
            else {
                hideIndicatorAnimation.hideItem(wifiIndicator);
            }
        }
    }

    BatteryIndicator {
        id: batteryIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        batteryLevel: 0
    }
}

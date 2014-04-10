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
    id: slidingArea

    property Item slidingTargetItem

    property int slidingAxis: Drag.XAxis
    property real minTreshold: 0.5
    property real maxTreshold: 0.5
    property bool filterChildren: false
    property bool slidingEnabled: true
    property bool slideOnLeft: true
    property bool slideOnRight: true

    signal slidedLeft
    signal slidedRight
    signal clicked
    signal pressAndHold

    NumberAnimation {
        id: swipeOutAnimation
        duration: 100
        target: slidingTargetItem
        property: slidingAxis === Drag.XAxis ? "x": "y"

        function doSwipeOut(targetValue, signalOnStop) {
            to = targetValue;
            start();

            __signalOnStop = signalOnStop;
        }
        // private
        property var __signalOnStop;
        onStopped: __signalOnStop();
    }
    NumberAnimation {
        id: backToHCenterAnimation
        running: false
        duration: 50

        target: slidingTargetItem
        property: "x"
        to: slidingArea.width/2 - slidingTargetItem.width/2
    }
    NumberAnimation {
        id: backToVCenterAnimation
        duration: 50

        target: slidingTargetItem
        property: "y"
        to: slidingArea.height/2 - slidingTargetItem.height/2
    }

    // Swipe a card up of down the screen to close the window:
    // use a movable area containing the card window
    SwipeArea {
        id: slidingMouseArea

        anchors.fill: slidingTargetItem
        rotation: slidingTargetItem.rotation
        transformOrigin: slidingTargetItem.transformOrigin

        drag.target: slidingTargetItem
        drag.axis: slidingAxis
        drag.filterChildren: filterChildren
        enabled: slidingEnabled

        z: slidingTargetItem.z + 1

        onClicked: {
            slidingArea.clicked();
        }

        onPressAndHold: {
            slidingArea.pressAndHold();
        }

        onPressed: {
            backToHCenterAnimation.stop();
            backToVCenterAnimation.stop();
        }

        onSwipeCanceled: {
            if( drag.axis === Drag.XAxis ) {
                backToHCenterAnimation.start();
            }
            else if( drag.axis === Drag.YAxis ) {
                backToVCenterAnimation.start();
            }
        }

        onSwipeLeftGesture: {
            if( drag.axis === Drag.XAxis ) {
                if( slideOnLeft && slidingTargetItem.x < (slidingArea.width*minTreshold - slidingTargetItem.width/2) ) {
                    // slided to the left
                    swipeOutAnimation.doSwipeOut(-slidingTargetItem.width, slidedLeft);
                }
                else {
                    backToHCenterAnimation.start();
                }
            }
            else {
                backToVCenterAnimation.start();
            }
        }
        onSwipeRightGesture: {
            if( drag.axis === Drag.XAxis ) {
                if( slideOnRight && slidingTargetItem.x > slidingArea.width*maxTreshold - slidingTargetItem.width/2 ) {
                    // slided to the right
                    swipeOutAnimation.doSwipeOut(slidingArea.width, slidedRight);
                }
                else {
                    backToHCenterAnimation.start();
                }
            }
            else {
                backToVCenterAnimation.start();
            }
        }
        onSwipeUpGesture: {
            if( drag.axis === Drag.YAxis ) {
                if( slideOnLeft && slidingTargetItem.y < (slidingArea.height*minTreshold - slidingTargetItem.height/2) ) {
                    // slided up
                    swipeOutAnimation.doSwipeOut(-slidingTargetItem.height, slidedLeft);
                }
                else {
                    backToVCenterAnimation.start();
                }
            }
            else {
                backToHCenterAnimation.start();
            }
        }
        onSwipeDownGesture: {
            if( drag.axis === Drag.YAxis ) {
                if( slideOnRight && slidingTargetItem.y > slidingArea.height*maxTreshold - slidingTargetItem.height/2 ) {
                    // slided down
                    swipeOutAnimation.doSwipeOut(slidingArea.height, slidedRight);
                }
                else {
                    backToVCenterAnimation.start();
                }
            }
            else {
                backToHCenterAnimation.start();
            }
        }
    }
}

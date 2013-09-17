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
    signal sliderClicked

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
    MouseArea {
        id: slidingMouseArea

        anchors.fill: slidingTargetItem
        drag.target: slidingTargetItem
        drag.axis: slidingAxis
        drag.filterChildren: filterChildren
        enabled: slidingEnabled

        onClicked: {
            sliderClicked();
        }

        onPressed: {
            backToHCenterAnimation.stop();
            backToVCenterAnimation.stop();
        }

        onReleased: {
            if( drag.axis === Drag.XAxis ) {
                if( slideOnLeft && slidingTargetItem.x < (slidingArea.width*minTreshold - slidingTargetItem.width) ) {
                    // slided to the left
                    swipeOutAnimation.doSwipeOut(-slidingTargetItem.width, slidedLeft);
                }
                else if( slideOnRight && slidingTargetItem.x > slidingArea.width*maxTreshold ) {
                    // slided to the right
                    swipeOutAnimation.doSwipeOut(slidingArea.width, slidedRight);
                }
                else
                {
                    backToHCenterAnimation.start();
                }
            }
            else if( drag.axis === Drag.YAxis ) {
                if( slideOnLeft && slidingTargetItem.y < (slidingArea.height*minTreshold - slidingTargetItem.height) ) {
                    // slided up
                    swipeOutAnimation.doSwipeOut(-slidingTargetItem.height, slidedLeft);
                }
                else if( slideOnRight && slidingTargetItem.y > slidingArea.height*maxTreshold ) {
                    // slided down
                    swipeOutAnimation.doSwipeOut(slidingArea.height, slidedRight);
                }
                else
                {
                    backToVCenterAnimation.start();
                }
            }
        }
    }
}

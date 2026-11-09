import QtQuick 2.0
import QtQml 2.15

Item {
    id: swipeableRoot
    property Component notifComponent
    property alias interactive: flickableArea.interactive
    property alias notifItem: notifLoader.item
    property bool blockSwipesToLeft: false

    signal requestDestruction()

    // An entry for a group of toasts outlives a swipe: only the toast on top
    // goes. The area calls this when the entry has taken up the next one, and
    // it is back in place, showing that.
    function comeBack() {
        if (!swipeoutNotification.running)
            flickableArea.settled = true;
    }

    Flickable {
        id: flickableArea

        width: swipeableRoot.width
        height: swipeableRoot.height

        flickableDirection: Flickable.HorizontalFlick
        interactive: true
        boundsBehavior: Flickable.DragOverBounds
        contentWidth: swipeableRoot.width
        // Put confortable margins on top and bottom of card to enable flicking
        leftMargin: swipeableRoot.width
        rightMargin: swipeableRoot.width
        contentX: 0

        Item {
            width: swipeableRoot.width
            height: swipeableRoot.height

            Loader {
                id: notifLoader
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: swipeableRoot.notifComponent
            }
        }
        onContentXChanged: if ((contentX>0) && (swipeableRoot.blockSwipesToLeft)) contentX=0;

        // Let go short of a swipe-out, it slides back into place. (A Behavior
        // on contentY was meant to do this, but the notification moves along
        // contentX, and the Binding below put it back at 0 in one jump.)
        property bool settled: true
        onMovementStarted: {
            slideBack.stop();   // caught again on its way back
            settled = false;
        }
        onMovementEnded: {
            if (!swipeoutNotification.running)
                slideBack.start();
        }
        NumberAnimation {
            id: slideBack
            target: flickableArea
            property: "contentX"
            to: 0
            duration: 150
            easing.type: Easing.OutQuad
            onStopped: flickableArea.settled = true
        }

        // When nothing special is happening, always have the card centered
        Binding {
            when: flickableArea.settled && !swipeoutNotification.running
            target: flickableArea
            property: "contentX"
            value: 0
            restoreMode: Binding.RestoreBinding
        }

        // handling of card swipe-out, either by drag or by flick
        SmoothedAnimation {
            id: swipeoutNotification
            target: flickableArea
            property: "contentX"
            duration: 200
            onStopped: requestDestruction(); // delete card
        }

        /* Slides the notification out the way it was swiped: a positive
         * contentX (or velocity) is the content moving left. The direction used
         * to come from swipeableRoot.contentX, which does not exist - always
         * undefined, so every notification left to the right, whichever way it
         * was swiped. */
        function swipeOut(toLeft) {
            swipeoutNotification.to = toLeft ? swipeableRoot.width : -swipeableRoot.width;
            swipeoutNotification.start();
        }

        onDraggingChanged: {
            if(!dragging && !swipeoutNotification.running) {
                if(contentX>(swipeableRoot.width*0.5) ||
                   contentX<(-swipeableRoot.width*0.5))
                {
                    swipeOut(contentX > 0);
                }
            }
        }
        onFlickingChanged: {
            if(flicking && !swipeoutNotification.running) {
                if( ((!swipeableRoot.blockSwipesToLeft)&&(horizontalVelocity>1000)) ||
                   horizontalVelocity<-1000)
                {
                    swipeOut(horizontalVelocity > 0);
                }
            }
        }
    }
}

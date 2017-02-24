import QtQuick 2.0

Item {
    id: swipeableRoot
    property Component notifComponent
    property alias interactive: flickableArea.interactive
    property alias notifItem: notifLoader.item
    property bool blockSwipesToLeft: false

    signal requestDestruction()

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

        // Smooth movement when resetting card position
        Behavior on contentY {
            SmoothedAnimation { duration: 100 }
        }
        // When nothing special is happening, always have the card centered
        Binding {
            when: !flickableArea.moving && !swipeoutNotification.running
            target: flickableArea
            property: "contentX"
            value: 0
        }

        // handling of card swipe-out, either by drag or by flick
        SmoothedAnimation {
            id: swipeoutNotification
            target: flickableArea
            property: "contentX"
            duration: 200
            to: swipeableRoot.contentX>=0 ? swipeableRoot.width : -swipeableRoot.width
            onStopped: requestDestruction(); // delete card
        }

        onDraggingChanged: {
            if(!dragging && !swipeoutNotification.running) {
                if(contentX>(swipeableRoot.width*0.5) ||
                   contentX<(-swipeableRoot.width*0.5))
                {
                    swipeoutNotification.start();
                }
            }
        }
        onFlickingChanged: {
            if(flicking && !swipeoutNotification.running) {
                if( ((!swipeableRoot.blockSwipesToLeft)&&(horizontalVelocity>1000)) ||
                   horizontalVelocity<-1000)
                {
                    swipeoutNotification.start();
                }
            }
        }
    }
}

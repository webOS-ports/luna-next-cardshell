import QtQuick 2.0
import QtQml 2.15

Item {
    id: swipeableRoot
    property Component cardComponent
    property alias interactive: flickableArea.interactive
    property alias cardItem: cardLoader.item

    signal requestDestruction()

    Flickable {
        id: flickableArea

        width: swipeableRoot.width
        height: swipeableRoot.height

        flickableDirection: Flickable.VerticalFlick
        interactive: true
        boundsBehavior: Flickable.DragOverBounds
        contentHeight: swipeableRoot.height
        // Put confortable margins on top and bottom of card to enable flicking
        topMargin: swipeableRoot.height
        bottomMargin: swipeableRoot.height

        Item {
            width: swipeableRoot.width
            height: swipeableRoot.height

            Loader {
                id: cardLoader
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: swipeableRoot.cardComponent
            }
        }

        // Smooth movement when resetting card position
        Behavior on contentY {
            SmoothedAnimation { duration: 100 }
        }
        // When nothing special is happening, always have the card centered
        Binding {
            when: !flickableArea.moving && !swipeoutCard.triggered
            target: flickableArea
            property: "contentY"
            value: 0
            restoreMode: Binding.RestoreBinding
        }

        // handling of card swipe-out, either by drag or by flick
        SmoothedAnimation {
            id: swipeoutCard
            target: flickableArea
            property: "contentY"
            duration: 200
            to: swipeableRoot.height
            onStopped: requestDestruction(); // delete card

            property bool triggered: false

            function swipeOut() {
                triggered = true;
                start();
            }
        }

        onDraggingChanged: {
            if(!dragging && !swipeoutCard.running) {
                if(contentY>(swipeableRoot.height*0.5) ||
                   contentY<(-swipeableRoot.height*0.7))
                {
                    swipeoutCard.swipeOut();
                }
            }
        }
        onFlickingChanged: {
            if(flicking && !swipeoutCard.running) {
                if(verticalVelocity>1000)
                {
                    swipeoutCard.swipeOut();
                }
                else if(verticalVelocity<0)
                {
                    contentY = 0;
                }
            }
        }
    }
}

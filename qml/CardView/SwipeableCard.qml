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

        /*
         * As wide as what it holds, whenever that is wider than the card.
         *
         * A maximized window grows past the card's width and is centred, so it
         * draws across the whole screen -- but a Flickable only delivers a
         * press within its own bounds, which left everything outside a centred
         * column the width of a card untouchable. Kept centred on the card, so
         * the list positions its delegates exactly as before; while the window
         * is carded this is the card's own width and nothing changes.
         */
        readonly property real widthOfContent:
            cardLoader.item ? Math.max(swipeableRoot.width, cardLoader.item.width)
                            : swipeableRoot.width

        width: widthOfContent
        x: (swipeableRoot.width - width) / 2
        height: swipeableRoot.height

        flickableDirection: Flickable.VerticalFlick
        interactive: true
        boundsBehavior: Flickable.DragOverBounds
        contentHeight: swipeableRoot.height
        // Put confortable margins on top and bottom of card to enable flicking
        topMargin: swipeableRoot.height
        bottomMargin: swipeableRoot.height

        Item {
            width: flickableArea.width
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
        // On resize (device rotation), the Flickable's bounds fixup can move
        // contentY away from 0 while contentHeight/margins still hold their old
        // values; the Binding above won't re-assert since its value didn't change.
        // Defer the reset until after the whole binding cascade has settled.
        function resetCardPosition() {
            if (!moving && !swipeoutCard.triggered) contentY = 0;
        }
        onHeightChanged: Qt.callLater(resetCardPosition)

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

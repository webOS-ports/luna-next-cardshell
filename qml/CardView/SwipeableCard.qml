import QtQuick 2.0

Item {
    id: swipeableRoot
    property Component cardComponent
    property alias interactive: myListView.interactive
    property alias cardItem: cardLoader.item

    signal requestDestruction()

    VisualItemModel {
        id: visualCardModel
        Item {
            width: swipeableRoot.width
            height: swipeableRoot.height
        }
        Item {
            width: swipeableRoot.width
            height: swipeableRoot.height

            Loader {
                id: cardLoader
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: swipeableRoot.cardComponent
            }
        }
        Item {
            width: swipeableRoot.width
            height: swipeableRoot.height
        }
    }

    ListView {
        id: myListView

        width: swipeableRoot.width
        height: swipeableRoot.height

        orientation: ListView.Vertical
        interactive: true
        currentIndex: 1
        model: visualCardModel
        boundsBehavior: Flickable.DragOverBounds

        SmoothedAnimation {
            id: swipeoutCard
            target: myListView
            property: "contentY"
            duration: 200
            to: swipeableRoot.height*2
            onStopped: requestDestruction(); // delete card
        }
        SmoothedAnimation {
            id: resetCard
            target: myListView
            property: "contentY"
            duration: 100
            to: swipeableRoot.height
        }

        onHeightChanged: resetCard.start();

        onDraggingChanged: {
            if(!dragging && !swipeoutCard.running) {
                if(contentY>(swipeableRoot.height*1.5) ||
                   contentY<(swipeableRoot.height*0.3))
                {
                    swipeoutCard.start();
                }
                else
                {
                    resetCard.start();
                }
            }
        }
        onFlickingChanged: {
            if(!flicking && !swipeoutCard.running) {
                if(verticalVelocity>1000) {
                    swipeoutCard.start();
                }
                else {
                    resetCard.start();
                }
            }
        }
    }
}

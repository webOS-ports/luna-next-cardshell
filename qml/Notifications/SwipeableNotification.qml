import QtQuick 2.0

Item {
    id: swipeableRoot
    property Component notifComponent
    property alias interactive: myListView.interactive
    property alias notifItem: notifLoader.item

    signal reset();
    signal requestDestruction()
    property bool __destructionRequested: false

    VisualItemModel {
        id: visualNotifModel
        Item {
            width: swipeableRoot.width
            height: swipeableRoot.height
        }
        Item {
            width: swipeableRoot.width
            height: swipeableRoot.height

            Loader {
                id: notifLoader
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: swipeableRoot.notifComponent
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

        orientation: ListView.Horizontal
        interactive: true
        snapMode: ListView.SnapOneItem
        currentIndex: 1
        model: visualNotifModel

        onContentXChanged: {
            if((contentX>(swipeableRoot.width*1.8) || contentX<(swipeableRoot.width*0.2))
                    && moving && !dragging && !__destructionRequested) {
                requestDestruction(); // delete notif
                __destructionRequested = true;
            }
            else if( !moving  ) {
                positionViewAtIndex(1, ListView.Beginning);
            }
        }
    }

    onReset: myListView.positionViewAtIndex(1, ListView.Beginning);
}

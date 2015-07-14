import QtQuick 2.0

Item {
    id: swipeableRoot
    property Component cardComponent
    property alias interactive: myListView.interactive
    property alias cardItem: cardLoader.item

    signal requestDestruction()
    property bool __destructionRequested: false

    VisualItemModel {
        id: visualCardModel
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
        snapMode: ListView.SnapToItem
        currentIndex: 0
        model: visualCardModel

        onContentYChanged: {
            if(contentY>(swipeableRoot.height*0.8) && !dragging && !__destructionRequested) {
                requestDestruction(); // delete card
                __destructionRequested = true;
            }
        }
    }
}

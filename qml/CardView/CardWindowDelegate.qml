import QtQuick 2.0
import LunaNext 0.1

Item {
    id: cardDelegateContainer

    // this is the card window instance wrapping the window container
    property variant cardWindow

    // this defines the size the card should have
    property alias cardWidth: cardDelegateContainer.width
    property alias cardHeight: cardDelegateContainer.height

    property bool isCurrent

    signal switchToMaximize()
    signal destructionRequest()

    property bool deleteCardWindowOnDestruction: false

    scale:  isCurrent ? 1.0: 0.9

    Item {
        id: cardWindowWrapper

        children: [ cardWindow ]

        anchors.fill: parent

        Component.onCompleted: {
            cardWindow.parent = cardWindowWrapper;
            cardWindow.anchors.fill = cardWindowWrapper;
            cardWindow.visible = true;
        }
        Component.onDestruction: {
            if( cardWindow )
            {
                cardWindow.visible = false;
                cardWindow.anchors.fill = undefined;
                cardWindow.parent = null;
            }
        }
    }

    Behavior on scale {
        NumberAnimation { duration: 100 }
    }

    onIsCurrentChanged: if(cardWindow) cardWindow.setCurrentCardState(isCurrent);

    // Delayed destruction for the cardWindow instance, to avoid problems
    // with evaluation of properties that depend on it
    Component.onDestruction: if(deleteCardWindowOnDestruction && cardWindow) cardWindow.destroy();
}

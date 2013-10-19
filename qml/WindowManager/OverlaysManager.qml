import QtQuick 2.0
import LunaNext 0.1

Item {
    id: overlaysManagerItem

    height: 600

    // a backlink to the window manager instance
    property variant windowManagerInstance

    ListModel {
        // This model contains the list of the cards
        id: listOverlaysModel
    }

    Repeater {
        id: overlaysRepeater

        anchors.left:overlaysManagerItem.left
        anchors.right:overlaysManagerItem.right
        anchors.bottom:overlaysManagerItem.bottom
        height: 600

        model: listOverlaysModel
        delegate: OverlayWindow {
            id: overlayWindowInstance

            anchors.left:parent.left
            anchors.right:parent.right

            Component.onCompleted: {
                //overlayWindowWrapper.setNewParent(overlayWindowInstance, false)
                overlayWindowWrapper.anchors.fill = undefined;
                overlayWindowWrapper.parent = overlayWindowInstance;
                overlayWindowWrapper.anchors.top = overlayWindowInstance.top
                overlayWindowWrapper.anchors.left = overlayWindowInstance.left
                overlayWindowWrapper.anchors.right = overlayWindowInstance.right
                overlayWindowInstance.height = Qt.binding(function() { return overlayWindowWrapper.height })

                overlayWindowInstance.state = "visible";
            }
        }
    }

    function appendOverlayWindow(windowWrapper, winId) {
        if( windowWrapper.windowType === WindowType.Overlay )
        {
            listOverlaysModel.append({"overlayWindowWrapper": windowWrapper});
        }
    }
}

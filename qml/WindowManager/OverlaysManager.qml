import QtQuick 2.0
import LunaNext 0.1

import "../Utils"

Item {
    id: overlaysManagerItem

    // a backlink to the window manager instance
    property variant windowManagerInstance

    ExtendedListModel {
        // This model contains the list of the cards
        id: listOverlaysModel
    }

    Repeater {
        model: listOverlaysModel
        delegate: OverlayWindow {
            id: overlayWindowInstance

            anchors.left:overlaysManagerItem.left
            anchors.right:overlaysManagerItem.right
            overlaysManagerInstance: overlaysManagerItem

            property Item windowWrapper: overlayWindowWrapper

            Component.onCompleted: {
                //overlayWindowWrapper.setNewParent(overlayWindowInstance, false)
                windowWrapper.anchors.fill = undefined;
                windowWrapper.parent = overlayWindowInstance;
                windowWrapper.anchors.top = overlayWindowInstance.top
                windowWrapper.anchors.left = overlayWindowInstance.left
                windowWrapper.anchors.right = overlayWindowInstance.right
                overlayWindowInstance.height = Qt.binding(function() { return windowWrapper.height })

                overlayWindowInstance.state = "visible";

                windowWrapper.windowVisibilityChanged.connect(__onWindowVisibilityChanged);
            }

            Component.onDestruction: {
                // remove window
                windowManagerInstance.removeWindow(windowWrapper);
            }

            function __onWindowVisibilityChanged(isVisible) {
                if( isVisible && overlayWindowInstance.state !== "visible" )
                    overlayWindowInstance.state = "visible";
                else if( overlayWindowInstance.state !== "hidden" )
                    overlayWindowInstance.state = "hidden";
            }
        }
    }

    function appendOverlayWindow(windowWrapper, winId) {
        if( windowWrapper.windowType === WindowType.Overlay )
        {
            listOverlaysModel.append({"overlayWindowWrapper": windowWrapper});

            // Add a tap action to hide the overlay
            windowManagerInstance.addTapAction("hideOverlay", __hideLastOverlay, windowWrapper)
        }
    }

    function removeOverlayWindow(windowWrapper, winId) {
        if( windowWrapper.windowType === WindowType.Overlay )
        {
            var index = listOverlaysModel.getIndexFromProperty("overlayWindowWrapper", windowWrapper);
            if( index >= 0 )
                listOverlaysModel.remove(index);
        }
    }

    function __hideLastOverlay(data) {
        // remove last overlay from the model
        //listOverlaysModel.remove(listOverlaysModel.count-1);
    }
}

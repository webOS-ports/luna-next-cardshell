/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick 2.0
import LunaNext.Common 0.1
import WebOSCompositorBase 1.0
import WebOSCoreCompositor 1.0

Item {
    id: overlaysManagerItem
    property var compositorInstance

    WindowModel {
        id: listOverlaysModel
        surfaceSource: compositorInstance.surfaceModel
        windowType: "_WEBOS_WINDOW_TYPE_KEYBOARD"

        onRowsInserted: {
            appendOverlayWindow(listOverlaysModel.get(last));
        }
    }

    Rectangle {
        id: overlayBackgroundArea
        anchors.fill: parent
        color: "grey"
        opacity: 0.2
        visible: associatedPopupWindow !== null
        property Item associatedPopupWindow
        MouseArea {
            anchors.fill: overlayBackgroundArea
            onClicked: {
                compositorInstance.closeWindow(overlayBackgroundArea.associatedPopupWindow);
                overlayBackgroundArea.associatedPopupWindow = null;
            }
        }
    }

    onWidthChanged:  updateOverlaySizes();
    onHeightChanged: updateOverlaySizes();

    function updateOverlaySizes() {
        console.log("new overlay window size = " + overlaysManagerItem.width +"x"+ overlaysManagerItem.height);
        for( var i = 0; i < listOverlaysModel.count; ++i ) {
            var window = listOverlaysModel.getByIndex(i);
            if(!window.isPopup) {
                window.changeSize(Qt.size(overlaysManagerItem.width, overlaysManagerItem.height));
            }
        }
    }

    function appendOverlayWindow(window) {
        console.log("OverlayManager: adding " + window);

        window.parent = overlaysManagerItem;
        if(!window.isPopup) {
            window.anchors.fill = overlaysManagerItem;
            window.changeSize(Qt.size(overlaysManagerItem.width, overlaysManagerItem.height));
        }
        else {
            window.anchors.centerIn = overlaysManagerItem;
            overlayBackgroundArea.associatedPopupWindow = window;
        }
    }
}

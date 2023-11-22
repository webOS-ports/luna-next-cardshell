/*
 * Copyright (C) 2014 Christophe Chapuis <chris.chapuis@gmail.com>
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
import LuneOS.Service 1.0

import "../Utils"

Rectangle {
    id: rootAlertsArea
    height: maxHeight

    property int maxHeight: 0
    property Item windowManagerItem
    property var compositorInstance

    color: "black"

    WindowModel {
        id: listPopupAlertsModel
        surfaceSource: compositorInstance.surfaceModel
        acceptFunction: "filter"

        function filter(surfaceItem) {
            // TBC: is this check correct ?
            return (surfaceItem.type === "_WEBOS_WINDOW_TYPE_SYSTEM_UI" &&
                    surfaceItem.windowProperties["LuneOS_window"] === "popupalert");
        }
    }

    Component {
        id: alertComponent
        FocusScope {
            id: alertItem

            property Item window: listPopupAlertsModel.get(index /* index is set by Repeater */)
            y: rootAlertsArea.height - height
            width: rootAlertsArea.width
            height: window ? window.height : 0
            onHeightChanged: computeNewRootHeight();

            onWidthChanged: if(window && window.height>0) window.changeSize(Qt.size(alertItem.width, alertItem.height));

            children: [ window ]

            Component.onCompleted: {
                if( window ) {
                    window.parent = alertItem;

                    /* This resizes only the quick item which contains the child surface but
                                     * doesn't really resize the client window */
                    window.anchors.left = alertItem.left;
                    window.anchors.right = alertItem.right;
                    window.y = 0;

                    //If the app provides window height in GridUnits we need to make sure we deal with it properly.
                    if( window.height>0 && window.windowProperties )
                    {
                        if( window.windowProperties.hasOwnProperty("LuneOS_metrics") && window.windowProperties["LuneOS_metrics"]==="units")
                        {
                            window.height = Units.gu(window.height/Units.length(1.0));
                        }
                    }

                    // be careful here: at this point in time, window.height is usually not yet set
                    if(window.height>0) {
                        window.changeSize(Qt.size(alertItem.width, window.height));
                    }
                    else {
                        window.onHeightChanged.connect(function() { window.changeSize(Qt.size(alertItem.width, window.height)); });
                    }

                    if( windowManagerItem ) {
                        windowManagerItem.addTapAction("hideAlertWindow", function () { compositorInstance.closeWindow(window); });
                    }

                    alertItem.focus = true;
                }
            }
        }
    }

    function computeNewRootHeight()
    {
        var i=0;
        var newMaxHeight = 0;
        var currentMaxHeight = 0;
        for( i=0; i < listPopupAlertsModel.count; ++i ) {
            currentMaxHeight = listPopupAlertsModel.get(i).height;
            if( currentMaxHeight > newMaxHeight )
                newMaxHeight = currentMaxHeight;
        }

        rootAlertsArea.maxHeight = newMaxHeight;
    }

    Repeater {
        id: repeaterAlerts

        anchors.left: rootAlertsArea.left
        anchors.right: rootAlertsArea.right
        anchors.bottom: rootAlertsArea.bottom
        model: listPopupAlertsModel.count
        delegate: alertComponent

        onItemAdded: (index, item) => {
            if( item.height > rootAlertsArea.maxHeight )
                rootAlertsArea.maxHeight = item.height;
        }
        onItemRemoved: (index, item) => {
            computeNewRootHeight();
        }
    }

    // have an object that surveys the count of alerts and notify the display if something interesting happens
    QtObject {
        property int count: listPopupAlertsModel.count
        onCountChanged: {
            if (count === 0 && __previousCount !== 0) {
                // notify the display
                displayService.call("luna://com.palm.display/control/alert",
                                    JSON.stringify({"status": "generic-deactivated"}), undefined, onDisplayControlError)
            }
            else if (count !== 0 && __previousCount === 0){
                // notify the display
                displayService.call("luna://com.palm.display/control/alert",
                                    JSON.stringify({"status": "generic-activated"}), undefined, onDisplayControlError)
            }

            __previousCount = count;
        }
        function onDisplayControlError(message) {
            console.log("Failed to call display service: " + message);
        }
        property int __previousCount: 0
    }
    LunaService {
        id: displayService

        name: "com.webos.surfacemanager-cardshell"
    }
}

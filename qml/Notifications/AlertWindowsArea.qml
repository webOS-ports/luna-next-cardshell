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
    height: maxHeight + 2 * contentMargin

    property int maxHeight: 0
    property Item windowManagerItem
    property var compositorInstance

    /* Phone ui fills its bar edge to edge with the alert. Tablet ui floats it,
     * so the alert needs room to breathe inside a rounded panel - measured off
     * webOS 3.0.5 on a touchpad, where the 320 wide alert sat in a ~340 wide
     * panel with the corners rounded by about the same margin.
     */
    readonly property real contentMargin: Settings.tabletUi ? Units.length(10) : 0

    color: Settings.tabletUi ? Qt.rgba(0, 0, 0, 0.85) : "black"
    radius: contentMargin

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
            x: rootAlertsArea.contentMargin
            y: rootAlertsArea.height - rootAlertsArea.contentMargin - height
            width: rootAlertsArea.width - 2 * rootAlertsArea.contentMargin
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

                    /* The height is already in device pixels and is used as it stands.
                     *
                     * This used to re-read a "LuneOS_metrics" == "units" height as grid
                     * units, on the assumption that WAM had scaled the requested height by
                     * the layout scale on the way in. WAM does no such thing: it hands the
                     * "height=" window feature straight to WebAppBase::Resize(), so the
                     * surface height we see here is the number the application asked for -
                     * or 100, the floor Chromium puts under a popup. Converting it anyway
                     * multiplied it by gridUnit/layoutScale, a ratio unrelated to anything
                     * either side meant, which is why the same alert came out 743px tall on
                     * tissot, 748 on sargo and 764 on mindphone - taller there than the
                     * screen, so it was clipped and appeared to hang from the top instead of
                     * sitting above the notification area.
                     *
                     * An html alert knows its own content height and nothing here does, so
                     * the size has to be settled before the window is opened; luna-systemui
                     * scales its css heights by the page zoom for exactly that reason.
                     */

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

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
import LunaNext.Compositor 0.1
import LunaNext.Shell.Notifications 0.1
import LuneOS.Service 1.0

import "../Utils"

Rectangle {
    height: listDashboardsModel.count > 0 ? dashboardsColumnFlickable.height + Units.gu(2) : 0

    color: "black"

    readonly property int maxDashboardWindowHeight: parent.height/2
    readonly property int dashboardCardFixedHeight: 56 // this value comes from the CSS of the dashboard cards

    WindowModel {
        id: listDashboardsModel
        windowTypeFilter: WindowType.Dashboard
        onCountChanged: {
            if (count === 0 && __previousCount !== 0) {
                // notify the display
                displayService.call("luna://com.palm.display/control/alert",
                                    JSON.stringify({"status": "banner-deactivated"}), undefined, onDisplayControlError)
            }
            else if (count !== 0 && __previousCount === 0){
                // notify the display
                displayService.call("luna://com.palm.display/control/alert",
                                    JSON.stringify({"status": "banner-activated"}), undefined, onDisplayControlError)
            }

            __previousCount = count;
        }
        function onDisplayControlError(message) {
            console.log("Failed to call display service: " + message);
        }
        property int __previousCount: 0
    }

    Flickable {
        id: dashboardsColumnFlickable

        interactive: height === maxDashboardWindowHeight
        clip: interactive
        flickableDirection: Flickable.VerticalFlick
        height: Math.min(maxDashboardWindowHeight, dashboardsColumn.height);
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            margins: Units.gu(1)
        }
        contentHeight: dashboardsColumn.height
        contentWidth: width

        Column {
            id: dashboardsColumn
            rotation: 180

            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
            }
            spacing: Units.gu(1) / 2

            Repeater {
                anchors.horizontalCenter: dashboardsColumn.horizontalCenter
                model: listDashboardsModel
                delegate: Item {
                            id: dashboardItem

                            width: dashboardsColumn.width
                            height: dashboardCardFixedHeight
                            rotation: -180

                            children: [ window ]

                            Component.onCompleted: {
                                if( window ) {
                                    window.parent = dashboardItem;

                                    /* This resizes only the quick item which contains the child surface but
                                     * doesn't really resize the client window */
                                    window.anchors.fill = dashboardItem;

                                    /* Resize the real client window to have the right size */
                                    window.changeSize(Qt.size(dashboardItem.width, dashboardItem.height));
                                }
                            }
                        }
            }
        }

        Behavior on height {
            NumberAnimation { duration: 150 }
        }
    }

    LunaService {
        id: displayService

        name: "org.webosports.luna"
        usePrivateBus: true
    }
}

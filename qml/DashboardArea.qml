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

import "Utils"

Rectangle {
    height: listDashboardsModel.count > 0 ? dashboardsColumn.height + Units.gu(2) : 0

    color: "black"

    WindowModel {
        id: listDashboardsModel
        windowTypeFilter: WindowType.Dashboard
    }

    Column {
        id: dashboardsColumn

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            margins: Units.gu(1)
        }
        spacing: Units.gu(1) / 2

        Repeater {
            anchors.horizontalCenter: dashboardsColumn.horizontalCenter
            model: listDashboardsModel
            delegate: Item {
                        id: dashboardItem

                        width: dashboardsColumn.width - Units.gu(1) * 2
                        height: window ? window.height : 0

                        children: [ window ]

                        Component.onCompleted: {
                            if( window ) {
                                window.parent = dashboardItem;

                                /* This resizes only the quick item which contains the child surface but
                                 * doesn't really resize the client window */
                                window.anchors.left = dashboardItem.left;
                                window.anchors.right = dashboardItem.right;
                                window.y = 0;

                                /* Resize the real client window to have the right size */
                                window.changeSize(Qt.size(dashboardItem.width, window.height));
                            }
                        }
                    }
        }
    }

    Behavior on height {
        NumberAnimation { duration: 150 }
    }
}

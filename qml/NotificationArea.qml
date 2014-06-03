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

// The notification area can take three states:
//  - closed: nothing is shown
//  - minimized: only notification icons are shown
//  - open: all notifications with their content are shown

Rectangle {
    id: notificationArea

    property Item windowManagerInstance

    height: 0

    color: "black"
    state: "minimized"

    NotificationListModel {
        id: notificationModel
    }

    Row {
        id: minimizedListView

        x: 0; y: 0; width: parent.width
        height: notificationModel.count > 0 ? Units.gu(3) : 0;

        layoutDirection: Qt.RightToLeft

        Repeater {
            model: notificationModel
            delegate: Image {
                    id: notifIconImage
                    source: Qt.resolvedUrl("images/default-app-icon.png")
                    height:  Units.gu(3)
                    fillMode: Image.PreserveAspectFit
                }
        }
    }
    MouseArea {
        anchors.fill: minimizedListView
        enabled: minimizedListView.visible
        onClicked: {
            notificationArea.state = "open";
        }
    }

    Column {
        id: openListView

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            leftMargin: Units.gu(1)
            rightMargin: Units.gu(1)
        }
        visible: false
        spacing: Units.gu(1) / 2

        Repeater {
            anchors.horizontalCenter: openListView.horizontalCenter
            model: notificationModel
            delegate:
                SlidingItemArea {
                    id: slidingNotificationArea
                    slidingTargetItem: notificationItem

                    height: notificationItem.height
                    width: notificationItem.width

                    NotificationItem {
                        id: notificationItem

                        anchors.verticalCenter: slidingNotificationArea.verticalCenter
                        width: notificationArea.width - Units.gu(1) * 2
                        height: Units.gu(6)
                        summary: object.summary
                        body: object.body
                    }

                    onSliderClicked:notificationArea.launchApplication(object.appName, "{}");
                    onSlidedLeft: notificationModel.remove(index);
                    onSlidedRight: notificationModel.remove(index);
                }
        }
    }

    Behavior on height {
        NumberAnimation { duration: 150 }
    }

    states: [
        State {
            name: "minimized"
            PropertyChanges { target: minimizedListView; visible: true }
            PropertyChanges { target: openListView; visible: false }
            PropertyChanges { target: notificationArea; height: minimizedListView.height }
        },
        State {
            name: "open"
            PropertyChanges { target: minimizedListView; visible: false }
            PropertyChanges { target: openListView; visible: true }
            PropertyChanges { target: notificationArea; height: openListView.height }
        }
    ]
}

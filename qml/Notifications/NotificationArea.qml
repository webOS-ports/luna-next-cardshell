/*
 * Copyright (C) 2014-2016 Christophe Chapuis <chris.chapuis@gmail.com>
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
import QtQml.Models 2.1

import LunaNext.Common 0.1
import WebOSCompositorBase 1.0
import LuneOS.Service 1.0

import "../Utils"

// The notification area can take three states:
//  - hidden: nothing is shown
//  - minimized: only notification icons are shown
//  - open: all notifications with their content are shown

Rectangle {
    id: notificationArea

    property QtObject compositorInstance
    property Item windowManagerInstance
    property int maxDashboardWindowHeight: parent.height/2
    readonly property int dashboardCardFixedHeight: Units.gu(5.6) // this value comes from the CSS of the dashboard cards
    readonly property int bannerNotificationFixedHeight: Units.gu(2.4) // this value comes from the CSS of the banner

    height: 0
    color: "black"
    /* hidden by default as long as we don't any notifications */
    state: "hidden"

    IconPathServices {
        id: iconPathServices
    }

    NotificationsMergedModel {
        id: mergedModel

        onAddBannerNotification: (notifObject) => {
           bannerItemsPopups.popupModel.append({"object": notifObject});
        }
    }

    // Minimized view
    Row {
        id: minimizedListView

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            margins: Units.gu(1)/2
        }

        height: mergedModel.count > 0 ? Units.gu(3) : 0;

        layoutDirection: Qt.RightToLeft

        Repeater {
            model: mergedModel
            delegate: Image {
                    id: notifIconImage
                    height: minimizedListView.height
                    width: height
                    fillMode: Image.PreserveAspectFit

                    function setSourceIcon(resolvedUrl) {
                        notifIconImage.source = resolvedUrl;
                    }

                    // set the source asynchronously
                    Component.onCompleted: {
                        // if it's a dashboard, iconUrl is equal to: getIconUrl(myIconUrl, window.appId),
                        // if it's a notification, it's simply getIconUrlOrDefault(iconUrl, ownerId, "mergedModel")

                        // so, if it's a window, we need to call setIconUrlFromWindow first
                        if(model.window) {
                            iconPathServices.setIconUrlFromWindow(model.window, function(resolvedUrl) {
                                iconPathServices.setIconUrlOrDefault(resolvedUrl, window.appId, setSourceIcon);
                            });
                        } else if(notifObject) {
                            iconPathServices.setIconUrlOrDefault(notifObject.iconPath, notifObject.ownerId, setSourceIcon);
                        }
                    }

            }
        }
    }

    function minimizeNotificationArea() {
        if( notificationArea.state === "open" )
            notificationArea.state = "minimized";
    }

    MouseArea {
        anchors.fill: minimizedListView
        enabled: minimizedListView.visible
        onClicked: {
            bannerItemsPopups.popupModel.clear();
            notificationArea.state = "open";
            windowManagerInstance.addTapAction("minimizeNotificationArea", minimizeNotificationArea, null)
        }
    }

    ListView {
        id: openListView

        visible: false
        interactive: height === maxDashboardWindowHeight
        clip: interactive
        orientation: ListView.Vertical
        cacheBuffer: maxDashboardWindowHeight
        height: Math.min(maxDashboardWindowHeight, contentHeight);
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            margins: Units.gu(1)/2
        }

        spacing: Units.gu(1) / 2
        model: mergedModel

        delegate:
            SwipeableNotification {
                id: slidingNotificationArea

                property var delegateNotifObject: typeof notifObject !== 'undefined' ? notifObject : undefined;
                property Item delegateWindow: typeof window !== 'undefined' ? window : null;
                property string delegateType: notifType;
                property int delegateHeight: notifHeight
                property int delegateIndex: index

                notifComponent: notificationItemLoaderComponent

                height: delegateHeight
                width: notificationArea.width - Units.gu(1)

                Component {
                    id: notificationItemLoaderComponent

                    Loader {
                        id: notificationItemLoader
                        width: slidingNotificationArea.width
                        height: slidingNotificationArea.delegateHeight

                        sourceComponent: slidingNotificationArea.delegateType === "notification" ?
                                             mergedModel.notificationItemDelegate :
                                             mergedModel.dashboardDelegate

                        property var loaderNotifObject: slidingNotificationArea.delegateNotifObject
                        property Item loaderWindow: slidingNotificationArea.delegateWindow
                        property QtObject loaderCompositorInstance: compositorInstance

                        signal closed()
                        onClosed: {
                            item.closed();
                        }
                    }
                }

                onRequestDestruction: slidingNotificationArea.notifItem.closed();
        }

        Behavior on height {
            NumberAnimation { duration: 150 }
        }
    }

    // Banner popup view
    BannerPopupArea {
        id: bannerItemsPopups
        visible: height>0

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        height: popupModel.count > 0 ? bannerNotificationFixedHeight : 0;
        Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
    }

    states: [
        State {
            name: "hidden"
            when: (bannerItemsPopups.popupModel.count + mergedModel.count) === 0
            PropertyChanges { target: minimizedListView; visible: false }
            PropertyChanges { target: openListView; visible: false }
            PropertyChanges { target: notificationArea; height: 0 }
        },
        State {
            name: "banner"
            when: bannerItemsPopups.popupModel.count>0
            PropertyChanges { target: minimizedListView; visible: false }
            PropertyChanges { target: openListView; visible: false }
            PropertyChanges { target: notificationArea; height: bannerItemsPopups.height }
        },
        State {
            name: "minimized"
            when: bannerItemsPopups.popupModel.count===0 && !openListView.visible
            PropertyChanges { target: minimizedListView; visible: true }
            PropertyChanges { target: openListView; visible: false }
            PropertyChanges { target: notificationArea; height: minimizedListView.height+Units.gu(1) }
        },
        State {
            name: "open"
            when: bannerItemsPopups.popupModel.count===0
            PropertyChanges { target: minimizedListView; visible: false }
            PropertyChanges { target: openListView; visible: true }
            PropertyChanges { target: notificationArea; height: openListView.height+Units.gu(1) }
        }
    ]
}

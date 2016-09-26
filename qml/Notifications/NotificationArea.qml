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
import LunaNext.Compositor 0.1
import LunaNext.Shell.Notifications 0.1
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
    readonly property int maxDashboardWindowHeight: parent.height/2
    readonly property int dashboardCardFixedHeight: Units.gu(5.6) // this value comes from the CSS of the dashboard cards
    readonly property int bannerNotificationFixedHeight: Units.gu(2.4) // this value comes from the CSS of the banner

    height: 0
    color: "black"
    /* hidden by default as long as we don't any notifications */
    state: "hidden"

    IconPathServices {
           id: iconPathServices
    }

    NotificationManager {
        id: notificationMgr
    }

    NotificationListModel {
        id: notificationModel

        // the signal itemAdded is declared in C++, without a qmltype declaration,
        // so QML isn't able to guess the name of the signal argument.
        onItemAdded: {
            var notifObject = arguments[0];

            var createStickyNotification = ( typeof notifObject.expireTimeout !== 'undefined' && notifObject.expireTimeout > 1 );

            // Banner in all cases
            bannerItemsPopups.popupModel.append({"object" : notifObject, "sticky": createStickyNotification});

            // If the notification's duration is long enough, also add it to the notification list
            if( createStickyNotification ) {
                // Sticky notification
                mergedModel.append({"notifType": "notification",
                                    "window": null,
                                    "notifObject": notifObject,
                                    "notifHeight": dashboardCardFixedHeight});
            }
        }
        onRowsAboutToBeRemoved: {
            var notifObject = notificationModel.get(last);
            for( var i=0; i<mergedModel.count; ++i ) {
                if( mergedModel.get(i).notifObject &&
                    mergedModel.get(i).notifObject.replacesId === notifObject.replacesId ) {
                    mergedModel.remove(i);
                    break;
                }
            }
        }
    }
    WindowModel {
        id: listDashboardsModel
        windowTypeFilter: WindowType.Dashboard

        onRowsInserted: {
            var window = listDashboardsModel.getByIndex(last);
            window.visible = false;

            // Handle dashboards with custom height
            var dashHeight = 0;
            if( window.windowProperties && window.windowProperties.hasOwnProperty("LuneOS_dashheight") )
            {
                //If the provide it in GridUnits we need to make sure we deal with it properly.
                if( window.windowProperties.hasOwnProperty("LuneOS_metrics") && window.windowProperties["LuneOS_metrics"]==="units")
                {
                    dashHeight = Units.gu(window.windowProperties["LuneOS_dashheight"]);
                }
                //Provided in normal pixels, convert to device pixels
                else
                {
                    dashHeight = Units.length(window.windowProperties["LuneOS_dashheight"]);
                }
            }
            if( dashHeight<=0 ) dashHeight = dashboardCardFixedHeight;

            if( notificationArea.state === "hidden" || notificationArea.state == "open" ) {
                notificationArea.state = "minimized";
            }
            mergedModel.append({"notifType": "dashboard",
                                "window": window,
                                "notifObject": null,
                                "notifHeight": dashHeight});
        }
        onRowsAboutToBeRemoved: {
            var window = listDashboardsModel.getByIndex(last);
            for( var i=0; i<mergedModel.count; ++i ) {
                if( mergedModel.get(i).window && mergedModel.get(i).window === window ) {
                    mergedModel.remove(i);
                    break;
                }
            }
        }
    }

    ListModel {
        id: mergedModel
        dynamicRoles: true
    }

    Component {
        id: notificationItemDelegate

        NotificationItem {
            id: notificationItem

            property var notifObject: loaderNotifObject;

            signal clicked()
            signal closed(int notifIndex)

            title: notifObject.title
            body: notifObject.body

            Component.onCompleted: {
                iconPathServices.setIconUrlOrDefault(notifObject.iconPath, notifObject.ownerId, function(resolvedUrl) { notificationItem.iconUrl = resolvedUrl; });
            }

            onClosed: {
                notificationMgr.closeById(notifObject.replacesId);
            }

            MouseArea {
                anchors.fill: parent
                onClicked: launcherInstance.launchApplication(notificationItem.notifObject.launchId,
                                                              notificationItem.notifObject.launchParams, handleLaunchAppSuccess);

															  
            }

            function handleLaunchAppSuccess() {
                if (typeof notifObject.replacesId !== "undefined") {
                    notificationMgr.closeById(notifObject.replacesId);
                }
            }
        }
    }
    Component {
        id: dashboardDelegate

        Item {
            id: dashboardItem

            property Item dashboardWindow: loaderWindow;

            signal clicked()
            signal closed(int notifIndex)

            onWidthChanged: if(dashboardWindow) dashboardWindow.changeSize(Qt.size(dashboardItem.width, dashboardItem.height));

            children: [ dashboardWindow ]

            Component.onCompleted: {
                if( dashboardWindow ) {
                    dashboardWindow.parent = dashboardItem;

                    /* This resizes only the quick item which contains the child surface but
                                             * doesn't really resize the client window */
                    dashboardWindow.anchors.fill = dashboardItem;
                    dashboardWindow.visible = true;

                    /* Resize the real client window to have the right size */
                    dashboardWindow.changeSize(Qt.size(dashboardItem.width, dashboardItem.height));
                }
            }
            Component.onDestruction: {
                if( dashboardWindow ) dashboardWindow.visible = false;
            }

            onClosed: {
                dashboardWindow.visible = false;
                compositorInstance.closeWindowWithId(dashboardWindow.winId); // this will take care of removing the card from mergedModel
                dashboardWindow = null;
            }
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

                        sourceComponent: slidingNotificationArea.delegateType === "notification" ? notificationItemDelegate : dashboardDelegate
                        property var loaderNotifObject: slidingNotificationArea.delegateNotifObject
                        property Item loaderWindow: slidingNotificationArea.delegateWindow

                        signal closed()
                        onClosed: {
                            item.closed(slidingNotificationArea.delegateIndex);
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


        Connections {
            target: bannerItemsPopups.popupModel
            onCountChanged: {
                if( bannerItemsPopups.popupModel.count > 0 )
                    notificationArea.state = "banner";
                else if( mergedModel.count > 0 )
                    notificationArea.state = "minimized";
            }
            onRowsAboutToBeRemoved: {
                if( !bannerItemsPopups.popupModel.get(last).sticky )
                {
                    notificationMgr.closeById(bannerItemsPopups.popupModel.get(last).object.replacesId);
                }
            }
        }
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
            PropertyChanges { target: minimizedListView; visible: false }
            PropertyChanges { target: openListView; visible: false }
            PropertyChanges { target: notificationArea; height: bannerItemsPopups.height }
        },
        State {
            name: "minimized"
            PropertyChanges { target: minimizedListView; visible: true }
            PropertyChanges { target: openListView; visible: false }
            PropertyChanges { target: notificationArea; height: minimizedListView.height+Units.gu(1) }
        },
        State {
            name: "open"
            PropertyChanges { target: minimizedListView; visible: false }
            PropertyChanges { target: openListView; visible: true }
            PropertyChanges { target: notificationArea; height: openListView.height+Units.gu(1) }
        }
    ]

    // have an object that surveys the count of notifications and notify the display if something interesting happens
    QtObject {
        property int count: mergedModel.count
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
    LunaService {
        id: displayService

        name: "org.webosports.luna"
        usePrivateBus: true
    }
}

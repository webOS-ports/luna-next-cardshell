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

import WebOSCoreCompositor 1.0 

import LunaNext.Common 0.1
import WebOSCompositorBase 1.0
import LuneOS.Service 1.0

import "../Utils"

ListModel {
    id: mergedModel
    dynamicRoles: true

    property IconPathServices iconPathServices: IconPathServices {}
    property NotificationService notificationService: NotificationService {}
    property Connections toastsListModelCnx: Connections {
        target: notificationService.toastModel
        // the signal itemAdded is declared in C++, without a qmltype declaration,
        // so QML isn't able to guess the name of the signal argument.
        function onRowsInserted(index, first, last) {
            var notifObject = notificationService.toastModel.get(last);

            var createStickyNotification = true; // ( typeof notifObject.expireTimeout !== 'undefined' && notifObject.expireTimeout > 1 );

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
        function onRowsAboutToBeRemoved(index, first, last) {
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
    property WindowModel listDashboardsModel : WindowModel {
        surfaceSource: compositorInstance.surfaceModel
        acceptFunction: "filter"

        function filter(surfaceItem) {
            // TBC: is this check correct ?
            return (surfaceItem.type === "_WEBOS_WINDOW_TYPE_FLOATING" /* && windowProperties["LuneOS_window"] === "dashboard" */);
        }

        onRowsInserted: (index, first, last) => {
            var window = listDashboardsModel.get(last);
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
        onRowsAboutToBeRemoved: (index, first, last) => {
            var window = listDashboardsModel.get(last);
            for( var i=0; i<mergedModel.count; ++i ) {
                if( mergedModel.get(i).window && mergedModel.get(i).window === window ) {
                    mergedModel.remove(i);
                    break;
                }
            }
        }
    }

    property Component notificationItemDelegate: Component {
        NotificationItem {
            id: notificationItem

            property var notifObject: loaderNotifObject;

            signal clicked()
            signal closed(int notifIndex)

            title: notifObject.title || notifObject.message
            body: notifObject.message

            Component.onCompleted: {
                iconPathServices.setIconUrlOrDefault(notifObject.iconPath, notifObject.sourceId, function(resolvedUrl) { notificationItem.iconUrl = resolvedUrl; });
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
    property Component dashboardDelegate: Component {
        Item {
            id: dashboardItem

            property Item dashboardWindow: loaderWindow;
            property QtObject compositorInstance: loaderCompositorInstance;

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
                compositorInstance.closeWindow(dashboardWindow); // this will take care of removing the card from mergedModel
                dashboardWindow = null;
            }
        }
    }

    // have an object that surveys the count of notifications and notify the display if something interesting happens
    property QtObject _mergedModelObserver: QtObject {
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
    property LunaService displayService: LunaService {
        name: "com.webos.surfacemanager-cardshell"
        usePrivateBus: true
    }
}
